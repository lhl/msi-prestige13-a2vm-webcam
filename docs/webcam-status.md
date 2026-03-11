# Webcam Status

Updated: 2026-03-12

## Short Answer

The webcam is now streaming raw frames on Linux on this laptop.

On the `exp18` kernel branch with explicit userspace `media-ctl` pipeline
setup, `/dev/video0` delivers real Bayer sensor data:

- 4 frames captured at 30 fps (33.39 ms inter-frame delta)
- 40,310,784 bytes total (4 x 10,077,696 = 2592 x 1944 x 2 bytes/pixel)
- raw data starts with plausible 10-bit Bayer values
- `VIDIOC_STREAMON returned 0 (Success)`
- a fresh-boot rerun confirmed this is a real pre/post delta, not inherited
  state:
  - pre-setup `Intel IPU7 CSI2 0` defaults to `SGRBG10_1X10/4096x3072`
  - the `CSI2:1 -> Capture 0` link starts disabled
  - steps 2-5 of `scripts/06-media-pipeline-setup.sh` switch the graph to the
    working `2592x1944` + `[ENABLED]` state

The required userspace setup before streaming:

```bash
# enable the CSI2-to-capture link
media-ctl -d /dev/media0 -l '"Intel IPU7 CSI2 0":1 -> "Intel IPU7 ISYS Capture 0":0 [1]'
# set CSI2 pad formats to match sensor output
media-ctl -d /dev/media0 -V '"Intel IPU7 CSI2 0":0/0 [fmt:SGRBG10_1X10/2592x1944]'
media-ctl -d /dev/media0 -V '"Intel IPU7 CSI2 0":1/0 [fmt:SGRBG10_1X10/2592x1944]'
# set video node format
v4l2-ctl -d /dev/video0 --set-fmt-video=width=2592,height=1944,pixelformat=BA10
```

The kernel patch stack required:

- `ms13q3-int3472-tps68470-v1.patch` — board data
- `ipu-bridge-ovti5675-v1.patch` — sensor enumeration
- `ov5675-serial-power-on-v1.patch` — sensor power sequencing
- `ms13q3-daisy-chain-standard-vsio-v1.patch` — daisy-chain isolation +
  standard VSIO (the `exp18` patch)

Known remaining issues:

- 5x `csi2-0 error: Received packet is too long` warnings in dmesg during
  capture
  - current hard clue: `bytesused = 10,077,696`, `Size Image = 10,082,880`,
    `Bytes per Line = 5,184`
  - the `5,184`-byte delta is exactly one extra scanline in the allocated
    capture buffer
  - likely a CSI2 format/blanking configuration detail, not a data-path
    blocker
- post-boot PMIC register dump still returns `ERROR` for every register
- the `media-ctl` route command (`-R`) returns `ENOTSUP` — the IPU7 CSI2
  entity does not support explicit routing, but link enable + format alignment
  is sufficient
- no automated pipeline setup yet; the `media-ctl` commands above must be run
  manually or scripted before each capture session

For the full March 9 review, see `docs/20260309-status-report.md`.

## What Is Proven Working

- IPU device present and bound:
  - PCI `8086:645d`
  - driver `intel-ipu7`
- PMIC companion present and reachable enough to identify itself:
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- sensor path present:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- MSI board-data patch working enough to create the sensor client:
  - `i2c-OVTI5675:00`
- `ov5675` clock path is real, not a dummy fallback:
  - `resolved xvclk provider via common clock framework at 19200000 Hz`
  - `tps68470_clk_prepare ... rate=19200000`
- sensor binds into the media graph:
  - `ov5675 10-0036` linked into `Intel IPU7 CSI2 0` `[ENABLED,IMMUTABLE]`
- fresh-boot defaults are now proven:
  - `Intel IPU7 CSI2 0` pad0/pad1 start at `SGRBG10_1X10/4096x3072`
  - `CSI2:1 -> Intel IPU7 ISYS Capture 0` starts as `[]`
- raw Bayer capture from `/dev/video0` works with explicit pipeline setup:
  - 4 frames at 30 fps
  - 10,077,696 bytes per frame
  - plausible 10-bit Bayer pixel values
  - steps 2-5 of `scripts/06-media-pipeline-setup.sh` are causally sufficient
    to move the graph into the working state

## What Is Still Incomplete

- automated pipeline setup: the `media-ctl` link enable and format commands
  must be run manually before each fresh capture session
- `csi2-0 error: Received packet is too long` warnings appear during capture
  (5 instances observed); the current leading clue is a one-scanline mismatch
  between `bytesused` and `Size Image`
- post-boot PMIC register dumping still returns `ERROR` for every register
- upstreamability: the current patch stack includes local experiment
  instrumentation that would need cleanup before submission

## What The PMIC Experiment Chain Added

### `exp1` PMIC instrumentation

What it proved:

- the real `TPS68470` clock provider is being used
- `tps68470_clk_prepare()` really runs
- the remaining failure is not just "maybe xvclk was a dummy clock"

Key finding:

- `VSIO` still logged `S_I2C_CTL=0x00`

### `exp2` staged `S_I2C_CTL`

What it proved:

- the current Linux experiment did reach the staged helper path

What it did not do:

- it did not move `S_I2C_CTL` off `0x00`
- it did not fix sensor identify

New issue introduced:

- `VSIO: failed to disable: -ETIMEDOUT`

Interpretation:

- this branch is informative, but not a clean negative. The current staged
  implementation is probably wrong or incomplete.

### `exp3` `VD = 1050 mV`

Result:

- clean negative
- same `-110` identify timeout pattern

### `exp4` `WF::Initialize`-style value programming

What it proved:

- the value-programming hook really executed on boot

Key line:

- `applying WF init value programming: VD=1050mV VA=2800mV VCM=2800mV VIO=1800mV VSIO=1800mV`

Result:

- still same repeated `-110` identify timeout

Interpretation:

- value-register initialization alone is insufficient

### `exp5` `WF` GPIO mode follow-up

Result:

- PMIC GPIO mode programming landed
- still same `-110` identify timeout

Interpretation:

- more blind GPIO mode tweaking is low value now

### `exp6` `UF` / `gpio.4` last resort

Result:

- `UF gpio.4 last resort: GPDO=0x00 value=0`
- still same `-110` identify timeout

Interpretation:

- the current `UF` / `gpio.4` branch is negative and remains a low-priority
  path

### `exp7` raw PMIC regmap trace

What it proved:

- PMIC access is healthy through:
  - clock setup
  - `ANA` enable on `VACTL`
  - `CORE` enable on `VDCTL`
- the first bad PMIC transaction is `VSIO` enable on `S_I2C_CTL` `0x43`

Key line:

- `enable VSIO update reg=S_I2C_CTL(0x43) ... update_ret=0 after_ret=-110`

Interpretation:

- `0x43` is now the primary suspect, not `0x47` or `0x48`
- the current Linux `VSIO` handling is likely tripping a PMIC/I2C state change
  that makes subsequent PMIC accesses fail

Operational note:

- the broad `exp7` tracing also amplified the timeout storm enough to interact
  badly with boot, including one `boot.mount` timeout / emergency-mode path
  during the run
- that looks like collateral from the PMIC/I2C timeout storm, not evidence
  that `/boot` itself is the webcam blocker

### `exp8` focused `S_I2C_CTL` trace

What it proved:

- the narrower trace does not change the underlying failure
- `ANA` still enables cleanly on `VACTL`
- `CORE` still enables cleanly on `VDCTL`
- the first bad PMIC transition is still `VSIO` enable on `S_I2C_CTL` `0x43`

Key lines:

- `pmic_focus: enable ANA ... before=0x00 ... after=0x01`
- `pmic_focus: enable CORE ... before=0x04 ... after=0x05`
- `pmic_focus: enable VSIO reg=S_I2C_CTL(0x43) ... update_ret=0 after_ret=-110`

Interpretation:

- `exp7` was not a false positive caused by broad tracing
- the bus wedge is tied to the `0x43` transition itself, not just to the
  extra regmap snapshotting
- the next meaningful question is narrower still:
  - does the wedge happen on the IO-side `BIT(1)` transition
  - or on the later GPIO-side `BIT(0)` transition

### `exp9` split-step `S_I2C_CTL` trace

What it proved:

- the IO-side `BIT(1)` step is safe in the regulator path
- the later `BIT(0)` step is the first bad PMIC transition

Key lines:

- `pmic_split: enable VSIO step=bit1 ... before=0x00 ... after=0x02`
- `pmic_split: enable VSIO step=bit0 ... before=0x02 ... update_ret=0 after_ret=-110`

Interpretation:

- Linux is not generically wrong about `0x43`; it is specifically wrong to
  assert `BIT(0)` in this early regulator-phase path
- the most plausible next move is to leave `BIT(1)` in place and stop setting
  `BIT(0)` there
- if that keeps the bus alive, the later question becomes where the board
  really wants `BIT(0)` to be asserted

### `exp10` `BIT(1)`-only `S_I2C_CTL`

What it proved:

- keeping only the IO-side `BIT(1)` step avoids the old PMIC bus wedge
- `ANA`, `CORE`, and `VSIO BIT(1)` all read back cleanly
- the sensor path now gets back to chip-ID reads without controller timeouts

Key lines:

- `pmic_focus: enable-bit1-only VSIO reg=S_I2C_CTL(0x43) ... after=0x02`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -121`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -121`
- `pmic_focus: disable-bit1-only VSIO reg=S_I2C_CTL(0x43) ... after=0x00`

Interpretation:

- `exp10` is not a clean negative
- it eliminated the old `0x43`-driven timeout storm
- `-121` (`EREMOTEIO`) is materially different from the older `-110`
  timeout behavior and is consistent with the bus staying alive while the
  sensor still does not answer with the expected chip ID
- the next question is no longer whether early `BIT(0)` is wrong; that is now
  effectively proven
- the next question is whether the board wants a later `BIT(0)` assertion or
  some other later wake-up / reset sequencing step after the regulator phase

### `exp11` late GPIO-phase `BIT(0)`

What it proved:

- this specific later-phase `BIT(0)` hook is not the fix
- the old timeout storm returns when the late `BIT(0)` write fires
- `exp10` remains the best clean-boot state so far

Key lines:

- `pmic_focus: enable-bit1-only VSIO reg=S_I2C_CTL(0x43) ... after=0x02`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -121`
- `tps68470-gpio ... pmic_gpio: sensor-gpio.1 value=0 ... before=0x02 update_ret=0 after_ret=-110`
- repeated `i2c_designware.1: controller timed out`

Interpretation:

- a late `BIT(0)` tied to this GPIO-active hook still wedges PMIC access
- it did not improve chip-ID behavior
- on this implementation, the only observed late `BIT(0)` event was
  `sensor-gpio.1 value=0`, which suggests the current hook is either still the
  wrong phase or still the wrong signal
- the useful state to preserve is still `exp10`:
  - `BIT(1)` only
  - no timeout storm
  - chip-ID loop reaches `-121`

### `exp12` Antti-inspired daisy-chain cross-check

What it proved:

- the low-effort local daisy-chain setup really executes
- the current `MS-13Q3` Linux lookup model then immediately re-drives
  `GPIO1` / `GPIO2` back to output mode
- the sensor failure shape still ends at `-121`

Key lines:

- `exp12_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp12_daisy: probe-after gpio.2 ... ctl=0x00`
- `exp12_daisy: direction-output-after gpio.1 ... ctl=0x02`
- `exp12_daisy: direction-output-after gpio.2 ... ctl=0x02`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Interpretation:

- this low-effort daisy-chain cross-check is negative as a direct fix
- it is still useful because it shows the current `GPIO1` / `GPIO2` model and
  the Antti daisy-chain model are not additive on this laptop
- a serious daisy-chain branch would need different sensor-GPIO modeling, not
  just daisy-chain enable on top of the current lookup table

### `exp13` daisy-chain isolation

What it proved:

- once Linux stops exporting `GPIO1` / `GPIO2` to `OVTI5675:00`, it can leave
  both lines in daisy-chain input mode for the full observed probe window
- the one-shot reclaim guard did not fire
- the sensor failure shape still ends at repeated `-121`

Key lines:

- `exp13_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp13_daisy: probe-after gpio.2 ... ctl=0x00`
- `pmic_focus: enable-bit1-only VSIO reg=S_I2C_CTL(0x43) ... after=0x02`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Interpretation:

- `exp13` is positive for wiring isolation, but negative as a direct fix
- the main question is no longer "does Linux still reclaim `GPIO1` / `GPIO2`?"
- the remote-line branch set later showed that `GPIO9`, `GPIO7`, and the
  current two-line approximation are all active but still insufficient under
  current `ov5675` limits

### `exp14` daisy-chain plus `GPIO9` reset

What it proved:

- `GPIO9` becomes an active Linux-visible remote control line on this board
- `GPIO1` / `GPIO2` still stay isolated in daisy-chain input mode
- `GPIO9` alone still does not move the sensor off the flat repeated `-121`
  identify failure

Key lines:

- `exp14_daisy: direction-output-after gpio.9 ...`
- `exp14_daisy: set-after gpio.9 ... sgpo_ret=0 sgpo=0x04`
- `exp14_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp14_daisy: probe-after gpio.2 ... ctl=0x00`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Interpretation:

- `GPIO9` is real and active, not just a theoretical Antti-derived candidate
- `GPIO9` alone is insufficient under current driver limits
- `exp15` now shows the next discriminator is the two-line approximation, not
  a different lone-line winner

### `exp15` daisy-chain plus `GPIO7` reset

What it proved:

- `GPIO7` becomes an active Linux-visible remote control line on this board
- `GPIO1` / `GPIO2` still stay isolated in daisy-chain input mode
- `GPIO7` alone still does not move the sensor off the flat repeated `-121`
  identify failure

Key lines:

- `exp15_daisy: direction-output-after gpio.7 ...`
- `exp15_daisy: set-after gpio.7 ... sgpo_ret=0 sgpo=0x01`
- `exp15_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp15_daisy: probe-after gpio.2 ... ctl=0x00`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Operational note:

- the verify-side PMIC dump did not complete in this run because the sudo
  prompt timed out:
  - `sudo: timed out reading password`

Interpretation:

- `GPIO7` is real and active, not just a theoretical second-line candidate
- `GPIO7` alone is insufficient under current driver limits
- `exp14` and `exp15` together now show that both single-line remote
  candidates are active but individually insufficient
- `exp16` later tested that two-line `GPIO9` / `GPIO7` approximation directly

### `exp16` daisy-chain `GPIO7` / `GPIO9` approximation

What it proved:

- the current two-line remote approximation really drives both remote lines in
  the same boot
- `GPIO1` / `GPIO2` still stay isolated in daisy-chain input mode
- even combined remote-line activity still does not move the sensor off the
  flat repeated `-121` identify failure

Key lines:

- `exp16_daisy: set-after gpio.7 ... sgpo_ret=0 sgpo=0x01`
- `exp16_daisy: set-after gpio.9 ... sgpo_ret=0 sgpo=0x05`
- `exp16_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp16_daisy: probe-after gpio.2 ... ctl=0x00`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Operational note:

- the verify-side PMIC dump completed in this run, but every register still
  came back as `ERROR`

Interpretation:

- the best current-driver `GPIO9` / `GPIO7` approximation is active but still
  insufficient
- the direct remote-line mapping question is now largely exhausted under
  current `ov5675` limits
- `exp17` later showed that one clean-remote-branch `BIT(0)` re-test is safe
  but still insufficient

### `exp17` clean remote branch plus later `BIT(0)`

What it proved:

- one later `S_I2C_CTL BIT(0)` assertion on `sensor-gpio.9` can read back
  cleanly once the clean remote-line branch is in place
- `GPIO1` / `GPIO2` still stay isolated in daisy-chain input mode
- `GPIO7` / `GPIO9` still become active during the identify window
- the old timeout storm does not return
- even with that later PMIC transition, the sensor still does not move off the
  flat repeated `-121` identify failure

Key lines:

- `exp17_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp17_daisy: probe-after gpio.2 ... ctl=0x00`
- `exp17_daisy: set-after gpio.7 ... sgpo_ret=0 sgpo=0x01`
- `exp17_daisy: set-after gpio.9 ... sgpo_ret=0 sgpo=0x05`
- `exp17_pmic_gpio: sensor-gpio.9 value=0 ... before=0x02 ... after=0x03`
- `pmic_focus: disable-bit1-only VSIO reg=S_I2C_CTL(0x43) ... before=0x03 ... after=0x01`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Operational note:

- the verify-side PMIC dump completed, but every register still came back as
  `ERROR`

Interpretation:

- `exp17` kills the simple "any later `BIT(0)` is toxic" hypothesis
- the remaining gap is now where that PMIC transition belongs, when it belongs
  there, or whether the real missing piece is the `ov5675` consumer/timing
  model rather than another remote-line guess

## Current Assessment

The webcam is working at the raw capture level. The complete path from sensor
through CSI2 to userspace frame delivery is proven.

What has been proven through the full experiment chain:

- the early regulator-phase `BIT(0)` on `S_I2C_CTL` was the PMIC bus wedge
- the daisy-chain isolation branch (removing `GPIO1`/`GPIO2` from sensor use)
  was the key wiring fix
- standard `VSIO` enable is safe on the clean daisy-chain branch
- the `STREAMON` "Link has been severed" failure was caused by missing
  userspace `media-ctl` pipeline setup, not by a kernel or firmware gap
- once the CSI2-to-capture link is enabled and pad formats are aligned, the
  sensor delivers real frames

## Remaining Work

1. Investigate the `csi2-0 error: Received packet is too long` warnings.
   - likely a CSI2 pad format or blanking configuration issue
   - current hard clue: `Size Image - bytesused = 5,184`, exactly one
     scanline at the current `Bytes per Line`
   - frames still arrive, so this may be cosmetic
2. Fix or replace the post-boot PMIC dump path.
   - `scripts/pmic-reg-dump.sh` still returns `ERROR` for every register
3. Clean up the patch stack for upstream submission.
   - remove experiment instrumentation logging
   - separate the minimal board-data changes from the diagnostic scaffolding
4. Test with higher-level capture tools (e.g. `libcamera`, `cheese`, `mpv`)
   to confirm the pipeline works end to end for normal applications.
5. Consider whether automated pipeline setup should be handled by a udev rule,
   a `libcamera` pipeline handler, or similar.

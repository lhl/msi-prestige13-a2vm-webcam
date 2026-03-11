# Webcam Status

Updated: 2026-03-11

## Short Answer

Webcam support is still not working end to end on this laptop.

The important change is not that nothing works. The important change is that
the remaining blocker is now much narrower:

- IPU7 support is present and firmware loads.
- `OVTI5675:00` is the correct sensor path.
- the MSI `INT3472` / `TPS68470` board-data patch is necessary and working
  enough to instantiate the sensor client
- the `ipu-bridge` `OVTI5675` patch is necessary and working
- the old clean-boot `dvdd` timeout is gone
- the `ov5675` driver now reaches chip-ID reads on a clean boot
- under the latest `exp10` PMIC follow-up, the old PMIC timeout storm is gone
- but every chip-ID read still fails, now with `-121`
- the `exp12` daisy-chain cross-check proved that the current Linux
  `GPIO1` / `GPIO2` lookup immediately overrides Antti-style daisy-chain setup
- `exp13` then proved that removing that lookup lets Linux keep `GPIO1` /
  `GPIO2` in daisy-chain input mode for the observed probe window
- but `exp13` still ends at the same repeated `-121` chip-ID failure
- `exp14` then proved that `GPIO9` is an active remote line, but not a
  sufficient lone reset line
- `exp15` then proved that `GPIO7` is also an active remote line, but not a
  sufficient lone reset line
- `exp16` then proved that the current `GPIO9` / `GPIO7` two-line
  approximation drives both remote lines together, but still does not move the
  sensor off repeated `-121`
- `exp17` then proved that a later `S_I2C_CTL BIT(0)` on the clean remote-line
  branch can read back safely as `0x03`, but it still does not move the sensor
  off repeated `-121`
- the repo now has a staged `exp18` patch plus wrapper pair for the next
  narrow Antti-parity PMIC comparison:
  - restore standard `VSIO` enable on top of the clean daisy-chain branch

That means the webcam is now blocked at sensor wake-up / later-stage PMIC
behavior, not at basic discovery or graph construction.

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
- the first PMIC clock and regulator instrumentation landed and logged on a
  clean boot

## What Is Still Broken

The current best PMIC experiment clean-boot checkpoint ends this way:

- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -121`
- `...`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -121`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -121`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -121`

Functional consequences:

- `ov5675` remains unbound
- there are still no `/dev/v4l-subdev*` nodes
- the media graph still lacks a working sensor entity
- the webcam is still not usable from normal Linux userspace

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

The honest assessment is:

- we are past the broad platform-support stage
- we are also past the first board-data and graph-endpoint stage
- we are in the hard last-mile stage where the sensor is present but never
  wakes up enough to answer I2C ID reads

What now looks unlikely:

- missing basic IPU7 support
- missing sensor identity
- missing first-pass MSI board-data
- missing `ipu-bridge` sensor enumeration
- simple `GPIO1` / `GPIO2` role or polarity guesses
- immediate Linux reclaim of `GPIO1` / `GPIO2` once those lines are removed
  from the sensor lookup

What now looks most likely:

- Linux still does not model either:
  - the complete remote sensor-control arrangement or consumer semantics:
    - `GPIO9` and `GPIO7` are both active together in `exp16`, but the sensor
      still stays flat at `-121`
    - `exp17` later showed a safe `sensor-gpio.9` `BIT(0)` event
      (`0x02 -> 0x03`), but the sensor still stays flat at `-121`
    - the remaining gap is therefore likely beyond the current `ov5675`
      GPIO-consumer model or exact electrical timing
  - or some board-specific later PMIC behavior that the Windows driver
    performs at a different phase
- or Linux is still missing the exact electrical waveform and timing that the
  sensor needs to exit reset / powerdown and answer chip-ID reads

## Current Blockers

1. We still cannot read back PMIC registers from userspace after boot.
   - `scripts/pmic-reg-dump.sh` remains unreliable in representative runs:
     earlier captures returned `ERROR` for every register, the `exp15` verify
     capture timed out at the sudo prompt, and both `exp16` and `exp17`
     returned all `ERROR` again.
2. We now know the bad PMIC transition is specifically the early
   regulator-phase `BIT(0)` set on `S_I2C_CTL`; `exp17` later showed that one
   later `sensor-gpio.9` `BIT(0)` write can read back cleanly as `0x03`.
3. We also now know that omitting early `BIT(0)` keeps the PMIC/I2C path
   alive, but still leaves the sensor failing chip-ID reads with `-121`.
4. We now know that removing the current `GPIO1` / `GPIO2` lookup collision is
   not sufficient by itself; `exp13` still fails flat at `-121`.
5. We now know `GPIO9` is active but insufficient as a lone reset line.
6. We now know `GPIO7` is also active but insufficient as a lone reset line.
7. We now know the current two-line `GPIO9` / `GPIO7` approximation is also
   insufficient under current driver limits.
8. We now have two different late-`BIT(0)` outcomes:
   - the earlier `exp11` GPIO hook reintroduces the PMIC wedge
   - the clean-remote-branch `exp17` hook is safe but still insufficient
9. We still do not have the exact higher-level Windows configuration path that
   feeds `WF::SetConf` or chooses the `WF` versus `UF` branch for this board.
10. We still do not have direct electrical truth for the PMIC GPIO and sensor
    reset / powerdown waveform.

## Next Steps

1. Keep `exp10` as the best functional PMIC state for now.
   - do not reintroduce `BIT(0)` in the early regulator path
   - do not treat the current `exp11` GPIO hook as a likely fix
   - use `exp17` only as evidence that one later `BIT(0)` placement is safe,
     not as a fix
2. Run staged `exp18` next.
   - restore standard `VSIO` enable on top of the clean daisy-chain branch
   - do not bundle endpoint-wait or broader regulator-set changes yet
3. Scope the `ov5675` consumer-model gap more directly if `exp18` is also
   negative.
4. Fix or replace the post-boot PMIC dump path so we can see real register
   state after a failed clean boot.
5. Extract the higher-level Windows config path that feeds `WF::SetConf` and
   selects `WF` versus `UF`.
6. Avoid spending more time on blind `GPIO1` / `GPIO2` permutations.
   - `exp13` retired the reclaim question

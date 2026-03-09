# Webcam Status

Updated: 2026-03-09

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
- but every chip-ID read still times out with `-110`

That means the webcam is now blocked at sensor wake-up / PMIC behavior, not at
basic discovery or graph construction.

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

Every recent clean-boot checkpoint ends the same way:

- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
- `...`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

Functional consequences:

- `ov5675` remains unbound
- there are still no `/dev/v4l-subdev*` nodes
- the media graph still lacks a working sensor entity
- the webcam is still not usable from normal Linux userspace

## What The March 9 PMIC Batch Added

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

What now looks most likely:

- Linux still does not model some board-specific `WF` PMIC behavior that the
  Windows driver performs
- or Linux is still missing the exact electrical waveform and timing that the
  sensor needs to exit reset / powerdown and answer chip-ID reads

## Current Blockers

1. We still cannot read back PMIC registers from userspace after boot.
   - `scripts/pmic-reg-dump.sh` currently returns `ERROR` for every register
     in representative runs.
2. We now know the bad PMIC transition is specifically the later `BIT(0)` set
   on `S_I2C_CTL` after `BIT(1)` has already read back cleanly as `0x02`.
3. We still do not have the exact higher-level Windows configuration path that
   feeds `WF::SetConf` or chooses the `WF` versus `UF` branch for this board.
4. We still do not have direct electrical truth for the PMIC GPIO and sensor
   reset / powerdown waveform.

## Next Steps

1. Run the `BIT(1)`-only `S_I2C_CTL` PMIC follow-up.
   - keep the Windows-like IO-side `BIT(1)` step
   - do not assert GPIO-side `BIT(0)` in the regulator path
   - immediate next wrapper:
     - `scripts/exp10-s-i2c-ctl-bit1-only-update.sh`
     - reboot
     - `scripts/exp10-s-i2c-ctl-bit1-only-verify.sh`
2. Fix or replace the post-boot PMIC dump path so we can see real register
   state after a failed clean boot.
3. Extract the higher-level Windows config path that feeds `WF::SetConf` and
   selects `WF` versus `UF`.
4. Avoid spending more time on blind GPIO permutations until the PMIC
   pass-through and register-state questions are answered.

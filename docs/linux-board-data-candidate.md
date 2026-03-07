# Linux Board-Data Candidate

This note captures the current best Linux-side patch candidate for the MSI
Prestige 13 AI+ Evo A2VMG webcam path after correlating:

- live ACPI on this laptop
- Linux `INT3472` / `TPS68470` board-data patterns
- the MSI Windows `iactrllogic64.sys` control-logic driver

## Current Result

The smallest plausible first patch is:

- add a new `int3472_tps68470_board_data` entry for `i2c-INT3472:06`
- add regulator consumers for `i2c-OVTI5675:00`
- add PMIC GPIO lookup wiring that starts with regular GPIO 1 / GPIO 2

Patch candidate:

- `reference/patches/ms13q3-int3472-tps68470-v1.patch`

Validation result:

- `git apply --check` succeeds against the local `v6.19` tree at
  `~/.cache/paru/clone/linux-mainline/src/linux-mainline`

## Why This Shape

Machine-specific facts:

- active sensor: `OVTI5675:00`
- active PMIC companion: `INT3472:06`
- live Linux device name: `i2c-INT3472:06`
- current failure: `No board-data found for this model`

Linux-side facts:

- `ov5675` requests:
  - regulators `avdd`, `dovdd`, `dvdd`
  - a `reset` GPIO
  - a 19.2 MHz `xvclk`
- `TPS68470` exposes:
  - `ANA` on `VACTL`
  - `CORE` on `VDCTL`
  - `VSIO` on `S_I2C_CTL`
  - `VIO` as the matching always-on rail for daisy-chained sensor-I2C use

Windows-side facts:

- `VoltageWF::PowerOn` stages VA, VD, VSIO, and VCM helper calls
- `IoActive` / `IoIdle` manage `S_I2C_CTL`
- `IoActive_GPIO` reconfigures `GPCTL1A` and `GPCTL2A`

That combination supports this first Linux mapping:

- `TPS68470_ANA` => `avdd` on `i2c-OVTI5675:00`
- `TPS68470_CORE` => `dvdd` on `i2c-OVTI5675:00`
- `TPS68470_VSIO` => `dovdd` on `i2c-OVTI5675:00`
- `TPS68470_VIO` fixed to the same 1.8 V level as `VSIO`
- PMIC regular GPIO 1 / GPIO 2 as the first candidate camera-control lines

## Main Uncertainty

The Windows evidence also shows one likely gap beyond plain board-data
matching:

- upstream `ov5675.c` only consumes `reset`
- the Windows path clearly touches both PMIC GPIO1 and GPIO2

So the first patch may still leave one MSI-specific control line unused on
Linux. If `v1` removes `No board-data found` but the sensor still does not
probe, the most likely next checks are:

1. swap the GPIO1 / GPIO2 semantic mapping
2. add optional `powerdown` handling to `ov5675.c`
3. confirm whether the second PMIC GPIO is sensor `powerdown` or a different
   board-specific control

## First Live-Test Goal

The first successful result is not "camera fully works". The first success is
smaller:

- `int3472-tps68470` no longer logs `No board-data found for this model`
- `ov5675` gets far enough to probe or at least fail differently
- the media graph gains a sensor subdevice or the kernel logs expose the next
  blocker after board-data

## Suggested Test Flow

1. Apply `reference/patches/ms13q3-int3472-tps68470-v1.patch` to a kernel tree.
2. Build a kernel or matching module set for the test kernel.
3. Boot or load the patched build.
4. Capture:
   - `scripts/webcam-run.sh snapshot --label after-v1-board-data`
   - `sudo scripts/webcam-run.sh reprobe-modules --label after-v1-board-data`
5. Compare against the committed baseline runs under `runs/2026-03-08/`.

## Expected Next Decision

After the first patched test, the branch should become one of:

- board-data-only was sufficient enough to expose the sensor path
- board-data is correct but `ov5675` needs an MSI-specific GPIO follow-up
- the regulator consumer mapping is still wrong and needs another pass

# Upstream Patch Series: MSI Prestige 13 AI+ Evo A2VMG Webcam

This directory contains a clean, upstream-ready patch series to enable
the built-in OV5675 webcam on the MSI Prestige 13 AI+ Evo A2VMG
(board MS-13Q3, Lunar Lake / IPU7).

## Status

Tested on kernel 7.0.0-rc2 with the `exp18` branch.  Raw Bayer capture
works at 2592x1944 @ 30 fps after explicit `media-ctl` pipeline setup.

## Patch Series

Apply in order against a clean mainline tree:

| # | File | Subsystem | Summary |
|---|------|-----------|---------|
| 1 | `0001-media-ipu-bridge-Add-OV5675-sensor-support.patch` | media | Add OVTI5675 to ipu-bridge sensor list |
| 2 | `0002-platform-int3472-Add-gpio-platform-data-for-TPS68470.patch` | platform/x86 | Plumb GPIO platform data through int3472 to tps68470-gpio |
| 3 | `0003-gpio-tps68470-Add-I2C-daisy-chain-support.patch` | gpio | Configure GPIO 1/2 as inputs for I2C daisy-chain mode |
| 4 | `0004-media-i2c-ov5675-Reorder-supply-names-for-correct-power-sequencing.patch` | media | Swap dvdd/dovdd in supply array for correct PMIC power-on order |
| 5 | `0005-platform-int3472-Add-MSI-Prestige-13-AI-Evo-A2VMG-board-data.patch` | platform/x86 | Board-specific regulator, GPIO, and DMI data for MS-13Q3 |

Dependencies: patch 3 depends on 2; patch 5 depends on 2.  Patches 1
and 4 are independent.

## What Changed vs. the POC Patches

The POC (experiments 1-19) used four patches layered with significant
debug instrumentation.  This series:

- **Drops all debug logging** -- no `exp18_daisy:`, `pmic_focus:`,
  `dump_stack()`, watched-line tracking, or regulator before/after
  readback instrumentation.
- **Drops all tps68470-regulator.c changes** -- the custom
  enable/disable paths with focused logging were purely diagnostic.
  The standard `regulator_enable_regmap` / `regulator_disable_regmap`
  work correctly once the daisy chain is in place.
- **Replaces the ov5675 serial power-on functions** with a simple
  supply-array reorder.  `regulator_bulk_enable` already enables
  serially in array order and `regulator_bulk_disable` disables in
  reverse order, so reordering the array achieves the same avdd ->
  dvdd -> dovdd sequence without any new code.
- **Simplifies the regulator set** from 7 regulators to 4
  (CORE/ANA/VIO/VSIO), dropping VCM/AUX1/AUX2 which had no consumers
  and were never enabled.
- **Uses DMI_SYS_VENDOR** instead of DMI_BOARD_VENDOR for consistency
  with existing entries.  Keeps DMI_BOARD_NAME as an extra safety
  match.
- **Corrects GPIO mapping** -- uses GPIO 9 (reset) and GPIO 7
  (powerdown) from the start, not the original GPIO 1/2 that were
  superseded during experiments.

## Relation to Antti Laakso's Prestige 14 Series

Antti Laakso posted a similar 5-patch series for the MSI Prestige 14
AI+ Evo C2VMG on 2026-03-10 (see `reference/antti-patch/`).  This
series shares the same structural approach:

- Same ipu-bridge OVTI5675 addition
- Same GPIO platform data plumbing mechanism
- Same I2C daisy chain concept (GPIO 1/2 as inputs)
- Same GPIO 9 + GPIO 7 for sensor control

Differences from Antti's v1:
- This targets a different machine (Prestige 13 / MS-13Q3)
- GPIO 7 is mapped as `powerdown` rather than a second `reset` index
  (current ov5675 driver only consumes one `reset` descriptor; the
  dual-reset approach was flagged in review of Antti's series)
- VIO uses `always_on` instead of `REGULATOR_CHANGE_STATUS` (tested
  safe; keeps PMIC I/O voltage stable)
- The ov5675 supply reorder is new (Antti's series didn't include it)
- The int3472 pdata plumbing conditionally sets platform_data only when
  non-NULL (safer than unconditional assignment)

## Before Submitting

- Replace all `FIXME` author/email placeholders with real values
- Add `Signed-off-by:` lines
- Verify patches apply cleanly against current mainline HEAD
- Consider whether patch 4 (ov5675 supply reorder) needs a
  `Tested-by:` or `Reviewed-by:` from someone with a non-TPS68470
  OV5675 board to confirm no regression

## After Applying

The sensor will bind and appear in the media graph, but userspace must
set up the media pipeline before streaming:

```sh
media-ctl -l '"Intel IPU7 CSI2 0":1 -> "Intel IPU7 ISYS Capture 0":0 [1]'
media-ctl -V '"Intel IPU7 CSI2 0":0/0 [fmt:SGRBG10_1X10/2592x1944]'
media-ctl -V '"Intel IPU7 CSI2 0":1/0 [fmt:SGRBG10_1X10/2592x1944]'
v4l2-ctl --set-fmt-video=width=2592,height=1944,pixelformat=BA10
v4l2-ctl --stream-mmap --stream-count=4
```

This produces raw 10-bit Bayer frames.  For normal webcam use, a
userspace bridge (GStreamer bayer2rgb, libcamera, or v4l2loopback) is
still needed.

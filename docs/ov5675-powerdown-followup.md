# `ov5675` Powerdown Follow-Up

Updated: 2026-03-08

This note captures the next patch candidate after the clean-boot test of the
serial power-on order.

## Clean-Boot Result After Serial Power-On

The first clean boot after the serial power-on patch produced:

- `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
- `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`

Important negative result:

- the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone

That means the serial rail-enable experiment did move the failure forward.

## What This Narrows

We are now past:

- missing MSI board-data
- missing firmware graph endpoint
- missing regulator lookup
- failing `dvdd` enable during `ov5675_power_on()`

The next failure is the sensor not answering `ov5675_identify_module()`:

- `failed to find sensor: -5`

That path corresponds to the chip-ID read itself failing, not a later media
registration error.

## Why `powerdown` Is Now The Leading Candidate

Current Linux-side facts:

- board data already exposes both GPIO mappings for `i2c-OVTI5675:00`:
  - `reset`
  - `powerdown`
- current `ov5675` only consumes:
  - `reset`
- Windows reverse-engineering still points to two PMIC GPIO lines being used on
  this board

So after the serial rail-enable fix, the most likely missing Linux-side control
is the second GPIO:

- assert both `reset` and `powerdown` during power-off / pre-power-on
- deassert `powerdown` and `reset` after rails are stable

## Patch Candidate

Patch file:

- `reference/patches/ov5675-powerdown-followup-v1.patch`

Patch shape:

- add optional `powerdown_gpio` handling to `ov5675`
- request it with `devm_gpiod_get_optional(..., "powerdown", GPIOD_OUT_HIGH)`
- assert it during power-off
- assert it before supply enable
- deassert it before the existing post-reset settle gap

This is intentionally the smallest follow-up after the serial power-order
change. It does not yet alter delays further.

## Success Criteria

Minimum success:

- `failed to find sensor: -5` disappears

Stronger success:

- `ov5675` binds
- `/dev/v4l-subdev*` appears
- `media-ctl` gains a sensor entity

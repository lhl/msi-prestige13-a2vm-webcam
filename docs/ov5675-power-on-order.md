# `ov5675` Power-On Order Candidate

Updated: 2026-03-08

This note captures the next kernel-side hypothesis after the first clean boot
with both the MSI board-data patch and the `ipu-bridge` `OVTI5675` patch.

## Clean-Boot Result

The clean combined-patch boot produced these key lines:

- `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
- `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `Failed to enable dvdd: -ETIMEDOUT`
- `ov5675 i2c-OVTI5675:00: failed to power on: -110`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

Binding state on the same boot:

- `i2c-INT3472:06` is bound to `int3472-tps68470`
- `i2c-OVTI5675:00` is still unbound
- no `/dev/v4l-subdev*` nodes exist

## What This Rules Out

The clean boot removes several earlier uncertainties:

- the original missing MSI board-data issue is fixed
- the missing firmware graph endpoint issue is fixed
- regulator lookup is working on a clean boot
- the earlier dummy-regulator warnings were a disturbed-session artifact

## Why Order Is Now The Leading Hypothesis

Three local facts line up:

1. `ov5675_power_on()` currently enables supplies through:
   - `regulator_bulk_enable(OV5675_NUM_SUPPLIES, ov5675->supplies)`
2. `ov5675_supply_names[]` orders those supplies as:
   - `avdd`
   - `dovdd`
   - `dvdd`
3. current `regulator_bulk_enable()` implementation is async, not strictly
   ordered

Recovered Windows notes for this laptop family point to staged power-on as:

- `VA`
- `VD`
- `VSIO`

Mapped to Linux `ov5675` supply names, that is:

- `avdd`
- `dvdd`
- `dovdd`

That makes the current Linux behavior a plausible mismatch for this MSI board.

## Patch Candidate

Patch file:

- `reference/patches/ov5675-serial-power-on-v1.patch`

Patch shape:

- replace async `regulator_bulk_enable()` with explicit serial enable
- use Windows-like order:
  - `avdd`
  - `dvdd`
  - `dovdd`
- disable in reverse order on error / power-off
- log the specific rail that fails if a serial enable still returns an error

## Why `media-ctl` Is Low Value Right Now

Until `ov5675_power_on()` succeeds:

- `ov5675` will not bind
- no `/dev/v4l-subdev*` node will exist
- `media-ctl -p -d /dev/media0` will keep showing only the IPU-side topology

So the highest-value signal for the next iteration is kernel log output around:

- `Failed to enable ...`
- `failed to power on`
- `failed to find sensor`
- appearance of `/dev/v4l-subdev*`

## Success Criteria For The Next Test

Minimum success:

- `Failed to enable dvdd: -ETIMEDOUT` disappears
- `ov5675 ... failed to power on: -110` disappears

Stronger success:

- `ov5675` gets far enough to log `failed to find sensor` or to bind
- `/dev/v4l-subdev*` appears
- `media-ctl` shows a sensor entity instead of IPU-only nodes

## Actual Result

The clean boot after the serial power-on patch did meet the minimum goal:

- `Failed to enable dvdd: -ETIMEDOUT` disappeared
- the failure moved forward to:
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`

That means this patch candidate was useful and should now be treated as a real
step forward, not just a theory.

The next likely branch is now in:

- `docs/ov5675-powerdown-followup.md`

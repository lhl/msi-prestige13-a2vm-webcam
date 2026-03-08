# Webcam status

Updated: 2026-03-08

## Machine under test

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Kernel: `7.0.0-rc2-1-mainline-dirty`

## Short answer

Webcam support is still not working end to end on this laptop.

The good news is that the first MSI-specific `INT3472` / `TPS68470`
board-data patch, the follow-up `ov5675` diagnostic patch, and the first
`ipu-bridge` follow-up patch have all moved the failure forward. The bad news
is that the camera is still blocked, now at the sensor power-on stage after
the graph hookup was fixed.

## What works

- The Lunar Lake IPU is present and bound:
  - PCI device `8086:645d`
  - kernel driver `intel-ipu7`
- In-tree kernel modules are available and loaded:
  - `intel_ipu7`
  - `intel_ipu7_isys`
  - `ov5675`
- MSI-specific `INT3472` / `TPS68470` board-data is now present in the patched
  test kernel
- The sensor client is now instantiated:
  - `i2c-OVTI5675:00`
- Device nodes exist:
  - `/dev/media0`
  - many `/dev/video*` nodes

## What is still broken

The main boot-time board-data failure is gone, but the camera still stops
before a usable sensor graph is assembled:

- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `intel-ipu7 0000:00:05.0: no subdev found in graph`

Additional live evidence on the patched kernel:

- `i2c-OVTI5675:00` exists under `/sys/bus/i2c/devices/`
- the `ipu-bridge` follow-up patch now logs:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- on a clean boot with both patches present:
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `Failed to enable dvdd: -ETIMEDOUT`
  - `ov5675 i2c-OVTI5675:00: failed to power on: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- the earlier dummy-regulator run is now understood as a disturbed-session
  artifact, not the clean combined-patch result
- the media graph still has no sensor entity
- there are still no `/dev/v4l-subdev*` nodes
- a manual bind attempt to `/sys/bus/i2c/drivers/ov5675/bind` returns:
  - `No such device or address`

Those lines and checks are the current high-value signal. They mean:

1. The PMIC is present and reachable.
2. The MSI board-data patch is active enough to instantiate the sensor client.
3. The firmware graph endpoint problem was real and is now fixed by the tested
   `ipu-bridge` patch.
4. On a clean boot, the sensor now fails during `ov5675_power_on()`, and the
   failing rail-enable path is specifically `dvdd`.

## Assessment

The likely sensor is no longer the main mystery, and neither is basic MSI
board-data matching.

- ACPI exposes `OVTI5675:00`.
- The `ov5675` kernel module is loaded.
- The patched kernel now instantiates `i2c-OVTI5675:00`.
- The graph-endpoint failure was real:
  - `OVTI5675` needed an `ipu-bridge` supported-sensor entry
- The clean-boot result removes the earlier dummy-regulator ambiguity:
  - `INT3472:06` binds cleanly
  - real regulators are found
  - `ov5675_power_on()` still fails with `-110`
  - kernel logging identifies the failing enable as `dvdd`
- The leading remaining local hypothesis is now:
  - Linux is not enabling the three sensor rails in the order MSI expects
  - recovered Windows notes point to `VA -> VD -> VSIO`
  - local `ov5675` currently requests supplies as `avdd`, `dovdd`, `dvdd`
    and enables them through async `regulator_bulk_enable()`

In practical terms, support looks like this:

- IPU7 core support: present
- Firmware loading: present
- Sensor driver presence: present
- MSI board-data match for `INT3472:06`: present in the patched test kernel
- Sensor instantiation on I2C: present in the patched test kernel
- Sensor bind / media-subdevice registration: still missing
- Firmware graph endpoint for `ov5675`: fixed by the current tested
  `ipu-bridge` patch
- Real regulators on `ov5675`: confirmed on a clean combined-patch boot
- Clean sensor power-on: still failing
- Usable webcam in userspace: not there yet

## Comparison with the upstream references

### Intel issue #17

The November 23, 2024 Intel issue already showed the same broad symptom pattern:

- firmware boots
- `/dev/video*` appears
- userspace still fails
- `no subdev found in graph`

That issue is still open as of 2026-03-07.

### Jeremy Grosser gist

The gist adds the missing board-specific hypothesis:

- `TPS68470` needs model-specific board data
- MSI likely configures this in Windows via `iactrllogic64`
- later comments through December 22, 2025 still report no working camera, including with kernel `6.18`

The local machine matched that analysis exactly before the `v1` patch. The new
patched-kernel test now narrows the blocker further than those older upstream
references could.

## Bottom line

The webcam is closer than it was in late 2024 because the current patched test
kernel now gets past the original MSI `INT3472` board-data failure and the
first `ipu-bridge` gap. But the laptop is still blocked on the next stage after
that:

- `ov5675` still does not bind successfully
- `ipu-bridge` now recognizes `OVTI5675:00` and reports one connected camera
- on a clean boot, `ov5675` now fails earlier in `power_on()`
- the failing rail-enable path is `dvdd`
- the sensor still does not appear as a media subdevice
- the camera still does not work in userspace

## Best next steps

- Test a module-only `ov5675` experiment that replaces async
  `regulator_bulk_enable()` with explicit serial rail enable in the recovered
  Windows order:
  - `avdd`
  - `dvdd`
  - `dovdd`
- Use the clean-boot `Failed to enable dvdd: -ETIMEDOUT` line as the pass/fail
  criterion for that test.
- Only if serial rail enable still fails, re-evaluate:
  - board-data regulator consumer mapping
  - `powerdown` / second-GPIO semantics
- Re-test with:
  - `journalctl -k -b | rg 'tps68470|ipu7|ov5675'`
  - `media-ctl -p -d /dev/media0`
  - `v4l2-ctl --list-devices`

# Webcam status

Updated: 2026-03-08

## Machine under test

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Kernel: `7.0.0-rc2-1-mainline-dirty`

## Short answer

Webcam support is still not working end to end on this laptop.

The good news is that the first MSI-specific `INT3472` / `TPS68470`
board-data patch and the follow-up `ov5675` diagnostic patch have both moved
the failure forward. The bad news is that the camera is still blocked at the
probe / graph stage, now with a more specific bridge-layer failure.

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
- the diagnostic `ov5675` module now logs:
  - `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`
- the media graph still has no sensor entity
- there are still no `/dev/v4l-subdev*` nodes
- a manual bind attempt to `/sys/bus/i2c/drivers/ov5675/bind` returns:
  - `No such device or address`

Those lines and checks are the current high-value signal. They mean:

1. The PMIC is present and reachable.
2. The MSI board-data patch is active enough to instantiate the sensor client.
3. The remaining blocker is now the firmware graph endpoint / sensor probe path.
4. The IPU still cannot assemble a complete media graph afterward.

## Assessment

The likely sensor is no longer the main mystery, and neither is basic MSI
board-data matching.

- ACPI exposes `OVTI5675:00`.
- The `ov5675` kernel module is loaded.
- The patched kernel now instantiates `i2c-OVTI5675:00`.
- The remaining failure is now more specifically consistent with missing
  firmware / graph-endpoint hookup for `ov5675`.
- The current leading local hypothesis is:
  - `OVTI5675` is missing from `drivers/media/pci/intel/ipu-bridge.c`
    `ipu_supported_sensors[]`
- Second-order possibilities still exist after that:
  - missing `powerdown` GPIO semantics
  - remaining regulator or sequencing mismatch after the graph is fixed

In practical terms, support looks like this:

- IPU7 core support: present
- Firmware loading: present
- Sensor driver presence: present
- MSI board-data match for `INT3472:06`: present in the patched test kernel
- Sensor instantiation on I2C: present in the patched test kernel
- Sensor bind / media-subdevice registration: still missing
- Firmware graph endpoint for `ov5675`: missing in the current tested kernel
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
kernel now gets past the original MSI `INT3472` board-data failure and exposes
the next missing piece. But the laptop is still blocked on the next stage after
that:

- `ov5675` still does not bind successfully
- `ov5675` now explicitly reports `no firmware graph endpoint found`
- the sensor still does not appear as a media subdevice
- the camera still does not work in userspace

## Best next steps

- Test the `ipu_bridge` follow-up patch candidate in:
  - `reference/patches/ipu-bridge-ovti5675-v1.patch`
- Check whether `OVTI5675` support is simply missing from
  `drivers/media/pci/intel/ipu-bridge.c`.
- If the graph-endpoint error disappears, only then re-evaluate:
  - missing `powerdown` GPIO handling in `ov5675`
  - remaining PMIC GPIO / sequencing mismatch
- Re-test with:
  - `journalctl -k -b | rg 'tps68470|ipu7|ov5675'`
  - `media-ctl -p -d /dev/media0`
  - `v4l2-ctl --list-devices`

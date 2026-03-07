# Webcam status

Updated: 2026-03-07

## Machine under test

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Kernel: `6.18.9-arch1-2`

## Short answer

Webcam support is still not working end to end on this laptop.

The good news is that kernel support has moved beyond the very early state from late 2024. The bad news is that the main blocker still appears to be board-specific camera power and graph setup, not the presence of the IPU7 core driver itself.

## What works

- The Lunar Lake IPU is present and bound:
  - PCI device `8086:645d`
  - kernel driver `intel-ipu7`
- In-tree kernel modules are available and loaded:
  - `intel_ipu7`
  - `intel_ipu7_isys`
  - `ov5675`
- Device nodes exist:
  - `/dev/media0`
  - many `/dev/video*` nodes

## What is still broken

The boot journal still shows the camera PMIC path failing before a usable sensor graph is assembled:

- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `int3472-tps68470 i2c-INT3472:06: error -ENODEV: No board-data found for this model`
- `intel-ipu7 0000:00:05.0: no subdev found in graph`

Those three lines are the current high-value signal. They mean:

1. The PMIC is present and reachable.
2. The kernel still lacks MSI-specific board data for this exact design.
3. The IPU cannot assemble a complete media graph afterward.

## Assessment

The likely sensor is no longer the main mystery.

- ACPI exposes `OVTI5675:00`.
- The `ov5675` kernel module is loaded.
- The remaining failure is more consistent with missing regulator and GPIO wiring data for the `INT3472` / `TPS68470` path than with a missing bare sensor driver.

In practical terms, support looks like this:

- IPU7 core support: present
- Firmware loading: present
- Sensor driver presence: present
- Board-specific power sequencing and graph wiring for MSI A2VMG: still missing
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

The local machine matches that analysis almost exactly.

## Bottom line

The webcam is closer than it was in late 2024 because the mainline-ish kernel side now has IPU7 and `ov5675` pieces present. But the laptop is still blocked on MSI-specific `INT3472` / `TPS68470` board data or equivalent power-sequencing knowledge, so the camera does not yet work.

## Best next steps

- Inspect the upstream `drivers/platform/x86/intel/int3472/tps68470_board_data.c` coverage and confirm this MSI model is absent.
- Extract clues from the MSI Windows camera package, especially anything around `iactrllogic64`, regulator values, or GPIO sequencing.
- After board-data changes land, re-test with:
  - `journalctl -k -b | rg 'tps68470|ipu7|ov5675'`
  - `media-ctl -p -d /dev/media0`
  - `v4l2-ctl --list-devices`

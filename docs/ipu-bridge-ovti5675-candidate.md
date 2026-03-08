# IPU Bridge `OVTI5675` Candidate

Updated: 2026-03-08

This note captures the current best explanation for the post-board-data failure
after the `ov5675` diagnostic patch.

## Actual Result From The Diagnostic Patch

The first `ov5675` diagnostic patch produced the first explicit probe error:

- `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`

That is a much stronger result than the earlier silent failure.

It means:

- the sensor client exists
- the `ov5675` driver is loading and probing
- the current failure happens before chip-ID or streaming logic
- the missing piece is likely firmware-node / graph hookup, not the original
  `TPS68470` board-data gap

## Why `ipu-bridge` is now the leading target

Three code facts line up:

1. `ov5675_get_hwcfg()` fails exactly when `fwnode_graph_get_next_endpoint()`
   finds no endpoint on the sensor's firmware node.
2. `ipu_bridge_connect_sensors()` only creates software-node graph endpoints for
   sensors listed in `ipu_supported_sensors[]`.
3. `OVTI5675` is present in the `ov5675` driver ACPI match table, but absent
   from `ipu_bridge`'s supported-sensor table.

On the live patched kernel:

- `ipu_bridge` is loaded
- `ov5675` is loaded
- `i2c-OVTI5675:00` exists
- there is still no graph endpoint for the sensor

That combination strongly suggests `ipu_bridge` never created the software-node
graph for this sensor because `OVTI5675` is not in its supported list.

## Link-Frequency Evidence

The local `ov5675` driver expects one link-frequency option:

- `450000000`

That gives a straightforward first candidate for the `ipu_bridge` sensor table:

- `IPU_SENSOR_CONFIG("OVTI5675", 1, 450000000)`

## Patch Artifact

Patch file:

- `reference/patches/ipu-bridge-ovti5675-v1.patch`

Patch shape:

- add `OVTI5675` to `ipu_supported_sensors[]`
- advertise one link-frequency at `450000000`

## Expected Result If This Is Correct

If this patch is the missing bridge piece, the next test should change the
failure mode again:

- `ov5675` should stop complaining about a missing firmware graph endpoint
- `ipu_bridge` may start logging that it found a supported sensor / connected a
  camera
- `/dev/v4l-subdev*` may appear
- `media-ctl -p -d /dev/media0` may show a sensor entity instead of only IPU
  capture nodes

If the graph endpoint error disappears but probe still fails later, that is
still a successful narrowing step.

## Suggested Test Flow

Use the same module-only method as the previous `ov5675` patch, but for
`ipu-bridge`:

1. apply `reference/patches/ipu-bridge-ovti5675-v1.patch`
2. run:
   - `make M=drivers/media/pci/intel modules`
3. compress and replace:
   - `/usr/lib/modules/$(uname -r)/kernel/drivers/media/pci/intel/ipu-bridge.ko.zst`
4. run `depmod`
5. reload at least:
   - `ov5675`
   - `intel_ipu7_isys`
   - `intel_ipu7`
   - `ipu_bridge`
6. capture with `scripts/webcam-run.sh`

## Bottom Line

The `ov5675` diagnostic patch did its job.

The leading hypothesis is no longer "sensor power sequencing is still wrong."
It is now:

- `OVTI5675` needs an `ipu-bridge` supported-sensor entry so Linux creates the
  firmware graph endpoint that `ov5675` expects.

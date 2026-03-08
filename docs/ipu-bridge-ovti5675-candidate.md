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

## Actual Result From The First `ipu-bridge` Test

The first `ipu-bridge` module-only test did change the failure mode exactly as
expected:

- `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
- `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- the old `ov5675 ... no firmware graph endpoint found` line disappeared

But the sensor still failed later:

- `ov5675 i2c-OVTI5675:00: supply avdd not found, using dummy regulator`
- `ov5675 i2c-OVTI5675:00: supply dovdd not found, using dummy regulator`
- `ov5675 i2c-OVTI5675:00: supply dvdd not found, using dummy regulator`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`

Important nuance:

- this same session also had an earlier:
  - `int3472-tps68470 i2c-INT3472:06: INT3472 seems to have no dependents`
- and a later live check showed:
  - `i2c-INT3472:06` currently unbound

So this first `ipu-bridge` test proved the bridge patch is real, but it did not
yet give a clean verdict on the regulator path. The missing-regulator result is
currently confounded by the broken `INT3472` state from the earlier manual
reprobe work.

## Actual Result From The Clean-Boot Re-Test

The clean combined-patch boot answered the main open question from the first
`ipu-bridge` run:

- `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
- `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `Failed to enable dvdd: -ETIMEDOUT`
- `ov5675 i2c-OVTI5675:00: failed to power on: -110`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

This means:

- the `ipu-bridge` patch is definitely correct
- the board-data / regulator lookup path is also present on a clean boot
- the earlier dummy-regulator output was not the steady-state combined-patch
  result
- the remaining blocker has narrowed again:
  - the failing power-on path is now specifically `dvdd`

## Suggested Test Flow

Use the same module-only method as the previous `ov5675` patch, but for
`ipu-bridge`.

That clean-boot validation is now complete, so the next targeted iteration is
no longer in `ipu-bridge`. The next patch should be in `ov5675` power-on.

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

The `ipu-bridge` follow-up patch also did its job. The confirmed result is:

- `OVTI5675` did need an `ipu-bridge` supported-sensor entry so Linux could
  create the firmware graph endpoint that `ov5675` expects

The next unresolved question is now later and narrower:

- can a serial Linux rail-enable sequence matching the recovered Windows
  `VA -> VD -> VSIO` order avoid the current `Failed to enable dvdd: -ETIMEDOUT`
  failure?

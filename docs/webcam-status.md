# Webcam status

Updated: 2026-03-09

## Machine under test

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Kernel: `7.0.0-rc2-1-mainline-dirty`

## Short answer

Webcam support is still not working end to end on this laptop.

The good news is that the first MSI-specific `INT3472` / `TPS68470`
board-data patch, the follow-up `ov5675` diagnostic patch, the `ipu-bridge`
follow-up patch, and the serial power-on follow-up have all moved the failure
forward. The bad news is that the camera is still blocked, now at sensor
identification after power-on succeeds. The latest three staged `ov5675`
GPIO-release clean boots were also negative, and the latest Windows-source
pull shows that Linux still does not model some `WF`-side PMIC behavior.

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
- on the next clean boot with the serial power-on follow-up present:
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`
- on the next clean boot with the added `powerdown` follow-up present:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`
- after installing the identify-debug `ov5675` build and doing a reload-only
  debug run:
  - `ov5675 i2c-OVTI5675:00: setup of GPIO reset failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to get reset-gpios: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- on the next clean boot with identify-debug parameters active on first load:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- on the next clean boot with the `INT3472` `GPIO1` / `GPIO2` role-swap patch:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- the clean-boot `gpio-swap-v1` run also makes one important interpretation
  point clearer:
  - with the current `ov5675` power sequence, a pure label swap on two
    `GPIO_ACTIVE_LOW` lines is close to a physical no-op, because both control
    lines are driven together
- on the next clean boot with the first polarity follow-up
  (`GPIO2` `powerdown` => `GPIO_ACTIVE_HIGH`):
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- that first polarity run also showed an early `-EPROBE_DEFER` path:
  - `cannot find GPIO chip tps68470-gpio, deferring`
  - `failed to get reset-gpios: -517`
  - but probe retried and still ended at the same clean-boot identify timeout
- on the next clean boot with the other physical-line polarity follow-up
  (`GPIO1` `powerdown` => `GPIO_ACTIVE_HIGH`):
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- unlike the first polarity run, this second one-line variant did not add the
  early `-517` GPIO-provider deferral noise
- on the three newer clean boots for staged `ov5675` GPIO release:
  - `sequence=1`, `delay_us=2000` still ends at repeated chip-ID timeouts
    `-110`
  - `sequence=2`, `delay_us=2000` still ends at repeated chip-ID timeouts
    `-110`
  - control `sequence=0` also still ends at repeated chip-ID timeouts `-110`
- the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
- the media graph still has no sensor entity
- there are still no `/dev/v4l-subdev*` nodes
- a manual bind attempt to `/sys/bus/i2c/drivers/ov5675/bind` returns:
  - `No such device or address`

Those lines and checks are the current high-value signal. They mean:

1. The PMIC is present and reachable.
2. The MSI board-data patch is active enough to instantiate the sensor client.
3. The firmware graph endpoint problem was real and is now fixed by the tested
   `ipu-bridge` patch.
4. The serial power-on follow-up removed the `dvdd` timeout and moved the
   failure forward again to sensor identification.
5. The first `powerdown` follow-up was a negative result:
   - consuming `powerdown` alone did not move the failure past `-5`
6. The first identify-debug reload run was also non-diagnostic:
   - the debug module is installed
   - but reload after a failed boot-time probe still dies earlier at
     `reset-gpios: -110`
   - the next trustworthy debug capture must happen on first load at clean boot
7. The clean-boot identify-debug run provided the real remaining error:
   - `ov5675_identify_module()` is reached
   - every chip-ID read attempt times out with `-110`
   - the remaining blocker is now a true transport / wake-up / sequencing
     failure at sensor identification time
8. The clean-boot `gpio-swap-v1` run was a negative result and also explained
   one limitation of the previous hypothesis:
   - the role-swap patch did not move the `-110` timeout
   - with the current `ov5675.c` power-on logic, both control lines are
     toggled in lockstep
   - that makes a label-only swap low-signal unless polarity also changes
9. The first one-line polarity follow-up was also a negative result:
   - moving the active-high `powerdown` behavior onto `GPIO2` did not move the
     clean-boot `-110` timeout
10. The second one-line polarity follow-up was also a negative result:
   - moving the active-high `powerdown` behavior onto `GPIO1` also did not
     move the clean-boot `-110` timeout
11. The three staged `ov5675` GPIO-release clean boots were also negative:
   - `sequence=1`, `delay_us=2000` did not move the timeout
   - `sequence=2`, `delay_us=2000` did not move it either
   - control `sequence=0` behaved the same
12. The newer Windows-source pull now narrows the likely missing Linux behavior:
   - the `WF` path carries a five-voltage tuple:
     `1050 / 2800 / 1800 / 2800 / 1800`
   - the `WF` initialize path writes PMIC value registers
     `0x41`, `0x40`, `0x42`, `0x3c`, and `0x3f`
   - the `WF` `S_I2C_CTL` path around register `0x43` is staged rather than a
     single generic enable write
   - the remaining gap is now more likely PMIC-side initialization or control
     behavior than another `ov5675`-only GPIO release tweak

## Assessment

The likely sensor is no longer the main mystery, and neither is basic MSI
board-data matching.

- ACPI exposes `OVTI5675:00`.
- The `ov5675` kernel module is loaded.
- The patched kernel now instantiates `i2c-OVTI5675:00`.
- The graph-endpoint failure was real:
  - `OVTI5675` needed an `ipu-bridge` supported-sensor entry
- The clean-boot results now remove the earlier dummy-regulator and `dvdd`
  timeout ambiguity:
  - `INT3472:06` binds cleanly
  - real regulators are found
  - `ov5675_power_on()` now succeeds far enough to reach chip-ID read
- The first `powerdown` follow-up did not change the clean-boot failure:
  - `ov5675` is still unbound
  - there are still no `/dev/v4l-subdev*`
- The clean-boot identify-debug run replaced the old collapsed `-5` ambiguity:
  - the sensor now fails with repeated chip-ID read timeouts `-110`
- The clean-boot `gpio-swap-v1` result was negative and low-signal:
  - the timeout pattern was unchanged
  - the current `ov5675` power sequence drives both control lines together, so
    swapping names without changing polarity does not materially alter the
    pin-level sequence
- The first and second one-line polarity follow-ups were both negative:
  - moving the active-high waveform onto `GPIO2` did not change the clean-boot
    identify failure
  - moving the active-high waveform onto `GPIO1` did not change it either
- The three staged `ov5675` GPIO-release runs were also negative:
  - `sequence=1`, `delay_us=2000` did not change the `-110` timeout
  - `sequence=2`, `delay_us=2000` did not change it either
  - control `sequence=0` behaved the same
- The latest Windows-source pull adds stronger PMIC-side evidence:
  - the `WF` helper carries a concrete voltage tuple
  - the `WF` initialize path writes PMIC value registers before power-on
  - the `WF` `S_I2C_CTL` handling is staged and conditional
- The leading remaining local possibilities are now:
  - missing `WF`-side PMIC value-register programming
  - missing staged `S_I2C_CTL` behavior
  - possible `VD` / `CORE` voltage mismatch between Linux and Windows
  - exact `GPIO1` / `GPIO2` semantic mapping beyond the current Linux model
- The Windows package does contain a separate `UF` helper family that touches a
  different PMIC GPIO line, but current ACPI evidence still keeps this laptop
  aligned with the `WF` / `LNK0` path, so a blind `gpio.4` pivot is not the
  best next step.

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
- Clean sensor power-on: improved enough to reach chip-ID read
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
- the serial power-on follow-up removed the clean-boot `dvdd` timeout
- the first `powerdown` follow-up did not change that outcome
- the first reload-only identify-debug run failed earlier at `reset-gpios: -110`
- the next clean boot with identify-debug parameters showed the real remaining
  failure: repeated chip-ID read timeouts `-110`
- the next clean boot with the `INT3472` role-swap follow-up was a negative
  result and effectively showed that the next useful board-data space is
  polarity, not more label-only swaps
- the next clean boot with the second `GPIO1`-active-high polarity follow-up
  was also negative
- the next three staged `ov5675` GPIO-release clean boots were also negative
- the newest Windows-source pull now shows a concrete `WF` PMIC init gap:
  value-register programming plus staged `S_I2C_CTL`
- the sensor still does not appear as a media subdevice
- the camera still does not work in userspace

## Best next steps

- Treat the first `powerdown` follow-up as a negative result.
- Use `docs/wf-vs-uf-gpio-analysis.md` to keep the next board-data experiments
  grounded in the current Windows and ACPI evidence.
- Treat the `gpio-swap-v1` clean-boot result as:
  - a real negative result
  - and evidence that polarity changes are now more meaningful than more
    label-only swaps
- Treat all three staged `ov5675` GPIO-release runs from `2026-03-09` as
  negative.
- Use the recovered Windows `WF` path to drive the next comparison in these
  directions:
  - PMIC value-register programming
  - `S_I2C_CTL` sequencing
  - current Linux `CORE` / `VD` voltage assumptions
- Current concrete next comparison:
  - current Linux MSI `WF` assumptions versus the recovered Windows `WF` tuple
    and initialization path
  - likely first patch space:
    - `INT3472` / `TPS68470` board-data or regulator behavior
    - not another `ov5675`-only GPIO-release tweak
- Re-test with:
  - `journalctl -k -b | rg 'tps68470|ipu7|ov5675'`
  - `media-ctl -p -d /dev/media0`
  - `v4l2-ctl --list-devices`

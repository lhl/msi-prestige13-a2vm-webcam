# Worklog

## 2026-03-07

### Repo bootstrap and initial webcam evidence capture

- Added repo-level process docs:
  - `README.md`
  - `AGENTS.md`
  - `PLAN.md`
  - `WORKLOG.md`
  - `state/CONTEXT.md`
  - `docs/README.md`
  - `reference/README.md`
- Added initial upstream reference notes:
  - `reference/intel-ipu7-drivers-issue-17.md`
  - `reference/jeremy-grosser-prestige13-notes.md`
- Added current technical assessment:
  - `docs/webcam-status.md`

### Local machine evidence gathered

- Commands:
  - `cat /sys/class/dmi/id/product_name`
  - `cat /sys/class/dmi/id/product_version`
  - `uname -a`
  - `lspci -nnk | rg -A3 -B2 -i 'ipu|image|camera|multimedia'`
  - `lsmod | rg 'ipu|ivsc|v4l2|uvc|sensor|ov'`
  - `journalctl -k -b --no-pager | rg -i 'ipu|ivsc|ov5675|tps68470|camera|v4l2|cio2'`

- Confirmed machine identity:
  - model `Prestige 13 AI+ Evo A2VMG`
  - revision `REV:1.0`
- Confirmed current kernel:
  - `6.18.9-arch1-2`
- Confirmed camera/IPU-related device and driver state:
  - Lunar Lake IPU at PCI ID `8086:645d`
  - kernel driver `intel-ipu7`
  - modules loaded: `intel_ipu7`, `intel_ipu7_isys`, `ov5675`
  - device nodes present: `/dev/media0` and `/dev/video*`
- Captured the strongest current boot-log evidence:
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `int3472-tps68470 i2c-INT3472:06: error -ENODEV: No board-data found for this model`
  - `intel-ipu7 0000:00:05.0: no subdev found in graph`

### Assessment

- The webcam is still not usable end to end.
- The current evidence points more strongly at missing MSI-specific `INT3472` / `TPS68470` board data or power sequencing than at a missing core IPU7 driver.
- `OVTI5675:00` and the loaded `ov5675` module make the sensor identity much less mysterious than it was in late 2024.

### Notes

- After the initial scaffold pass, the `claudecycles-revisited` repo was reviewed as an additional process reference.
- The most useful convention imported from it was a small restart capsule in `state/CONTEXT.md` plus stricter command/evidence logging discipline in `WORKLOG.md`.

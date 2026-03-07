# Context

Updated: 2026-03-07

## Objective

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG, or reduce the remaining blocker to a specific upstream patch or vendor-only gap with strong evidence.

## Best Current Read

- IPU7 core support is present.
- `ov5675` is likely the correct sensor path.
- The strongest blocker is still MSI-specific `INT3472` / `TPS68470` board data or power sequencing.
- Local `linux-mainline` source path to reuse:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
  - current inspected tag: `v6.19`
- Exact MSI `OV5675` Windows package now documented:
  - Catalog entry: `Intel Corporation Driver Update (70.26100.19939.1)`
  - Scoped view: `https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=8fd6696d-67b8-4bc7-a477-6d8800725426`
  - local CAB: `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
  - extracted dir: `/tmp/ovti5675-msi/extracted2`
- This MSI package contains `ov5675.inf`, `ov5675_extension_msi.inf`, `iacamera64_ext_msi.inf`, `iactrllogic64.inf`, `iactrllogic64.sys`, and MSI/LNL graph-setting blobs.
- The Windows packages are now vendored in-repo for repeatable analysis:
  - `reference/windows-driver-packages/intel-control-logic-71.26100.23.20279/`
  - `reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/`
  - binary-heavy files under that archive path are tracked with Git LFS
- Additional local reference artifacts now kept in-repo:
  - `reference/tps68470.pdf`
  - `reference/linux-mainline-v6.19/drivers/platform/x86/intel/int3472/`
  - `reference/linux-torvalds-head/drivers/platform/x86/intel/int3472/`
- Current Torvalds `HEAD` snapshot details:
  - commit: `4ae12d8bd9a830799db335ee661d6cbc6597f838`
  - diff vs local `v6.19`: only `discrete.c` and `tps68470.c` changed
  - no observed new MSI board-data entry in `tps68470_board_data.c`
- Safe Linux-side reprobe harness is now in-repo:
  - script: `scripts/webcam-run.sh`
  - usage doc: `docs/reprobe-harness.md`
  - run archive root: `runs/`
  - safety boundary: snapshot + module reload only, no raw PMIC/I2C register writes
  - validated locally with `snapshot` and `reprobe-modules --dry-run` smoke tests using temporary run roots under `/tmp`
- First real run set is now captured under `runs/2026-03-08/`:
  - `20260308T001800-snapshot-baseline`
  - `20260308T001807-reprobe-modules-first-reprobe`
  - reprobe completed cleanly but reproduced the same `No board-data found for this model` failure
  - `media-ctl` still shows only the IPU-side topology with no sensor subdevice after reprobe
- Additional related-MSI low-level reference now captured:
  - `reference/greymouser-summit-13-ai-evo-a2vm.md`
  - related model: `MSI Summit 13 AI+ Evo A2VMTG`
  - board: `MS-13P5`
  - currently interesting for IIO sensor and LED-control work, not directly webcam-specific

Most important current log lines:

- `int3472-tps68470 i2c-INT3472:06: error -ENODEV: No board-data found for this model`
- `intel-ipu7 0000:00:05.0: no subdev found in graph`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`

## Open Questions

- Is a missing DMI match the only blocker?
- What regulator or GPIO sequencing does MSI require for this camera path?
- Can we extract enough information from the Windows package to patch Linux support cleanly?

## Next Actions

1. Correlate MSI `OV5675` graph-setting names such as `BCAB65` and `S5VM17` with ACPI-visible identifiers or module IDs.
2. Check whether this MSI DMI identity is supported under another variant string or in newer upstream changes beyond local `v6.19`.
3. Start extracting the concrete `TPS68470` sequencing logic from `iactrllogic64.sys`.

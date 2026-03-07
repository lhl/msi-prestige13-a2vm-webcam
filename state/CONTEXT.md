# Context

Updated: 2026-03-08

## Objective

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG, or reduce the remaining blocker to a specific upstream patch or vendor-only gap with strong evidence.

## Best Current Read

- IPU7 core support is present.
- `ov5675` is likely the correct sensor path.
- The strongest blocker is still MSI-specific `INT3472` / `TPS68470` board data or power sequencing.
- The Windows `iactrllogic64.sys` control-logic driver clearly contains board-specific `TPS68470` sequencing logic; it is not just an install stub.
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
- Repeatable reverse-engineering helpers are now in-repo:
  - `scripts/capture-acpi.sh`
  - `scripts/extract-iactrllogic64.sh`
  - canonical note: `docs/tps68470-reverse-engineering.md`
  - generated analysis tree: `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/`
- Current Windows-driver extraction result:
  - `iactrllogic64.sys` contains named `SensorInitialize`, `SensorOn`, `SensorOff`, clock, voltage, GPIO, and flash routines for `TPS68470`
  - recovered `StartClock` register write order: `0x0a`, `0x08`, `0x07`, `0x0b`, `0x0c`, `0x06`, `0x10`, `0x09`, `0x0d`
  - recovered a common low-level write helper at `0x140010be0` with retry behavior through `0x1400110f4`
  - recovered `VoltageWF` examples that read/modify/write registers `0x47` and `0x43`
- First real raw ACPI capture now exists in-repo:
  - `reference/acpi/20260308T004459-unknown-host/`
  - `dmi.txt` confirms product `Prestige 13 AI+ Evo A2VMG`, board `MS-13Q3`, BIOS `E13Q3IMS.109`, BIOS date `09/04/2024`
  - raw `acpidump.txt` contains camera-relevant `INT3472` and `CLDB` strings
  - extracted binary tables are present under `tables/`
  - the committed capture now also includes regenerated `dsdt.dsl`, `ssdt*.dsl`, a valid `camera-related-hits.txt`, and `live-linux-acpi-state.txt`
- The committed ACPI capture has now been reviewed from regenerated temp DSL:
  - `ssdt17.dat` / `MiCaTabl` contains the camera topology with `LNK*`, `DSC*`, and `CLP*` objects
  - the live active sensor is `OVTI5675:00` at `\_SB_.LNK0`
  - the live active PMIC companion is `INT3472:06` at `\_SB_.CLP0`
  - `INT3472:06` is the physical Linux I2C device `i2c-INT3472:06`
  - the inactive alternate path `INT3472:00` at `\_SB_.DSC0` also exists in firmware but is not selected on this machine
  - `CDEP()` in ACPI routes `LNK0` to `CLP0` when `C0TP > 1`, so this laptop is on the Windows PMIC path rather than the discrete `DSC0` path
- Windows-to-Linux register mapping is now partially confirmed:
  - Windows `StartClock` uses the same TPS68470 clock register family that Linux `clk-tps68470.c` programs
  - recovered voltage and IO helpers touch `VACTL` `0x47`, `S_I2C_CTL` `0x43`, and GPIO control registers `0x16` / `0x18`
- Linux-side implication:
  - `ov5675` expects `avdd`, `dovdd`, `dvdd`, `reset`, and 19.2 MHz `xvclk`
  - the likely blocker is missing MSI-specific `tps68470_board_data` for `i2c-INT3472:06` and `OVTI5675:00`, not just a missing DMI match
- `scripts/capture-acpi.sh` is now fixed to disassemble lowercase `dsdt.dat` / `ssdt*.dat`, keep `.dsl` outputs under `dsl/`, and capture `live-linux-acpi-state.txt` in future runs

Most important current log lines:

- `int3472-tps68470 i2c-INT3472:06: error -ENODEV: No board-data found for this model`
- `intel-ipu7 0000:00:05.0: no subdev found in graph`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`

## Open Questions

- Is a missing DMI match the only blocker?
- What regulator or GPIO sequencing does MSI require for this camera path?
- Can we extract enough information from the Windows package to patch Linux support cleanly?

## Next Actions

1. Derive an MSI `tps68470_board_data` candidate for `i2c-INT3472:06` and `OVTI5675:00`.
2. Continue recovering Windows `VoltageWF::*` and sensor-class behavior to confirm the exact rails and GPIO roles MSI uses.
3. Draft the smallest plausible Linux patch and compare it against the reprobe baseline.
4. Re-check whether any extra driver behavior beyond board-data is needed for the MSI path.

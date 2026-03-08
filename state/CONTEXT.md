# Context

Updated: 2026-03-08

## Objective

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG, or reduce the remaining blocker to a specific upstream patch or vendor-only gap with strong evidence.

## Best Current Read

- IPU7 core support is present.
- `ov5675` is the correct sensor path.
- The first patched `MS-13Q3` `tps68470_board_data` test moved the failure forward:
  - the old board-data error is gone
  - `i2c-OVTI5675:00` now exists
  - the sensor still does not bind
- The `ov5675` diagnostic patch narrowed the remaining blocker further:
  - `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`
- The strongest blocker is now the sensor firmware-graph hookup, not the
  original DMI match failure.
- The first `ov5675` diagnostic patch is now ready:
  - `reference/patches/ov5675-probe-diagnostics-v1.patch`
  - it turns the silent early `-ENXIO` exits into explicit kernel log lines
- The next patch candidate is now:
  - `reference/patches/ipu-bridge-ovti5675-v1.patch`
  - rationale: `OVTI5675` is absent from `ipu_bridge`'s
    `ipu_supported_sensors[]`
- The Windows `iactrllogic64.sys` control-logic driver clearly contains board-specific `TPS68470` sequencing logic; it is not just an install stub.
- Local `linux-mainline` source path to reuse:
  - package root: `~/.cache/paru/clone/linux-mainline`
  - cached bare Git repo: `~/.cache/paru/clone/linux-mainline/linux-mainline`
  - editable worktree path during `makepkg` prepare/build: `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
  - current cached upstream source:
    - describe: `v7.0-rc2-467-g4ae12d8bd9a8`
    - commit: `4ae12d8bd9a8`
  - there is no current `src/linux-mainline` worktree until `makepkg` creates it
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
  - recovered `VoltageWF::PowerOn`, `PowerOff`, `IoActive`, `IoActive_IO`, `IoActive_GPIO`, and `IoIdle` windows as durable artifacts under `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/`
  - `PowerOn` orchestrates staged VA / VD / VSIO / VCM helper calls
  - `PowerOff` tears down VA / VD / VCM while `VSIO` is handled via the IO refcount path
  - `IoActive_GPIO` configures `GPCTL1A` `0x16` and `GPCTL2A` `0x18`, which points to PMIC regular GPIO 1 and GPIO 2 on this board
- Current Linux patch candidate:
  - doc: `docs/linux-board-data-candidate.md`
  - patch: `reference/patches/ms13q3-int3472-tps68470-v1.patch`
  - validated with `git apply --check` against local `v6.19`
  - current first-pass mapping:
    - `TPS68470_ANA` => `avdd` on `i2c-OVTI5675:00`
    - `TPS68470_CORE` => `dvdd` on `i2c-OVTI5675:00`
    - `TPS68470_VSIO` => `dovdd` on `i2c-OVTI5675:00`
    - PMIC regular GPIO 1 / GPIO 2 as the initial camera-control guess
  - main remaining risk:
    - `ov5675.c` only consumes `reset`
    - Windows clearly uses both PMIC GPIO1 and GPIO2
    - a second Linux patch may still be needed for `powerdown` or swapped GPIO semantics
  - the same patch still applies cleanly to the current cached `v7.0-rc2` `tps68470_board_data.c` content extracted from the bare package cache
- Patched-kernel `v1` live-test result:
  - patched kernel booted successfully as `7.0.0-rc2-1-mainline-dirty`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `No board-data found for this model` is gone
  - `intel-ipu7 ... no subdev found in graph` still remains
  - `i2c-OVTI5675:00` now exists on the live I2C bus
  - `ov5675` is loaded but the sensor client is still unbound
  - a manual bind attempt returns `No such device or address`
  - there are still no `/dev/v4l-subdev*` nodes
- Diagnostic `ov5675` module-only test result:
  - `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`
  - `ipu_bridge` is loaded on the same kernel
  - local `ipu_bridge.c` only creates software-node graph endpoints for sensors
    listed in `ipu_supported_sensors[]`
  - `OVTI5675` is absent from that list
  - local `ov5675.c` expects one link frequency at `450000000`
- Important trap:
  - `readlink -f /sys/bus/i2c/devices/i2c-OVTI5675:00/driver` is misleading when the
    `driver` symlink does not exist
  - use `ls -l .../driver` or `readlink -e` when checking whether the sensor is
    actually bound
- Module-iteration trap:
  - the installed Arch modules are `.ko.zst`
  - for clean replacement, install a matching `.ko.zst` over the packaged path
    instead of leaving a second uncompressed `.ko` beside it
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
- First executed manual userland PMIC poke result:
  - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/`
  - the bus stayed healthy through clock setup and GPIO mode changes
  - the first PMIC transaction after `S_I2C_CTL=0x03` triggered `i2c_designware.1: controller timed out`
  - this means the initial manual sequence was non-diagnostic for sensor liveness; the next manual script revision now makes `S_I2C_CTL` the last PMIC write before direct chip-ID reads
- Second reordered manual userland PMIC poke attempt:
  - `runs/2026-03-08/20260308T021300-manual-i2c-sensor-check-second-manual-check/`
  - failed immediately on the initial `REVID` read before any writes
  - this means the controller was still wedged from the previous manual experiment
  - it does **not** provide any new evidence about the reordered `VA -> VD -> VSIO` sequence
- Linux-side implication:
  - `ov5675` expects `avdd`, `dovdd`, `dvdd`, `reset`, and 19.2 MHz `xvclk`
  - missing MSI-specific `tps68470_board_data` was real, but is no longer the
    leading blocker after `v1`
  - the next blocker is now more specifically the firmware graph hookup:
    - `OVTI5675` likely needs an `ipu_bridge` supported-sensor entry
    - only after that should we revisit `powerdown` or regulator details
- `scripts/capture-acpi.sh` is now fixed to disassemble lowercase `dsdt.dat` / `ssdt*.dat`, keep `.dsl` outputs under `dsl/`, and capture `live-linux-acpi-state.txt` in future runs

Most important current log lines:

- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`
- `intel-ipu7 0000:00:05.0: no subdev found in graph`
- manual bind follow-up:
  - `tee: /sys/bus/i2c/drivers/ov5675/bind: No such device or address`

## Open Questions

- Is a missing DMI match the only blocker?
- What regulator or GPIO sequencing does MSI require for this camera path?
- Can we extract enough information from the Windows package to patch Linux support cleanly?

## Next Actions

1. Apply and test `reference/patches/ipu-bridge-ovti5675-v1.patch`.
2. Rebuild and replace only the affected module:
   - `ipu-bridge`
3. Re-test whether:
   - `ov5675 ... no firmware graph endpoint found` disappears
   - a sensor subdevice appears in `media-ctl`
4. Only after that, revisit:
   - missing `powerdown` GPIO handling
   - wrong GPIO semantics
   - remaining regulator details

# Worklog

## 2026-03-08

### Review first ACPI capture and correlate it with live Linux plus Windows artifacts

- Plan: disassemble the captured ACPI tables from a writable temp area, identify the machine's active camera path, map that to the live ACPI/sysfs state, and fix the capture script based on the first-run failure.
- Commands:
  - regenerated DSL from the committed capture in temp:
    - copied `reference/acpi/20260308T004459-unknown-host/tables/*.dat` to `/tmp/ms13q3-acpi-review/`
    - `iasl -e ssdt*.dat -d dsdt.dat`
    - `iasl -d ssdt*.dat`
  - reviewed ACPI structure:
    - `/tmp/ms13q3-acpi-review/ssdt17.dsl`
    - `/tmp/ms13q3-acpi-review/dsdt-disasm.log`
    - `/tmp/ms13q3-acpi-review/ssdt-disasm.log`
  - reviewed live ACPI/sysfs state:
    - `/sys/bus/acpi/devices/OVTI5675:00/*`
    - `/sys/bus/acpi/devices/INT3472:06/*`
    - `/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-INT3472:06/*`
  - reviewed Linux-side consumers and PMIC register definitions:
    - `drivers/media/i2c/ov5675.c`
    - `drivers/platform/x86/intel/int3472/tps68470.c`
    - `drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `drivers/clk/clk-tps68470.c`
    - `drivers/regulator/tps68470-regulator.c`
    - `include/linux/mfd/tps68470.h`
  - `apply_patch` fixing `scripts/capture-acpi.sh` and updating the canonical note and state files
- Result:
  - confirmed the camera topology lives in `ssdt17.dat` / `MiCaTabl`, which defines six `LNK*` sensor links, six `DSC*` `INT3472` PMIC nodes, and six `CLP*` `INT3472` PMIC nodes backed by an `MNVS` operation region
  - confirmed the live active sensor is `OVTI5675:00` at ACPI path `\_SB_.LNK0` with `status=15`
  - confirmed the live active PMIC companion is `INT3472:06` at ACPI path `\_SB_.CLP0` with `status=15`, and its physical Linux device is `i2c-INT3472:06`
  - confirmed the alternate `DSC0` `INT3472:00` path exists but is inactive on this machine
  - confirmed `CDEP()` in the ACPI table selects `DSC0 + I2C bus` only when `C0TP == 1`, but returns `CLP0` when `C0TP > 1`; this laptop is therefore on the Windows PMIC companion path, not the simpler discrete path
  - confirmed the Windows `StartClock` register sequence maps directly to Linux TPS68470 clock registers:
    - `0x06` `POSTDIV2`
    - `0x07` `BOOSTDIV`
    - `0x08` `BUCKDIV`
    - `0x09` `PLLSWR`
    - `0x0A` `XTALDIV`
    - `0x0B` `PLLDIV`
    - `0x0C` `POSTDIV`
    - `0x0D` `PLLCTL`
    - `0x10` `CLKCFG2`
  - confirmed `ov5675` expects regulators `avdd`, `dovdd`, and `dvdd`, plus a `reset` GPIO and a 19.2 MHz clock
  - confirmed the likely blocker is now narrower:
    - missing MSI-specific `tps68470_board_data` for `i2c-INT3472:06`
    - likely with `OVTI5675:00`-specific regulator consumer mappings and GPIO policy
    - not just a missing DMI string
  - fixed `scripts/capture-acpi.sh` so future runs disassemble lowercase `dsdt.dat` and `ssdt*.dat` files correctly
- Decision: keep; this is the first machine-specific ACPI-to-Linux path confirmation and it narrows the next patch-design work to MSI `TPS68470` board data and PMIC policy.

### Commit first ACPI capture for MSI `MS-13Q3`

- Plan: commit the first real root-collected ACPI capture from this laptop before deeper analysis, and record both the successful raw dump and the script failure that left the DSL pass incomplete.
- Commands:
  - `sudo scripts/capture-acpi.sh`
  - reviewed:
    - `reference/acpi/20260308T004459-unknown-host/metadata.env`
    - `reference/acpi/20260308T004459-unknown-host/dmi.txt`
    - `reference/acpi/20260308T004459-unknown-host/acpidump.txt`
    - `reference/acpi/20260308T004459-unknown-host/acpixtract.log`
    - `reference/acpi/20260308T004459-unknown-host/dsl/ssdt-disasm.log`
- Result:
  - captured the first in-repo raw ACPI dump for this exact machine under `reference/acpi/20260308T004459-unknown-host/`
  - confirmed DMI identity from the same capture:
    - product: `Prestige 13 AI+ Evo A2VMG`
    - board: `MS-13Q3`
    - BIOS: `E13Q3IMS.109`
    - BIOS date: `09/04/2024`
  - confirmed the raw dump contains camera-relevant `INT3472` and `CLDB` strings
  - confirmed binary ACPI tables were extracted successfully under `tables/`
  - confirmed the first `iasl` disassembly attempt failed because `scripts/capture-acpi.sh` expected uppercase `DSDT.dat` and `SSDT*.dat` while this run produced lowercase `dsdt.dat` and `ssdt*.dat`
  - confirmed `camera-related-hits.txt` is empty in this first run because the DSL generation step failed
- Decision: keep; the raw capture is valid and should be preserved now, then analyzed and followed by a script fix in a separate step.

### Add canonical ACPI plus Windows-control-logic reverse-engineering workflow

- Plan: make the ACPI capture and Windows `iactrllogic64.sys` analysis reproducible in-repo, then write one canonical note that preserves the concrete reverse-engineering results.
- Commands:
  - checked current constraints:
    - `which acpidump`
    - `sudo -n true`
    - `ls -l /sys/firmware/acpi/tables`
    - `acpidump -b`
  - added scripts:
    - `scripts/capture-acpi.sh`
    - `scripts/extract-iactrllogic64.sh`
  - generated Windows analysis artifacts:
    - `scripts/extract-iactrllogic64.sh`
  - reviewed generated outputs:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/debug-directory.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/pe-header-and-imports.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-addresses.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoron.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoroff.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-start.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-confighclkab.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvactl.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvsioctl-gpio.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-register-write-wrapper.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-transport-helper.txt`
- Result:
  - added a root-capable ACPI capture helper that stores reproducible evidence under `reference/acpi/`
  - confirmed raw ACPI table capture is still blocked from the current unprivileged session because `/sys/firmware/acpi/tables/*` is root-readable only
  - generated a stable in-repo analysis tree for `iactrllogic64.sys`
  - confirmed the Windows driver contains named `TPS68470` sensor, clock, voltage, GPIO, and flash routines plus `CommonFunc::Cmd_SensorPowerOn` / `Cmd_SensorPowerOff`
  - confirmed the binary build provenance:
    - PDB path `W:\repo\w\camerasw\Source\Camera\Platform\LNL\x64\Release\iactrllogic64.pdb`
    - PDB GUID `804BA0D7-738B-4CC9-8027-7AF3103C24B5`
  - recovered a concrete `Tps68470Clock::StartClock` write sequence using registers `0x0a`, `0x08`, `0x07`, `0x0b`, `0x0c`, `0x06`, `0x10`, `0x09`, and `0x0d`
  - recovered a `ConfigHCLKAB` helper that reads and masks register `0x0d` before writing it back
  - recovered a common register-write helper at `0x140010be0` that retries through `0x1400110f4`
  - recovered `VoltageWF` examples that read/modify/write at least registers `0x47` and `0x43`
- Decision: keep; this is now the canonical reverse-engineering base for the next ACPI capture and Linux patch-design pass.

### Commit first baseline snapshot and reprobe run set

- Plan: record the first real `runs/` output from the safe harness so the baseline failure state and exact reprobe behavior are preserved in git.
- Commands:
  - `scripts/webcam-run.sh snapshot --label baseline --note "before first reprobe"`
  - `sudo scripts/webcam-run.sh reprobe-modules --label first-reprobe --note "baseline reprobe after boot"`
  - reviewed:
    - `runs/2026-03-08/20260308T001800-snapshot-baseline/summary.env`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/summary.env`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/action.log`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/journal-since-run-start.txt`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/media-ctl-media0.txt`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/v4l2-list-devices.txt`
- Result:
  - captured the first baseline snapshot and first real reprobe run under `runs/2026-03-08/`
  - confirmed the reprobe sequence completed successfully with no module-load failures
  - confirmed the same blocker reproduces cleanly after reprobe:
    - `TPS68470 REVID: 0x21`
    - `error -ENODEV: No board-data found for this model`
    - `intel-ipu7 ... no subdev found in graph`
  - confirmed `media-ctl` still shows an IPU-only topology with no sensor subdevice attached after reprobe
- Decision: keep; this is the baseline evidence batch for future diffs against patched kernels or new sequencing hypotheses.

### Add related MSI Summit 13 low-level Linux repo as a future comparison reference

- Plan: capture a nearby MSI Lunar Lake Linux-support repo that is not webcam-specific but may still hold useful board-level patterns for later comparison.
- Commands:
  - opened `https://github.com/greymouser/Summit-13-AI-Evo-A2VM`
  - `apply_patch` adding `reference/greymouser-summit-13-ai-evo-a2vm.md`
  - `apply_patch` updating `reference/README.md`, `README.md`, and `state/CONTEXT.md`
- Result:
  - added a reference note for the related `MSI Summit 13 AI+ Evo A2VMTG` / `MS-13P5` repo
  - captured that its visible Linux focus is currently IIO sensor support and audio mute / speaker LED control
  - recorded it as a future low-level comparison source rather than a direct webcam bring-up reference
- Decision: keep; related MSI platform work may expose useful DMI, ACPI, firmware, or vendor-integration patterns later.

### Build safe snapshot/reprobe harness for repeatable Linux testing

- Plan: add a low-risk harness that records every meaningful reprobe attempt with enough evidence to analyze failures later, without doing raw PMIC or I2C register writes.
- Commands:
  - inspected current repo docs and plan files
  - inspected current sysfs driver hooks for `int3472-tps68470` and `ov5675`
  - inspected current module state and kernel logs
  - `apply_patch` adding `scripts/webcam-run.sh`
  - `apply_patch` adding `docs/reprobe-harness.md`
  - `apply_patch` adding `runs/README.md`
  - `apply_patch` updating `README.md`, `docs/README.md`, `PLAN.md`, and `state/CONTEXT.md`
  - `bash -n scripts/webcam-run.sh`
  - `scripts/webcam-run.sh snapshot --runs-root /tmp/...`
  - `scripts/webcam-run.sh reprobe-modules --dry-run --runs-root /tmp/...`
- Result:
  - added `scripts/webcam-run.sh` with two actions: `snapshot` and `reprobe-modules`
  - each run now captures pre/post state, exact step order, filtered kernel logs, media/V4L2 output, and relevant sysfs state under `runs/`
  - the harness is explicitly limited to snapshot and module reload activity; it does not do `i2cset`, raw `i2ctransfer` writes, or address-scanning `i2cdetect`
  - documented the run layout and usage in `docs/reprobe-harness.md`
  - smoke-tested `snapshot` and `reprobe-modules --dry-run` successfully using temporary run roots under `/tmp`
- Decision: keep; this gives us a repeatable low-risk testing baseline before any deeper reverse engineering or kernel patching.

## 2026-03-07

### Snapshot Torvalds `HEAD` `int3472` subtree for upstream comparison

- Plan: capture the current upstream `drivers/platform/x86/intel/int3472/` tree from Torvalds Linux `HEAD` and compare it against the local `v6.19` snapshot.
- Commands:
  - opened `https://web.git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/platform/x86/intel/int3472`
  - opened `https://github.com/torvalds/linux/tree/master/drivers/platform/x86/intel/int3472`
  - `git ls-remote https://github.com/torvalds/linux.git HEAD`
  - sparse-cloned Torvalds Linux `HEAD` and copied `drivers/platform/x86/intel/int3472/`
  - `git diff --no-index --stat -- reference/linux-mainline-v6.19/drivers/platform/x86/intel/int3472 reference/linux-torvalds-head/drivers/platform/x86/intel/int3472`
- Result:
  - captured Torvalds `HEAD` at `4ae12d8bd9a830799db335ee661d6cbc6597f838`
  - added an in-repo upstream snapshot under `reference/linux-torvalds-head/`
  - confirmed that only `discrete.c` and `tps68470.c` differ from the local `v6.19` snapshot
  - did not observe a new MSI board-data entry in `tps68470_board_data.c`
- Decision: keep; this narrows the current upstream delta and confirms that plain upstream drift has not already fixed the MSI board-data gap.

### Vendor Windows package trees, TPS68470 PDF, and local `int3472` kernel snapshot

- Plan: move the active binary artifacts and local source snapshot into `reference/` so future reverse engineering does not depend on `/tmp` or the paru cache path.
- Commands:
  - `git lfs track 'reference/windows-driver-packages/**/*.cab' 'reference/windows-driver-packages/**/*.sys' 'reference/windows-driver-packages/**/*.dll' 'reference/windows-driver-packages/**/*.bin' 'reference/windows-driver-packages/**/*.aiqb' 'reference/windows-driver-packages/**/*.cpf' 'reference/windows-driver-packages/**/*.cat' 'reference/windows-driver-packages/**/*.bmp'`
  - copied `/tmp/int3472-winpkg/intel-control-logic-71.26100.23.20279.cab`
  - copied `/tmp/int3472-winpkg/extracted`
  - copied `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
  - copied `/tmp/ovti5675-msi/extracted2`
  - `git lfs track 'reference/**/*.pdf'`
  - copied `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/`
- Result:
  - vendored the two Windows package trees into `reference/windows-driver-packages/`
  - enabled Git LFS for the binary-heavy Windows-package payloads and for PDFs under `reference/`
  - added a local reference copy of `drivers/platform/x86/intel/int3472/` from the inspected `v6.19` tree
  - added `reference/tps68470.pdf` to the repo as a local PMIC datasheet reference
- Decision: keep; this lowers future setup cost and gives us stable in-repo inputs for both Windows-package and kernel-source analysis.

### Document exact MSI `OV5675` Catalog package and local download path

- Plan: record the exact Microsoft Update Catalog entry, direct CAB URL, and local download paths for the MSI-submitted `OV5675` package so we can reliably reopen it later.
- Commands:
  - opened `https://www.catalog.update.microsoft.com/Search.aspx?q=ACPI%5COVTI5675`
  - opened `https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=8fd6696d-67b8-4bc7-a477-6d8800725426`
  - downloaded `https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2026/02/8a77f110-818a-4dee-b65b-291e97512d0f_0e7b66ca05a48e8131f5ef36e983f419b4ebef52.cab`
  - extracted `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
- Result:
  - confirmed the exact MSI package entry is `Intel Corporation Driver Update (70.26100.19939.1)`
  - confirmed company field `MICRO-STAR INTERNATIONAL CO., LTD`
  - confirmed supported hardware ID `ACPI\\OVTI5675`
  - documented the direct CAB URL plus local paths in `reference/msi-ov5675-microsoft-update-catalog-70.26100.19939.1.md`
- Decision: keep; this makes the Windows package reference stable and removes the need to rediscover the exact Catalog entry.

### Tighten AGENTS progress-summary expectations

- Plan: make user-facing updates state the concrete result or blocker, so status stays useful as the repo and session history grow.
- Commands:
  - `nl -ba AGENTS.md | sed -n '1,220p'`
  - `apply_patch` updating `AGENTS.md`
- Result:
  - added a `Communication rules` section to `AGENTS.md`
  - future progress updates are now required to state what was actually done and what was actually learned
  - if there is no substantive result yet, the update must say that explicitly instead of only describing activity
- Decision: keep; this should make multi-step research sessions easier to follow and audit.

### Document local `linux-mainline` source location and board-data status

- Plan: record the exact local kernel-source path and the concrete `v6.19` finding so it is easy to reopen the same files later.
- Commands:
  - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline rev-parse --short HEAD`
  - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline describe --tags --always`
  - `nl -ba ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c | sed -n '240,336p'`
  - `nl -ba ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470.c | sed -n '176,184p'`
  - `nl -ba ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c | sed -n '1355,1379p'`
- Result:
  - documented the reusable local source location as `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
  - confirmed that local source is `v6.19` at `05f7e89ab973`
  - confirmed `tps68470_board_data.c` only contains Surface Go variants and Dell Latitude 7212, with no MSI `MS-13Q3` / `Prestige 13 AI+ Evo A2VMG`
  - confirmed the `ov5675` ACPI match for `OVTI5675` exists in the same tree
- Decision: keep; this closes the first local-kernel-tree inspection step and gives us a stable place to resume from later.

### Add shared `CLAUDE.md` symlink

- Plan: add a repo-local `CLAUDE.md` symlink pointing to `AGENTS.md` so Codex and Claude Code read the same instructions.
- Commands:
  - `ln -s AGENTS.md CLAUDE.md`
  - `ls -l AGENTS.md CLAUDE.md`
- Result:
  - created relative symlink `CLAUDE.md -> AGENTS.md`
  - repo now has one shared instruction source for both tools
- Decision: keep; this avoids instruction drift between parallel agent environments.

### AGENTS commit-discipline update

- Plan: tighten `AGENTS.md` so multi-agent and mixed human/agent work in one worktree stays safe.
- Commands:
  - `nl -ba AGENTS.md | sed -n '1,220p'`
  - `apply_patch` updating `AGENTS.md`
- Result:
  - commit policy now explicitly requires frequent commits on logical task completion
  - commit units are defined as coherent evidence/doc/probe/patch bundles
  - staged-diff review commands are now part of the written repo policy
- Decision: keep; this should reduce cross-agent drift and make future hardware bring-up sessions easier to isolate and review.

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

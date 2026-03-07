# Worklog

## 2026-03-07

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

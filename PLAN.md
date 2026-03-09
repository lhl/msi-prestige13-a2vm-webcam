# Webcam Bring-Up Plan

Updated: 2026-03-09

This is the active plan for getting the MSI Prestige 13 AI+ Evo A2VMG webcam working on Linux and for documenting the investigation cleanly as we go.

## Goal

Reach a point where the built-in webcam is usable from normal Linux userspace, or reduce the remaining blocker to a specific upstream patch, firmware dependency, or vendor-only gap with strong evidence.

## Current Assessment

- IPU7 core support is present enough to enumerate the Lunar Lake IPU and load firmware.
- The first patched `tps68470_board_data` test succeeded partially:
  - the old `No board-data found for this model` failure is gone
  - `i2c-OVTI5675:00` is now instantiated on the live I2C bus
- The strongest current blocker has moved forward to the sensor side:
  - `ipu-bridge` now finds `OVTI5675:00` and reports one connected camera
  - `ov5675` still does not bind successfully to `i2c-OVTI5675:00`
  - on a clean combined-patch boot:
    - the old `dvdd` timeout is gone
    - `ov5675 ... failed to find sensor: -5`
  - on the first clean boot after adding `powerdown` handling:
    - the same `ov5675 ... failed to find sensor: -5` lines remain
  - on the first identify-debug reload run:
    - `setup of GPIO reset failed: -110`
    - `failed to get reset-gpios: -110`
    - `probe with driver ov5675 failed with error -110`
  - on the first clean boot with identify-debug parameters active on first load:
    - `chip id read attempt 1/5 failed: -110`
    - `chip id read attempt 2/5 failed: -110`
    - `chip id read attempt 3/5 failed: -110`
    - `chip id read attempt 4/5 failed: -110`
    - `chip id read attempt 5/5 failed: -110`
    - `failed to find sensor: -110`
  - on the three staged `ov5675` GPIO-release clean boots from `2026-03-09`:
    - `sequence=1`, `delay_us=2000`: still `-110`
    - `sequence=2`, `delay_us=2000`: still `-110`
    - control `sequence=0`: still `-110`
  - there are still no `/dev/v4l-subdev*` nodes
  - the current Windows-vs-ACPI analysis still favors the `WF` / `LNK0` path
    over a premature `UF` / `gpio.4` pivot
  - the latest Windows-source pull now shows concrete `WF` PMIC behavior that
    Linux does not yet model:
    - default/configured voltage tuple `1050 / 2800 / 1800 / 2800 / 1800`
    - PMIC value-register writes `0x41`, `0x40`, `0x42`, `0x3c`, `0x3f`
    - staged `S_I2C_CTL` handling around register `0x43`

## Evidence Baseline

- [x] Capture the Intel upstream issue for this laptop family.
- [x] Capture the Jeremy Grosser MSI gist and later comments.
- [x] Record a current local support assessment in `docs/webcam-status.md`.
- [x] Confirm local machine identity, kernel version, PCI binding, and loaded modules.
- [x] Record the exact local `linux-mainline` source location and current `v6.19` board-data status in `docs/kernel-tree-status.md`.
- [x] Capture a clean media graph dump once direct device access is available for testing.
- [x] Add a root-capable ACPI capture script for this exact machine.
- [x] Capture ACPI and DMI details relevant to existing `INT3472` board-data matching logic.
- [x] Identify the active live ACPI camera path and companion `INT3472` device on this machine.
- [x] Test the first `MS-13Q3` `tps68470_board_data` patch on a booted patched kernel.

## Workstreams

### 1. Upstream gap analysis

- [x] Inspect current local `v6.19` `drivers/platform/x86/intel/int3472/tps68470_board_data.c`.
- [x] Snapshot the local `drivers/platform/x86/intel/int3472/` subtree into `reference/` for easier side-by-side work.
- [x] Snapshot current Torvalds `HEAD` `drivers/platform/x86/intel/int3472/` and compare it against local `v6.19`.
- [ ] Check whether this MSI DMI identity is already supported under another variant string.
- [ ] Search recent kernel and mailing-list activity for Lunar Lake `ov5675`, `INT3472`, or `TPS68470` additions.
- [x] Determine that the blocker is not only missing board-data matching.
- [ ] Determine whether the remaining blocker is:
  - missing `ov5675` GPIO handling
  - missing firmware / graph-endpoint hookup
  - remaining regulator or sequencing details

### 2. Local machine evidence

- [x] Build a safe snapshot/reprobe harness that records pre/post state and exact action order under `runs/`.
- [x] Run direct media and V4L2 probing:
  - `media-ctl -p -d /dev/media0`
  - `v4l2-ctl --list-devices`
  - targeted `v4l2-ctl --all -d /dev/video*`
- [x] Save exact boot-log excerpts for failed probe attempts and preserve room for later successful-probe captures.
- [x] Record the change from stock `6.18.9-arch1-2` to patched `7.0.0-rc2-1-mainline-dirty`.
- [x] Confirm that the patched kernel changes the failure mode:
  - sensor client instantiated
  - board-data error removed
  - sensor still not bound

### 3. Vendor / Windows clue extraction

- [x] Identify the MSI Windows camera-related package(s) for this machine.
- [x] Inspect driver package contents for `iactrllogic64`, INF files, registry settings, GPIO hints, or regulator programming clues.
- [x] Vendor the current Windows camera packages into the repo with Git LFS so future analysis does not depend on `/tmp`.
- [x] Add a repeatable `iactrllogic64.sys` static-analysis extractor and generated artifacts.
- [x] Map recovered register-write sequences and control-flow findings back to Linux `TPS68470` driver structures.

### 4. Patch path

- [x] If board-data matching is missing, draft the smallest possible kernel patch for this model.
- [ ] If additional sequencing data is needed, document exactly what is still unknown before patching.
- [ ] Re-test after each change and record results in `WORKLOG.md`.

## Near-Term Priority

1. Treat the first `powerdown-v1` clean-boot test as a negative result.
2. Use the clean-boot identify-debug result as the new baseline:
   - repeated chip-ID read timeouts `-110`
3. Treat all three staged `ov5675` GPIO-release clean boots from `2026-03-09`
   as negative:
   - `sequence=1`, `delay_us=2000`
   - `sequence=2`, `delay_us=2000`
   - control `sequence=0`
4. Use the new Windows-source pull to determine whether the next real fix is:
   - missing `WF` value-register programming
   - missing staged `S_I2C_CTL` handling
   - wrong Linux `CORE` / `VD` voltage assumption
5. Use the scripted PMIC experiment wrappers for the ordered follow-ups above:
   - `scripts/exp1-pmic-instrumentation-update.sh`
   - `scripts/exp2-wf-s-i2c-ctl-update.sh`
   - `scripts/exp3-ms13q3-vd-1050mv-update.sh`
   - `scripts/exp4-wf-init-value-programming-update.sh`
   - `scripts/exp5-wf-gpio-mode-followup-update.sh`
   - `scripts/exp6-uf-gpio4-last-resort-update.sh`
   - run the matching `*-verify.sh` wrapper after reboot
   - the default experiment patch files now exist under `reference/patches/`
   - the update wrappers now reverse previously-applied PMIC experiment patches
     by default so the experiments can be run sequentially with clean
     attribution
6. Treat label-only `GPIO1` / `GPIO2` swaps as low-signal with the current
   `ov5675` power sequence:
   - both control lines are driven in lockstep during power-on and power-off
   - the next meaningful electrical change is polarity, not another pure role
     swap
7. Treat both one-line polarity variants as negative:
   - `GPIO2` active-high: negative
   - `GPIO1` active-high: negative
8. Do not jump to a `gpio.4` / `UF` redesign first:
   - the `UF` path is real
   - local ACPI still favors `WFCS -> LNK0`
9. Keep full kernel rebuilds as a fallback only when a change stops being
   module-local.

## Open Questions

- Was the missing piece just a DMI match entry, or does MSI require custom regulator and GPIO data not present upstream?
- Answer so far: not just a DMI match; board-data was necessary but not sufficient.
- Does `ov5675` fail because it lacks a second GPIO such as `powerdown`, or because it never receives the expected firmware graph endpoint?
- Answer so far: the graph-endpoint problem was also real and is now fixed.
- The serial power-on follow-up was also real: the old `dvdd` timeout is gone.
- The first `powerdown` follow-up was a negative result.
- The first identify-debug reload run was also non-diagnostic.
- The first clean-boot identify-debug run was a real narrowing step:
  - `ov5675_identify_module()` is reached
  - repeated chip-ID reads time out with `-110`
- The three staged `ov5675` GPIO-release clean boots were also negative.
- The next open question is whether Linux now needs:
  - `WF` value-register programming before rail enables
  - staged `S_I2C_CTL` behavior
  - a different `CORE` / `VD` voltage assumption
- The repo now has scripted wrappers for those ordered experiments:
  - update/install/reboot via `scripts/exp*-*-update.sh`
  - clean-boot verification via `scripts/exp*-*-verify.sh`
- The latest Windows-helper analysis adds one important guardrail:
  - the package has both `WF` and `UF` helper families
  - `UF` touches what Linux would call `gpio.4`
  - but this laptop's active ACPI path is still `WFCS -> LNK0`, so `gpio.4`
    should not be the first follow-up without stronger local evidence
- Current diagnostic gap:
  - we now know the identify stage times out
  - lockstep GPIO release changes and staged `ov5675` release tests have all
    been negative
  - the next gap is which `WF` PMIC behavior Linux must reproduce for this
    board
- Is there any vendor firmware or Intel middleware dependency beyond standard kernel and firmware files?
- Does this machine correspond to the Windows driver's `VoltageWF` path, `VoltageUF` path, or a narrower subclass selected via ACPI / board config?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- Reference notes under `reference/`
- Current support summary under `docs/`
- If feasible, a minimal patch or patch-ready technical note describing the needed change

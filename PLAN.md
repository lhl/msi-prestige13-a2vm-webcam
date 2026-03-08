# Webcam Bring-Up Plan

Updated: 2026-03-08

This is the active plan for getting the MSI Prestige 13 AI+ Evo A2VMG webcam working on Linux and for documenting the investigation cleanly as we go.

## Goal

Reach a point where the built-in webcam is usable from normal Linux userspace, or reduce the remaining blocker to a specific upstream patch, firmware dependency, or vendor-only gap with strong evidence.

## Current Assessment

- IPU7 core support is present enough to enumerate the Lunar Lake IPU and load firmware.
- The first patched `tps68470_board_data` test succeeded partially:
  - the old `No board-data found for this model` failure is gone
  - `i2c-OVTI5675:00` is now instantiated on the live I2C bus
- The strongest current blocker has moved forward to the sensor side:
  - `intel-ipu7 ... no subdev found in graph`
  - `ov5675` still does not bind successfully to `i2c-OVTI5675:00`
  - there are still no `/dev/v4l-subdev*` nodes

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

1. Reboot into the same combined-patch kernel and capture a clean baseline
   before any manual reprobe disturbs `INT3472`.
2. Verify whether the clean boot still shows:
   - `intel-ipu7 ... Found supported sensor OVTI5675:00`
   - `Connected 1 cameras`
   - `supply avdd/dovdd/dvdd not found, using dummy regulator`
3. If the supply warnings remain on a clean boot, determine whether the next
   patch is:
   - board-data regulator consumer follow-up
   - optional `powerdown` support in `ov5675.c`
   - GPIO semantic swap
4. Keep full kernel rebuilds as a fallback only when a change stops being
   module-local.

## Open Questions

- Was the missing piece just a DMI match entry, or does MSI require custom regulator and GPIO data not present upstream?
- Answer so far: not just a DMI match; board-data was necessary but not sufficient.
- Does `ov5675` fail because it lacks a second GPIO such as `powerdown`, or because it never receives the expected firmware graph endpoint?
- Is there any vendor firmware or Intel middleware dependency beyond standard kernel and firmware files?
- Does this machine correspond to the Windows driver's `VoltageWF` path, `VoltageUF` path, or a narrower subclass selected via ACPI / board config?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- Reference notes under `reference/`
- Current support summary under `docs/`
- If feasible, a minimal patch or patch-ready technical note describing the needed change

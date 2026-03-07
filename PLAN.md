# Webcam Bring-Up Plan

Updated: 2026-03-07

This is the active plan for getting the MSI Prestige 13 AI+ Evo A2VMG webcam working on Linux and for documenting the investigation cleanly as we go.

## Goal

Reach a point where the built-in webcam is usable from normal Linux userspace, or reduce the remaining blocker to a specific upstream patch, firmware dependency, or vendor-only gap with strong evidence.

## Current Assessment

- IPU7 core support is present enough to enumerate the Lunar Lake IPU and load firmware.
- The likely sensor path is no longer completely opaque:
  - ACPI exposes `OVTI5675:00`
  - the `ov5675` kernel module is loaded
- The strongest current blocker is still the `INT3472` / `TPS68470` path:
  - `error -ENODEV: No board-data found for this model`
  - `intel-ipu7 ... no subdev found in graph`

## Evidence Baseline

- [x] Capture the Intel upstream issue for this laptop family.
- [x] Capture the Jeremy Grosser MSI gist and later comments.
- [x] Record a current local support assessment in `docs/webcam-status.md`.
- [x] Confirm local machine identity, kernel version, PCI binding, and loaded modules.
- [ ] Capture a clean media graph dump once direct device access is available for testing.
- [ ] Capture ACPI and DMI details relevant to existing `INT3472` board-data matching logic.

## Workstreams

### 1. Upstream gap analysis

- [ ] Inspect current upstream `drivers/platform/x86/intel/int3472/tps68470_board_data.c`.
- [ ] Check whether this MSI DMI identity is already supported under another variant string.
- [ ] Search recent kernel and mailing-list activity for Lunar Lake `ov5675`, `INT3472`, or `TPS68470` additions.
- [ ] Determine whether the blocker is only missing board-data matching or also missing regulator/GPIO sequencing details.

### 2. Local machine evidence

- [ ] Run direct media and V4L2 probing:
  - `media-ctl -p -d /dev/media0`
  - `v4l2-ctl --list-devices`
  - targeted `v4l2-ctl --all -d /dev/video*`
- [ ] Save exact boot-log excerpts for successful and failed probe attempts.
- [ ] Record any changes across kernel versions if testing on multiple kernels.

### 3. Vendor / Windows clue extraction

- [ ] Identify the MSI Windows camera-related package(s) for this machine.
- [ ] Inspect driver package contents for `iactrllogic64`, INF files, registry settings, GPIO hints, or regulator programming clues.
- [ ] Map any discovered identifiers or sequencing steps back to Linux driver structures.

### 4. Patch path

- [ ] If board-data matching is missing, draft the smallest possible kernel patch for this model.
- [ ] If additional sequencing data is needed, document exactly what is still unknown before patching.
- [ ] Re-test after each change and record results in `WORKLOG.md`.

## Near-Term Priority

1. Inspect upstream `tps68470_board_data.c` coverage.
2. Pull the MSI Windows camera package and look for concrete board-data clues.
3. Re-run direct `media-ctl` / `v4l2-ctl` probing now that full device access is available.

## Open Questions

- Is the missing piece just a DMI match entry, or does MSI require custom regulator and GPIO data not present upstream?
- Does `ov5675` probe far enough to appear in the media graph once PMIC board data exists, or is there a second blocker after power-up?
- Is there any vendor firmware or Intel middleware dependency beyond standard kernel and firmware files?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- Reference notes under `reference/`
- Current support summary under `docs/`
- If feasible, a minimal patch or patch-ready technical note describing the needed change

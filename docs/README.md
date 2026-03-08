# Docs Index

Current focus:

- Restart capsule: `../state/CONTEXT.md`
- Active plan: `../PLAN.md`
- Active work log: `../WORKLOG.md`
- Current technical status: `docs/webcam-status.md`

## Core Docs

- `docs/webcam-status.md` — current Linux webcam support assessment for this laptop
- `docs/kernel-tree-status.md` — exact local `linux-mainline` source path and current `v6.19` INT3472/TPS68470 finding
- `docs/reprobe-harness.md` — safe snapshot/reprobe script and run-capture workflow
- `docs/tps68470-reverse-engineering.md` — canonical note for ACPI capture plus Windows `iactrllogic64.sys` analysis
- `docs/linux-board-data-candidate.md` — current MSI `tps68470_board_data` hypothesis and first patched-test plan
- `docs/module-iteration.md` — faster module-only rebuild/install workflow for camera-path changes

## Repo-Level Control Docs

- `../state/CONTEXT.md` — one-screen restart capsule with current objective and next actions
- `../PLAN.md` — active investigation plan and task queue
- `../WORKLOG.md` — reverse-chronological record of work performed
- `../AGENTS.md` — repo workflow guide
- `../README.md` — repo entrypoint and layout

## References

- `../reference/README.md` — index of captured upstream sources

## Expected Growth

As the investigation expands, add new synthesized notes here rather than burying them in ad-hoc root files. Likely future docs:

- patch design notes
- kernel-version comparison notes
- media-graph and validation logs

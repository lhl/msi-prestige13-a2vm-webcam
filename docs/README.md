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
- `docs/ov5675-gpio-release-sequencing-followup.md` — current `ov5675` module-only GPIO-sequencing debug branch after both one-line polarity variants failed
- `docs/int3472-gpio1-powerdown-active-high-followup.md` — latest negative `INT3472` physical-line polarity follow-up after the first polarity result
- `docs/int3472-gpio-polarity-followup.md` — earlier negative first `INT3472` polarity follow-up
- `docs/int3472-gpio-swap-followup.md` — earlier negative `INT3472` board-data role-swap test on the existing `GPIO1` / `GPIO2` pair
- `docs/module-iteration.md` — faster module-only rebuild/install workflow for camera-path changes
- `docs/ov5675-diagnostic-patch.md` — first `ov5675` probe-logging patch and exact module-only test steps
- `docs/ipu-bridge-ovti5675-candidate.md` — current `ipu-bridge` follow-up patch candidate after the `ov5675` diagnostic result
- `docs/ov5675-power-on-order.md` — next `ov5675` power-on sequencing hypothesis after the clean-boot `dvdd` timeout
- `docs/ov5675-powerdown-followup.md` — next `ov5675` GPIO follow-up after the clean-boot serial-power result
- `docs/ov5675-identify-debug-followup.md` — next `ov5675` identify/debug branch after the negative `powerdown-v1` result
- `docs/wf-vs-uf-gpio-analysis.md` — Windows helper-family analysis for deciding whether this laptop still matches the `WF` / `LNK0` GPIO model
- `docs/pmic-followup-experiments.md` — ordered PMIC experiment matrix and the scripted update/reboot/verify workflow for experiments 1-6
- `docs/patch-kernel-workflow.md` — idempotent patch-stack workflow for the local `linux-mainline` tree
- `docs/test-routines.md` — numbered test wrappers for clean-boot and reload checkpoints

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

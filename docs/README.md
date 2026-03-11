# Docs Index

Current focus:

- Restart capsule: `../state/CONTEXT.md`
- Active plan: `../PLAN.md`
- Active work log: `../WORKLOG.md`
- Short live status: `docs/webcam-status.md`
- Full March 9 report: `docs/20260309-status-report.md`

## Core Docs

- `docs/antti-prestige14-thread-review.md` — review of the March 10, 2026
  Antti Laakso MSI Prestige 14 patch thread and what its daisy-chain model
  means for this A2VMG
- `docs/normal-usage-bridge-paths.md` — comparison of the two next
  app-facing routes: `libcamera` and `v4l2loopback`
- `docs/20260309-status-report.md` — complete March 9 reverse-engineering and
  experiment report
- `docs/webcam-status.md` — short current Linux webcam support assessment for
  this laptop
- `docs/kernel-tree-status.md` — exact local `linux-mainline` source path and
  original `v6.19` `INT3472` / `TPS68470` finding
- `docs/reprobe-harness.md` — safe snapshot/reprobe script and run-capture
  workflow
- `docs/tps68470-reverse-engineering.md` — canonical note for ACPI capture plus
  Windows `iactrllogic64.sys` analysis
- `docs/linux-board-data-candidate.md` — original MSI
  `tps68470_board_data` hypothesis and first patched-test plan
- `docs/pmic-followup-experiments.md` — ordered PMIC experiment matrix and the
  scripted update/reboot/verify workflow for experiments 1-19; `exp13` through
  `exp18` are now completed evidence, `exp18` is the first clean standard-`VSIO`
  branch that binds `ov5675` into the media graph, and `exp19` stages the
  first capture/userspace validation on top of that branch
- `docs/wf-vs-uf-gpio-analysis.md` — Windows helper-family analysis for
  deciding whether this laptop still matches the `WF` / `LNK0` GPIO model
- `docs/patch-kernel-workflow.md` — idempotent patch-stack workflow for the
  local `linux-mainline` tree
- `docs/module-iteration.md` — faster module-only rebuild/install workflow for
  camera-path changes
- `docs/test-routines.md` — numbered test wrappers for clean-boot, reload,
  userspace-capture, no-reboot format-sweep, pipeline-setup, higher-level
  client compatibility, explicit userspace-bridge, and next-step integration
  checkpoints
- `docs/ov5675-diagnostic-patch.md` — first `ov5675` probe-logging patch and
  exact module-only test steps
- `docs/ipu-bridge-ovti5675-candidate.md` — `ipu-bridge` follow-up patch note
- `docs/ov5675-power-on-order.md` — `ov5675` power-on sequencing note after the
  clean-boot `dvdd` timeout
- `docs/ov5675-powerdown-followup.md` — `ov5675` GPIO follow-up after the
  serial-power result
- `docs/ov5675-identify-debug-followup.md` — identify/debug branch that exposed
  the clean-boot `-110` chip-ID timeout
- `docs/ov5675-gpio-release-sequencing-followup.md` — staged `ov5675`
  GPIO-release sequencing branch after the polarity variants failed
- `docs/int3472-gpio1-powerdown-active-high-followup.md` — latest negative
  `INT3472` physical-line polarity follow-up
- `docs/int3472-gpio-polarity-followup.md` — earlier negative first `INT3472`
  polarity follow-up
- `docs/int3472-gpio-swap-followup.md` — earlier negative `INT3472` board-data
  role-swap test on `GPIO1` / `GPIO2`

## Repo-Level Control Docs

- `../state/CONTEXT.md` — one-screen restart capsule with current objective and
  next actions
- `../PLAN.md` — active investigation plan and task queue
- `../WORKLOG.md` — reverse-chronological record of work performed
- `../AGENTS.md` — repo workflow guide
- `../README.md` — repo entrypoint and layout

## References

- `../reference/README.md` — index of captured upstream sources
- `../reference/antti-patch/README.md` — local archive note for the March 10,
  2026 Antti Laakso Prestige 14 Lore thread

## Expected Growth

As the investigation expands, add new synthesized notes here rather than
burying them in ad-hoc root files. The next likely additions are:

- deeper PMIC instrumentation notes
- Windows config-path extraction notes for `WF::SetConf`
- a dedicated note on why `pmic-reg-dump.sh` still fails post-boot

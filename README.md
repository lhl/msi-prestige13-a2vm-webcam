# MSI Prestige 13 AI+ Evo A2VMG Webcam Bring-Up

Research and bring-up notes for getting the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG / A2VM family.

## Current Status

- Current verdict: the webcam is still not working end to end.
- Latest technical assessment: `docs/webcam-status.md`
- Current leading blocker: on a clean combined-patch boot, `ov5675` now gets
  past the earlier `dvdd` timeout and reaches sensor identification, but every
  clean-boot chip-ID read still times out with `-110`

Machine under test:

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Latest recorded kernel: `7.0.0-rc2-1-mainline-dirty` on 2026-03-08

## Start Here

- [`state/CONTEXT.md`](./state/CONTEXT.md) — short restart capsule with current objective and next actions
- [`PLAN.md`](./PLAN.md) — active investigation plan and task queue
- [`WORKLOG.md`](./WORKLOG.md) — reverse-chronological record of work performed
- [`docs/README.md`](./docs/README.md) — documentation index
- [`docs/kernel-tree-status.md`](./docs/kernel-tree-status.md) — local `linux-mainline` source location and current board-data finding
- [`docs/reprobe-harness.md`](./docs/reprobe-harness.md) — safe snapshot/reprobe harness and run capture workflow
- [`docs/tps68470-reverse-engineering.md`](./docs/tps68470-reverse-engineering.md) — canonical ACPI plus Windows-control-logic reverse-engineering note
- [`docs/linux-board-data-candidate.md`](./docs/linux-board-data-candidate.md) — current Linux patch candidate and first live-test criteria
- [`docs/ov5675-gpio-release-sequencing-followup.md`](./docs/ov5675-gpio-release-sequencing-followup.md) — current `ov5675` module-only GPIO-sequencing debug branch after both one-line polarity variants failed
- [`docs/int3472-gpio1-powerdown-active-high-followup.md`](./docs/int3472-gpio1-powerdown-active-high-followup.md) — latest negative `INT3472` physical-line polarity test after the first negative polarity result
- [`docs/int3472-gpio-polarity-followup.md`](./docs/int3472-gpio-polarity-followup.md) — earlier negative first `INT3472` polarity test on the existing `GPIO1` / `GPIO2` pair
- [`docs/int3472-gpio-swap-followup.md`](./docs/int3472-gpio-swap-followup.md) — earlier negative `INT3472` board-data role-swap test on the existing `GPIO1` / `GPIO2` pair
- [`docs/module-iteration.md`](./docs/module-iteration.md) — faster module-only rebuild/install workflow for camera-path kernel changes
- [`docs/ov5675-diagnostic-patch.md`](./docs/ov5675-diagnostic-patch.md) — first `ov5675` diagnostic patch and exact module-only test flow
- [`docs/ipu-bridge-ovti5675-candidate.md`](./docs/ipu-bridge-ovti5675-candidate.md) — current `ipu-bridge` follow-up patch candidate after the diagnostic result
- [`docs/ov5675-power-on-order.md`](./docs/ov5675-power-on-order.md) — next `ov5675` power-on sequencing hypothesis after the clean-boot `dvdd` timeout
- [`docs/ov5675-powerdown-followup.md`](./docs/ov5675-powerdown-followup.md) — next `ov5675` GPIO follow-up after the clean-boot serial-power result
- [`docs/ov5675-identify-debug-followup.md`](./docs/ov5675-identify-debug-followup.md) — next `ov5675` debug/retry branch after the negative `powerdown-v1` result
- [`docs/wf-vs-uf-gpio-analysis.md`](./docs/wf-vs-uf-gpio-analysis.md) — why the local evidence still favors the `WF` / `LNK0` GPIO model over a premature `gpio.4` pivot
- [`docs/pmic-followup-experiments.md`](./docs/pmic-followup-experiments.md) — ordered `WF` / PMIC experiment matrix plus update/reboot/verify wrappers for experiments 1-6
- [`docs/patch-kernel-workflow.md`](./docs/patch-kernel-workflow.md) — idempotent patch-stack workflow for the local `linux-mainline` tree
- [`docs/test-routines.md`](./docs/test-routines.md) — numbered test wrappers for clean-boot and reload checkpoints
- [`reference/README.md`](./reference/README.md) — captured upstream references

## Resume Codex

From this repo root, the quickest way back into the latest investigation
session is:

```bash
cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam
codex resume --last
```

Useful variants:

- `codex resume` — open the session picker filtered to the current working tree
- `codex resume --all` — show all recorded sessions, not just this repo/CWD
- `codex resume <SESSION_ID>` — resume a specific session UUID directly

## Repo Layout

```text
msi-prestige13-a2vm-webcam/
├── README.md
├── AGENTS.md
├── PLAN.md
├── WORKLOG.md
├── scripts/
│   ├── capture-acpi.sh
│   ├── extract-iactrllogic64.sh
│   ├── 01-clean-boot-check.sh
│   ├── 02-ov5675-reload-check.sh
│   ├── 03-ov5675-identify-debug-check.sh
│   ├── exp*-*-update.sh
│   ├── exp*-*-verify.sh
│   ├── patch-kernel.sh
│   ├── lib-experiment-workflow.sh
│   └── webcam-run.sh
├── runs/
│   └── README.md
├── state/
│   └── CONTEXT.md
├── docs/
│   ├── README.md
│   ├── module-iteration.md
│   ├── pmic-followup-experiments.md
│   ├── ipu-bridge-ovti5675-candidate.md
│   ├── ov5675-diagnostic-patch.md
│   ├── reprobe-harness.md
│   ├── tps68470-reverse-engineering.md
│   └── webcam-status.md
└── reference/
    ├── README.md
    ├── acpi/
    ├── intel-ipu7-drivers-issue-17.md
    └── jeremy-grosser-prestige13-notes.md
```

## Working Conventions

- `README.md` stays accurate and points to the current doc structure.
- `PLAN.md` is the forward-looking source of truth for open questions and next steps.
- `WORKLOG.md` records every meaningful work session, including commands, evidence, and outcomes.
- `scripts/webcam-run.sh` is the safe harness for repeatable snapshot and reprobe runs.
- `scripts/capture-acpi.sh` is the root-only ACPI capture helper for this exact machine.
- `scripts/extract-iactrllogic64.sh` regenerates the checked-in Windows control-logic analysis artifacts.
- `runs/` stores timestamped run outputs from the harness.
- `state/CONTEXT.md` is the one-screen restart capsule for the next session.
- `reference/` holds captured external sources with stable filenames, source URLs, and capture dates.
- `docs/` holds our synthesized conclusions and state-of-project documents.

## Current Focus

1. Use `scripts/patch-kernel.sh` to keep the local patch stack repeatable and
   idempotent.
2. Treat the first `powerdown-v1` clean boot as a negative result:
   `failed to find sensor: -5` did not change.
3. Use the `ov5675` identify-debug branch as the clean-boot baseline:
   chip-ID reads now fail with `-110`, not the old collapsed `-5`.
4. Use the ordered PMIC follow-up workflow in
   [`docs/pmic-followup-experiments.md`](./docs/pmic-followup-experiments.md)
   and the matching `scripts/exp*-*-update.sh` / `scripts/exp*-*-verify.sh`
   wrappers for experiments 1-6.

## Related Docs

- [`docs/webcam-status.md`](./docs/webcam-status.md) — current Linux support assessment for this laptop
- [`docs/kernel-tree-status.md`](./docs/kernel-tree-status.md) — exact local kernel-source path and 6.19 board-data status
- [`docs/reprobe-harness.md`](./docs/reprobe-harness.md) — safe module reprobe/capture workflow for repeatable experiments
- [`docs/tps68470-reverse-engineering.md`](./docs/tps68470-reverse-engineering.md) — canonical reverse-engineering note for ACPI plus Windows `iactrllogic64.sys`
- [`docs/linux-board-data-candidate.md`](./docs/linux-board-data-candidate.md) — current MSI `tps68470_board_data` hypothesis and first patched-test plan
- [`docs/ov5675-gpio-release-sequencing-followup.md`](./docs/ov5675-gpio-release-sequencing-followup.md) — current `ov5675` module-only GPIO-sequencing debug branch after both one-line polarity variants failed
- [`docs/int3472-gpio1-powerdown-active-high-followup.md`](./docs/int3472-gpio1-powerdown-active-high-followup.md) — latest negative `INT3472` physical-line polarity test after the first negative polarity result
- [`docs/int3472-gpio-polarity-followup.md`](./docs/int3472-gpio-polarity-followup.md) — earlier negative first `INT3472` polarity test on the existing `GPIO1` / `GPIO2` pair
- [`docs/int3472-gpio-swap-followup.md`](./docs/int3472-gpio-swap-followup.md) — earlier negative `INT3472` board-data role-swap test on the existing `GPIO1` / `GPIO2` pair
- [`docs/module-iteration.md`](./docs/module-iteration.md) — module-only rebuild/install workflow for camera-path iteration
- [`docs/ov5675-diagnostic-patch.md`](./docs/ov5675-diagnostic-patch.md) — first `ov5675` diagnostic patch and exact module-only test flow
- [`docs/ipu-bridge-ovti5675-candidate.md`](./docs/ipu-bridge-ovti5675-candidate.md) — current `ipu-bridge` follow-up patch candidate after the diagnostic result
- [`docs/ov5675-power-on-order.md`](./docs/ov5675-power-on-order.md) — next `ov5675` power-on sequencing hypothesis after the clean-boot `dvdd` timeout
- [`docs/ov5675-powerdown-followup.md`](./docs/ov5675-powerdown-followup.md) — next `ov5675` GPIO follow-up after the clean-boot serial-power result
- [`docs/ov5675-identify-debug-followup.md`](./docs/ov5675-identify-debug-followup.md) — next `ov5675` debug/retry branch after the negative `powerdown-v1` result
- [`docs/wf-vs-uf-gpio-analysis.md`](./docs/wf-vs-uf-gpio-analysis.md) — Windows helper-family analysis for `WF` / `UF` and PMIC GPIO implications
- [`docs/patch-kernel-workflow.md`](./docs/patch-kernel-workflow.md) — idempotent patch-stack workflow for the local `linux-mainline` tree
- [`docs/test-routines.md`](./docs/test-routines.md) — numbered test wrappers for clean-boot and reload checkpoints
- [`reference/greymouser-summit-13-ai-evo-a2vm.md`](./reference/greymouser-summit-13-ai-evo-a2vm.md) — related MSI Summit 13 AI+ Evo A2VMTG Linux support repo note
- [`reference/intel-ipu7-drivers-issue-17.md`](./reference/intel-ipu7-drivers-issue-17.md) — Intel upstream issue note
- [`reference/intel-control-logic-microsoft-update-catalog-71.26100.23.20279.md`](./reference/intel-control-logic-microsoft-update-catalog-71.26100.23.20279.md) — exact `ACPI\INT3472` Windows control-logic package entry and CAB URL
- [`reference/patches/ipu-bridge-ovti5675-v1.patch`](./reference/patches/ipu-bridge-ovti5675-v1.patch) — first `ipu-bridge` follow-up patch candidate for adding `OVTI5675`
- [`reference/patches/ov5675-identify-debug-v1.patch`](./reference/patches/ov5675-identify-debug-v1.patch) — module-only debug patch for exact chip-ID read errors, retries, and extra delay
- [`reference/patches/ov5675-probe-diagnostics-v1.patch`](./reference/patches/ov5675-probe-diagnostics-v1.patch) — first `ov5675` probe-logging patch candidate
- [`reference/jeremy-grosser-prestige13-notes.md`](./reference/jeremy-grosser-prestige13-notes.md) — MSI-specific Debian/gist note
- [`reference/linux-mainline-v6.19/README.md`](./reference/linux-mainline-v6.19/README.md) — local snapshot of the inspected `v6.19` `int3472` kernel subtree
- [`reference/linux-torvalds-head/README.md`](./reference/linux-torvalds-head/README.md) — current Torvalds `HEAD` snapshot of the `int3472` subtree
- [`reference/msi-ov5675-microsoft-update-catalog-70.26100.19939.1.md`](./reference/msi-ov5675-microsoft-update-catalog-70.26100.19939.1.md) — exact MSI `OV5675` Windows package entry and CAB URL
- [`reference/tps68470.pdf`](./reference/tps68470.pdf) — local TPS68470 datasheet copy
- [`reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/README.md`](./reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/README.md) — repeatable static-analysis artifacts for the MSI Windows control-logic driver
- [`reference/patches/ms13q3-int3472-tps68470-v1.patch`](./reference/patches/ms13q3-int3472-tps68470-v1.patch) — current first-pass Linux board-data patch candidate
- [`reference/patches/ov5675-gpio-release-sequencing-debug-v1.patch`](./reference/patches/ov5675-gpio-release-sequencing-debug-v1.patch) — current `ov5675` debug patch for staged `reset` / `powerdown` release order and delay
- [`reference/patches/ms13q3-int3472-gpio1-powerdown-active-high-v1.patch`](./reference/patches/ms13q3-int3472-gpio1-powerdown-active-high-v1.patch) — latest negative board-data physical-line polarity follow-up that moved the active-high `powerdown` behavior onto `GPIO1`
- [`reference/patches/ms13q3-int3472-powerdown-active-high-v1.patch`](./reference/patches/ms13q3-int3472-powerdown-active-high-v1.patch) — earlier negative first board-data polarity follow-up that flipped `GPIO2` `powerdown` to `GPIO_ACTIVE_HIGH`
- [`reference/patches/ms13q3-int3472-gpio-swap-v1.patch`](./reference/patches/ms13q3-int3472-gpio-swap-v1.patch) — earlier negative board-data follow-up that swapped `GPIO1` / `GPIO2` roles for `OVTI5675`
- [`reference/windows-driver-packages/README.md`](./reference/windows-driver-packages/README.md) — vendored Windows package archive and extracted-tree index
- [`runs/README.md`](./runs/README.md) — run archive layout for timestamped probe batches

# MSI Prestige 13 AI+ Evo A2VMG Webcam Bring-Up

Research and bring-up notes for getting the built-in webcam working on Linux on
the MSI Prestige 13 AI+ Evo A2VMG / A2VM family.

## Current Status

- Current verdict: the webcam is still not working end to end.
- Best current summary: `docs/webcam-status.md`
- Full March 9 status report: `docs/20260309-status-report.md`
- Current leading blocker: Linux now reaches `ov5675` sensor identification on
  a clean boot, but every chip-ID read still times out with `-110` even after
  the first six PMIC follow-up experiments.
- Current leading interpretation: the remaining gap is no longer basic IPU7
  support, sensor discovery, or the first MSI board-data patch. It is now a
  narrower PMIC-side wake-up / pass-through / sequencing problem.

Machine under test:

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Latest recorded kernel: `7.0.0-rc2-1-mainline-dirty` on `2026-03-09`

## Start Here

- [`docs/20260309-status-report.md`](./docs/20260309-status-report.md) —
  complete March 9 reverse-engineering and experiment report
- [`docs/webcam-status.md`](./docs/webcam-status.md) — shorter live technical
  status
- [`state/CONTEXT.md`](./state/CONTEXT.md) — restart capsule with current
  objective and next actions
- [`PLAN.md`](./PLAN.md) — active investigation plan and task queue
- [`WORKLOG.md`](./WORKLOG.md) — reverse-chronological record of work
  performed
- [`docs/README.md`](./docs/README.md) — documentation index
- [`docs/kernel-tree-status.md`](./docs/kernel-tree-status.md) — local
  `linux-mainline` source location and original board-data finding
- [`docs/tps68470-reverse-engineering.md`](./docs/tps68470-reverse-engineering.md)
  — canonical ACPI plus Windows-control-logic reverse-engineering note
- [`docs/wf-vs-uf-gpio-analysis.md`](./docs/wf-vs-uf-gpio-analysis.md) — why
  the local evidence still favors the `WF` / `LNK0` model over a premature
  `UF` / `gpio.4` pivot
- [`docs/pmic-followup-experiments.md`](./docs/pmic-followup-experiments.md) —
  ordered PMIC experiment matrix and the update/reboot/verify workflow
- [`docs/module-iteration.md`](./docs/module-iteration.md) — faster module-only
  rebuild/install workflow for camera-path kernel changes
- [`docs/patch-kernel-workflow.md`](./docs/patch-kernel-workflow.md) —
  idempotent patch-stack workflow for the local `linux-mainline` tree
- [`docs/test-routines.md`](./docs/test-routines.md) — numbered test wrappers
  for clean-boot and reload checkpoints
- [`reference/README.md`](./reference/README.md) — captured upstream
  references

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
├── .gitignore
├── scripts/
│   ├── capture-acpi.sh
│   ├── extract-iactrllogic64.sh
│   ├── patch-kernel.sh
│   ├── pmic-reg-dump.sh
│   ├── lib-experiment-workflow.sh
│   ├── 01-clean-boot-check.sh
│   ├── 02-ov5675-reload-check.sh
│   ├── 03-ov5675-identify-debug-check.sh
│   ├── exp*-*-update.sh
│   ├── exp*-*-verify.sh
│   └── webcam-run.sh
├── runs/
│   └── README.md
├── state/
│   └── CONTEXT.md
├── docs/
│   ├── README.md
│   ├── 20260309-status-report.md
│   ├── webcam-status.md
│   ├── pmic-followup-experiments.md
│   ├── tps68470-reverse-engineering.md
│   └── ...
└── reference/
    ├── README.md
    ├── acpi/
    ├── patches/
    ├── windows-driver-analysis/
    └── windows-driver-packages/
```

## Working Conventions

- `README.md` stays accurate and points to the current doc structure.
- `PLAN.md` is the forward-looking source of truth for open questions and next
  steps.
- `WORKLOG.md` records every meaningful work session, including commands,
  evidence, and outcomes.
- `scripts/webcam-run.sh` is the safe harness for repeatable snapshot and
  reprobe runs.
- `scripts/capture-acpi.sh` is the root-only ACPI capture helper for this exact
  machine.
- `scripts/extract-iactrllogic64.sh` regenerates the checked-in Windows
  control-logic analysis artifacts.
- `scripts/patch-kernel.sh` applies the baseline patch profile repeatably.
- `scripts/exp*-*-update.sh` and `scripts/exp*-*-verify.sh` are the current
  PMIC experiment entrypoints.
- `runs/` stores timestamped run outputs from the harness and experiment
  wrappers.
- `state/CONTEXT.md` is the one-screen restart capsule for the next session.
- `reference/` holds captured external sources with stable filenames, source
  URLs, and capture dates.
- `docs/` holds synthesized conclusions and current state-of-project documents.

## Current Focus

1. Treat the completed March 9 PMIC batch as the new baseline evidence, not as
   future work.
2. Keep the current tested stack fixed:
   - MSI `INT3472` / `TPS68470` board-data
   - `ipu-bridge` `OVTI5675`
   - `ov5675` serial power-on order
3. Use the completed negative branches to stop spending time on blind GPIO
   permutations:
   - label-only `GPIO1` / `GPIO2` swap
   - both one-line polarity variants
   - three staged `ov5675` GPIO-release variants
   - `exp5` `WF` GPIO mode follow-up
   - `exp6` `UF` / `gpio.4` last resort
4. Put the next effort into the PMIC behavior Linux still does not explain:
   - why `S_I2C_CTL` `0x43` is the first PMIC transaction after which readback
     collapses to `-110`
   - whether the bad transition happens on the IO-side `BIT(1)` step, the
     later GPIO-side `BIT(0)` step, or both
   - why post-boot PMIC register dumps still fail completely
   - the higher-level Windows config that feeds `WF::SetConf`
5. The next concrete kernel-side run is:
   - `scripts/exp9-s-i2c-ctl-split-step-trace-update.sh`
   - reboot
   - `scripts/exp9-s-i2c-ctl-split-step-trace-verify.sh`

## Related Docs

- [`docs/20260309-status-report.md`](./docs/20260309-status-report.md) —
  complete March 9 status report with experiment results and next steps
- [`docs/webcam-status.md`](./docs/webcam-status.md) — short current Linux
  support assessment for this laptop
- [`docs/kernel-tree-status.md`](./docs/kernel-tree-status.md) — exact local
  kernel-source path and original `INT3472` / `TPS68470` status
- [`docs/reprobe-harness.md`](./docs/reprobe-harness.md) — safe module
  reprobe/capture workflow for repeatable experiments
- [`docs/tps68470-reverse-engineering.md`](./docs/tps68470-reverse-engineering.md)
  — canonical reverse-engineering note for ACPI plus Windows
  `iactrllogic64.sys`
- [`docs/wf-vs-uf-gpio-analysis.md`](./docs/wf-vs-uf-gpio-analysis.md) —
  Windows helper-family analysis for `WF` / `UF` and PMIC GPIO implications
- [`docs/pmic-followup-experiments.md`](./docs/pmic-followup-experiments.md) —
  PMIC experiment workflow and patch entrypoints
- [`reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/README.md`](./reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/README.md)
  — repeatable static-analysis artifact index for the MSI Windows control-logic
  driver
- [`reference/patches/ms13q3-int3472-tps68470-v1.patch`](./reference/patches/ms13q3-int3472-tps68470-v1.patch)
  — current first-pass Linux board-data patch
- [`reference/patches/ipu-bridge-ovti5675-v1.patch`](./reference/patches/ipu-bridge-ovti5675-v1.patch)
  — current `ipu-bridge` follow-up patch
- [`reference/patches/ov5675-serial-power-on-v1.patch`](./reference/patches/ov5675-serial-power-on-v1.patch)
  — current `ov5675` serial supply-enable patch
- [`reference/patches/pmic-path-instrumentation-v1.patch`](./reference/patches/pmic-path-instrumentation-v1.patch)
  — PMIC instrumentation experiment patch
- [`reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch`](./reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch)
  — staged `S_I2C_CTL` experiment patch
- [`reference/patches/pmic-si2c-ctl-focused-trace-v1.patch`](./reference/patches/pmic-si2c-ctl-focused-trace-v1.patch)
  — narrower `S_I2C_CTL` confirmation patch used in `exp8`
- [`reference/patches/pmic-si2c-ctl-split-step-trace-v1.patch`](./reference/patches/pmic-si2c-ctl-split-step-trace-v1.patch)
  — split-step `S_I2C_CTL` experiment patch for `exp9`
- [`reference/patches/ms13q3-vd-1050mv-v1.patch`](./reference/patches/ms13q3-vd-1050mv-v1.patch)
  — `VD = 1050 mV` experiment patch
- [`reference/patches/ms13q3-wf-init-value-programming-v1.patch`](./reference/patches/ms13q3-wf-init-value-programming-v1.patch)
  — `WF::Initialize` value-programming experiment patch
- [`reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch`](./reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch)
  — PMIC GPIO mode follow-up patch
- [`reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch`](./reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch)
  — `UF` / `gpio.4` last-resort patch

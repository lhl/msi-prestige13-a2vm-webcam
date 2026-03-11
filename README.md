# MSI Prestige 13 AI+ Evo A2VMG Webcam Bring-Up

Research and bring-up notes for getting the built-in webcam working on Linux on
the MSI Prestige 13 AI+ Evo A2VMG / A2VM family.

## Current Status

- Current verdict: the webcam is still not working end to end.
- Best current summary: `docs/webcam-status.md`
- Full March 9 status report: `docs/20260309-status-report.md`
- Current leading blocker: `exp18` now binds `ov5675 10-0036` into the media
  graph with stock regulator-side `VSIO = 0x03`, so the remaining gap is no
  longer first sensor wake-up; `exp19` shows the first raw userspace stream on
  `/dev/video0` now fails later at `VIDIOC_STREAMON` with `Link has been
  severed`, and a later no-reboot `4096x3072 BA10` sweep across `/dev/video0`
  through `/dev/video7` still fails the same way, plus broken post-boot PMIC
  visibility.
- Current leading interpretation: the clean daisy-chain branch plus standard
  `VSIO` is the first positive local baseline, and any remaining Antti-thread
  drift is now more likely to matter for cleanup/upstreamability than for basic
  sensor bring-up.

Machine under test:

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Latest recorded kernel: `7.0.0-rc2-1-mainline-dirty` on `2026-03-09`

## Start Here

- [`docs/20260309-status-report.md`](./docs/20260309-status-report.md) —
  complete March 9 reverse-engineering and experiment report
- [`docs/webcam-status.md`](./docs/webcam-status.md) — shorter live technical
  status
- [`docs/antti-prestige14-thread-review.md`](./docs/antti-prestige14-thread-review.md)
  — review of the March 10, 2026 Antti Laakso Prestige 14 patch thread and
  what its daisy-chain model means for this A2VMG
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
  for clean-boot, reload, and userspace-capture checkpoints
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
│   ├── 04-userspace-capture-check.sh
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
4. Treat `exp13` through `exp18` as completed evidence.
   - `exp13` proved Linux can leave `GPIO1` / `GPIO2` in daisy-chain input
     mode
   - `exp14` proved `GPIO9` is active, but insufficient as a lone reset line
   - `exp15` proved `GPIO7` is also active, but insufficient as a lone reset
     line
   - `exp16` proved the current-driver `GPIO7` / `GPIO9` approximation can
     drive both remote lines together, but is still insufficient
   - `exp17` proved a later `S_I2C_CTL BIT(0)` on the clean remote-line branch
     is safe and reads back as `0x03`, but still does not move the sensor off
     repeated `-121`
   - `exp18` proved stock regulator-side `VSIO` enable is safe on the clean
     daisy-chain branch and yields the first `ov5675 10-0036` sensor entity in
     the media graph
5. Keep `exp10` only as the older PMIC control baseline.
   - `exp11` showed that one modeled late `BIT(0)` hook still re-wedges PMIC
     access
   - `exp12` showed that the low-effort Antti-inspired daisy-chain setup is
     immediately overridden by the current Linux `GPIO1` / `GPIO2` lookup
   - `exp13` through `exp18` then showed the clean daisy-chain branch is real,
     both remote lines are active, standard `VSIO` is safe there, and sensor
     bind is now possible
6. Use `exp18` as the current best local branch for follow-up validation.
   - standard `VSIO` now reads back cleanly as `0x03`
   - the old timeout storm does not return
   - the media graph now contains `ov5675 10-0036`
7. Use `exp19` plus the later no-reboot format sweep as the current capture
   truth source.
   - reuse the positive `exp18` patch unchanged
   - the first `/dev/video0` stream attempt now reaches `VIDIOC_STREAMON`
     and fails there with `Link has been severed`
   - forcing `/dev/video0` through `/dev/video7` to `4096x3072 BA10` is
     accepted at `VIDIOC_S_FMT`, but all eight nodes still fail
     `VIDIOC_STREAMON` with `Link has been severed`
8. Treat post-boot PMIC visibility as secondary to the new userspace
   `STREAMON` failure until the capture-path result is understood.

## Related Docs

- [`docs/20260309-status-report.md`](./docs/20260309-status-report.md) —
  complete March 9 status report with experiment results and next steps
- [`docs/webcam-status.md`](./docs/webcam-status.md) — short current Linux
  support assessment for this laptop
- [`docs/antti-prestige14-thread-review.md`](./docs/antti-prestige14-thread-review.md)
  — preserved review of Antti Laakso's March 10, 2026 Prestige 14 patch
  thread and its relevance to `MS-13Q3`
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
- [`reference/antti-patch/README.md`](./reference/antti-patch/README.md) —
  local archive note for Antti Laakso's March 10, 2026 Prestige 14 Lore thread
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
- [`reference/patches/pmic-si2c-ctl-bit1-only-v1.patch`](./reference/patches/pmic-si2c-ctl-bit1-only-v1.patch)
  — `BIT(1)`-only `S_I2C_CTL` experiment patch for `exp10`
- [`reference/patches/pmic-si2c-ctl-late-gpio-bit0-v1.patch`](./reference/patches/pmic-si2c-ctl-late-gpio-bit0-v1.patch)
  — later GPIO-phase `BIT(0)` experiment patch for `exp11`
- [`reference/patches/ms13q3-daisy-chain-crosscheck-v1.patch`](./reference/patches/ms13q3-daisy-chain-crosscheck-v1.patch)
  — Antti-inspired daisy-chain cross-check patch for `exp12`
- [`reference/patches/ms13q3-daisy-chain-isolation-v1.patch`](./reference/patches/ms13q3-daisy-chain-isolation-v1.patch)
  — daisy-chain isolation patch for `exp13`
- [`reference/patches/ms13q3-daisy-chain-gpio9-reset-v1.patch`](./reference/patches/ms13q3-daisy-chain-gpio9-reset-v1.patch)
  — `GPIO9` remote reset candidate patch for `exp14`
- [`reference/patches/ms13q3-daisy-chain-gpio7-reset-v1.patch`](./reference/patches/ms13q3-daisy-chain-gpio7-reset-v1.patch)
  — `GPIO7` remote reset candidate patch for `exp15`
- [`reference/patches/ms13q3-daisy-chain-gpio7-gpio9-approx-v1.patch`](./reference/patches/ms13q3-daisy-chain-gpio7-gpio9-approx-v1.patch)
  — current two-line `GPIO7` / `GPIO9` approximation patch for `exp16`
- [`reference/patches/ms13q3-daisy-chain-bit0-retest-v1.patch`](./reference/patches/ms13q3-daisy-chain-bit0-retest-v1.patch)
  — clean-daisy-chain `BIT(0)` re-test patch for `exp17`
- [`reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch`](./reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch)
  — clean-daisy-chain standard-`VSIO` comparison patch for `exp18`
- [`reference/patches/ms13q3-vd-1050mv-v1.patch`](./reference/patches/ms13q3-vd-1050mv-v1.patch)
  — `VD = 1050 mV` experiment patch
- [`reference/patches/ms13q3-wf-init-value-programming-v1.patch`](./reference/patches/ms13q3-wf-init-value-programming-v1.patch)
  — `WF::Initialize` value-programming experiment patch
- [`reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch`](./reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch)
  — PMIC GPIO mode follow-up patch
- [`reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch`](./reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch)
  — `UF` / `gpio.4` last-resort patch

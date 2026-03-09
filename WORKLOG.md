# Worklog

## 2026-03-09

### Analyze `exp7`, commit its run artifacts, and prepare a narrower `exp8`

- Plan: record the new `exp7` run evidence and update the project assessment,
  then replace the broad raw-regmap follow-up with a tighter `S_I2C_CTL`
  experiment that keeps the key signal without amplifying boot delays.
- Commands:
  - reviewed the `exp7` update and verify artifacts:
    - `sed -n '1,220p' runs/2026-03-09/20260309T155228-pmic-raw-regmap-trace-update/action.log`
    - `sed -n '1,220p' runs/2026-03-09/20260309T155609-snapshot-exp7-clean-boot/focused-summary.txt`
    - `sed -n '1,260p' runs/2026-03-09/20260309T155609-snapshot-exp7-clean-boot/experiment-journal.txt`
    - `sed -n '1,200p' runs/2026-03-09/20260309T155609-snapshot-exp7-clean-boot/pmic-reg-dump.txt`
  - reviewed the full previous-boot journal around the long timeout path:
    - `journalctl -b -1 --no-pager | rg -n "i2c|ov5675|boot.mount|Emergency Mode|timed out"`
    - `journalctl -b -1 -u boot.mount --no-pager -o short-full`
  - generated a clean-source `exp8` patch from `git show HEAD:` copies under:
    - `.tmp/exp8-gen/`
  - validated `exp8` in a repo-local clean clone under:
    - `.tmp/exp8-buildcheck/`
  - `apply_patch` / shell updates:
    - `reference/patches/pmic-si2c-ctl-focused-trace-v1.patch`
    - `scripts/exp8-s-i2c-ctl-focused-trace-update.sh`
    - `scripts/exp8-s-i2c-ctl-focused-trace-verify.sh`
    - `scripts/lib-experiment-workflow.sh`
    - `README.md`
    - `docs/20260309-status-report.md`
    - `docs/pmic-followup-experiments.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - `exp7` is now recorded as the first run that isolated the bad PMIC
    transaction to `VSIO` enable on `S_I2C_CTL` `0x43`
  - the long boot-side effect now looks like instrumentation-amplified I2C
    timeout fallout, not a primary `/boot` or systemd root cause
  - the repo now has `exp8`, a narrower follow-up designed to confirm the
    `0x43` failure point without dragging the bus through dozens of extra
    timeout reads

### Add the next PMIC kernel-instrumentation experiment for raw regmap trace

- Plan: add a new PMIC experiment focused on raw register truth inside the
  Linux clock and regulator drivers, because the current userspace PMIC dump
  path is not yielding useful data.
- Commands:
  - reviewed the current PMIC experiment patches, wrappers, and kernel sources:
    - `sed -n '1,260p' reference/patches/pmic-path-instrumentation-v1.patch`
    - `sed -n '1,260p' reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch`
    - `sed -n '1,260p' scripts/lib-experiment-workflow.sh`
    - `sed -n '1,260p' scripts/exp1-pmic-instrumentation-update.sh`
    - `sed -n '1,260p' scripts/exp1-pmic-instrumentation-verify.sh`
    - `sed -n '1,260p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/clk/clk-tps68470.c`
    - `sed -n '1,260p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
  - reviewed the generic regulator helpers to preserve behavior while adding
    tracing:
    - `sed -n '1,140p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/helpers.c`
    - `sed -n '260,330p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/helpers.c`
  - generated a new patch from temporary source copies under:
    - `.tmp/exp7-gen/`
  - validated the result:
    - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline apply --check reference/patches/pmic-raw-regmap-trace-v1.patch`
    - repo-local shared-clone build check for:
      - `drivers/clk`
      - `drivers/regulator`
  - `apply_patch` updating:
    - `reference/patches/pmic-raw-regmap-trace-v1.patch`
    - `scripts/lib-experiment-workflow.sh`
    - `scripts/exp7-pmic-raw-regmap-trace-update.sh`
    - `scripts/exp7-pmic-raw-regmap-trace-verify.sh`
    - `docs/pmic-followup-experiments.md`
    - `README.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `docs/webcam-status.md`
    - `WORKLOG.md`
- Result:
  - the repo now has a concrete `exp7` PMIC trace experiment aimed at raw
    register truth during the failing clean-boot probe window
  - the new patch instruments:
    - `clk-tps68470`
    - `tps68470-regulator`
  - it logs:
    - register
    - mask / value
    - regmap return code
    - immediate readback
  - `exp7` is now the highest-priority next kernel-side experiment

### Clarify that the March 9 PMIC batch ran on the `candidate` baseline

- Plan: fix a provenance ambiguity in the new March 9 report so it does not
  read like `exp1` through `exp6` ran on the pure `tested` stack.
- Commands:
  - reviewed the relevant report section and experiment metadata:
    - `sed -n '120,190p' docs/20260309-status-report.md`
    - `sed -n '1,40p' runs/2026-03-09/20260309T142113-pmic-instrumentation-update/metadata.env`
    - `sed -n '1,40p' runs/2026-03-09/20260309T150040-uf-gpio4-last-resort-update/metadata.env`
  - `apply_patch` updating:
    - `docs/20260309-status-report.md`
    - `WORKLOG.md`
- Result:
  - the report now explicitly says the March 9 PMIC batch ran on the
    `candidate` baseline profile
  - it also spells out that `candidate` means `tested` plus the extra
    `ov5675` debug patches, which matches the recorded update metadata

### Publish the March 9 status report and refresh stale top-level docs

- Plan: turn the completed PMIC experiment batch and Windows extraction state
  into one current report, then refresh the repo entrypoints so they point at
  the real current state instead of treating the PMIC batch as future work.
- Commands:
  - reviewed the stale control docs and current summaries:
    - `sed -n '1,220p' README.md`
    - `sed -n '1,220p' docs/README.md`
    - `sed -n '1,260p' docs/webcam-status.md`
    - `sed -n '1,260p' PLAN.md`
    - `sed -n '1,220p' state/CONTEXT.md`
  - reviewed the completed PMIC run batch and Windows extraction notes:
    - `sed -n '1,260p' reference/windows-driver-analysis/.../power-sequencing-notes.md`
    - `for d in runs/2026-03-09/*snapshot-exp{1,2,3,4,5,6}-clean-boot; do ...; done`
    - `sed -n '1,340p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - `apply_patch` updating:
    - `README.md`
    - `docs/README.md`
    - `docs/webcam-status.md`
    - `docs/20260309-status-report.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the repo root now points directly at the full March 9 status report
  - the short status, plan, and restart capsule now reflect the completed
    PMIC batch instead of describing it as pending work
  - the new report records:
    - current Linux state
    - Windows extraction state
    - tooling state
    - experiment interpretation
    - comparison to simpler `TPS68470` bring-up efforts such as Surface Go
    - the fundamental data still missing
    - the next batch of work

### Record the March 9 PMIC experiment run batch before analysis

- Plan: check in the latest PMIC experiment artifacts as a clean evidence
  bundle before interpreting the results.
- Scope:
  - `exp1` rerun with working instrumentation
  - repeated `exp2` update attempts across workflow fixes
  - final `exp2` clean-boot verify
  - `exp3` through `exp6` update and clean-boot verify runs
- Result:
  - the repo now carries the raw run directories for this batch under
    `runs/2026-03-09/`
  - interpretation is intentionally deferred to the next analysis step so the
    commit captures evidence, not conclusions

### Ignore the repo-local temp root created by experiment wrappers

- Plan: keep the new repo-local temp root from polluting `git status` on every
  experiment run.
- Commands:
  - checked for an existing `.gitignore`
  - `apply_patch` adding:
    - `.gitignore`
- Result:
  - the wrapper temp root `/.tmp/` is now ignored by git
  - run evidence under `runs/` remains intentionally unignored

### Move experiment temp files off /tmp and into a repo-local temp root

- Plan: stop PMIC experiment runs from failing on `/tmp` quota by defaulting
  wrapper temp files and `patch-kernel.sh` status snapshots to a repo-local
  temp directory instead.
- Trigger:
  - repeated `exp2` attempts progressed past status snapshot, then failed in
    compiler temp-file creation with:
    - `fatal error: error writing to /tmp/...: Disk quota exceeded`
- Commands:
  - reviewed temp-file call sites in:
    - `scripts/lib-experiment-workflow.sh`
    - `scripts/patch-kernel.sh`
  - `apply_patch` updating:
    - `scripts/lib-experiment-workflow.sh`
    - `scripts/patch-kernel.sh`
    - `docs/pmic-followup-experiments.md`
    - `WORKLOG.md`
- Result:
  - experiment wrappers now default `TMPDIR` to `REPO_ROOT/.tmp`
  - `.ko.zst` staging files now use that temp root instead of `/tmp`
  - `patch-kernel.sh --status` now creates its temporary status tree under the
    same temp root unless `TMPDIR` is explicitly overridden
  - this should remove the observed `/tmp`-quota blocker from both the status
    snapshot path and compiler temp-file allocation during module builds

### Make update wrappers resilient when patch-kernel status snapshot fails

- Plan: fix the `exp*-update.sh` path that appeared to stall at
  `scripts/patch-kernel.sh --status` by making status failures explicit and
  non-fatal.
- Trigger:
  - repeated `exp2` runs stopped after:
    - `note: kernel tree is already dirty; patch state will be checked file-by-file`
  - update logs showed no later output, which pointed at the status snapshot
    phase before baseline apply
- Commands:
  - reviewed the failing `exp2` action logs under:
    - `runs/2026-03-09/20260309T144640-wf-s-i2c-ctl-staging-update/`
    - `runs/2026-03-09/20260309T144644-wf-s-i2c-ctl-staging-update/`
    - `runs/2026-03-09/20260309T144705-wf-s-i2c-ctl-staging-update/`
  - reviewed `scripts/patch-kernel.sh` status-tree creation and
    `scripts/lib-experiment-workflow.sh` update flow
  - `apply_patch` updating:
    - `scripts/patch-kernel.sh`
    - `scripts/lib-experiment-workflow.sh`
    - `docs/pmic-followup-experiments.md`
    - `WORKLOG.md`
- Result:
  - `scripts/patch-kernel.sh --status` now errors with an explicit message if
    it cannot create/apply the temporary status tree (for example `/tmp`
    space/quota pressure)
  - experiment update wrappers now treat the status snapshot as best-effort:
    they log a warning and continue with baseline apply instead of aborting the
    whole update
  - docs now reflect that `--status` visibility is attempted but not a hard
    prerequisite for applying baseline + experiment patch

### Fix missing regmap header in exp2 and exp4 regulator patches

- Plan: fix the remaining PMIC experiment patches that add `regmap_*()` calls
  in `tps68470-regulator.c` without also adding the required
  `#include <linux/regmap.h>`.
- Trigger:
  - the first real `exp2` build failed with implicit declarations for
    `regmap_read()` and `regmap_update_bits()`
- Commands:
  - reviewed the failed `exp2` update output
  - reviewed the `exp2` and `exp4` default patch files:
    - `sed -n '1,220p' reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch`
    - `sed -n '1,260p' reference/patches/ms13q3-wf-init-value-programming-v1.patch`
  - searched the patch set for `regmap_*()` users and existing `regmap.h`
    includes:
    - `rg -n "regmap_(read|write|update_bits)|<linux/regmap.h>" reference/patches/*.patch`
  - `apply_patch` updating:
    - `reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch`
    - `reference/patches/ms13q3-wf-init-value-programming-v1.patch`
    - `WORKLOG.md`
- Result:
  - `exp2` now adds `#include <linux/regmap.h>` before its staged
    `S_I2C_CTL` regulator helper
  - `exp4` now adds the same include before its `WF::Initialize`-style value
    programming helper
  - this removes the same compile-time defect that already surfaced once in
    `exp1` and again in the first real `exp2` run

### Replace patch-reversal isolation with file reset plus baseline reapply

- Plan: switch the PMIC experiment wrappers from patch-reversal isolation to
  the more robust model of resetting the known experiment-touched files back to
  kernel `HEAD`, then reapplying the baseline profile and the selected
  experiment patch.
- Trigger:
  - the first `exp2` run failed while trying to reverse `exp1` because the
    legacy and fixed `exp1` patch variants overlap but are not identical
- Commands:
  - reviewed the shared workflow helper and the failed `exp2` update log
  - `apply_patch` updating:
    - `scripts/lib-experiment-workflow.sh`
    - `docs/pmic-followup-experiments.md`
    - `WORKLOG.md`
- Result:
  - the wrappers no longer depend on reverse-applying the previous experiment
    patch cleanly
  - instead they restore the tracked files touched by any known PMIC
    experiment patch back to kernel `HEAD`
  - then they reapply the baseline `candidate` patch stack and finally the
    selected experiment patch
  - this matches the intended isolation model more closely and avoids the
    specific `exp1` legacy/fixed overlap failure seen at the start of `exp2`

### Fix the exp1 instrumentation patch compile failure and preserve rerun recovery

- Plan: repair the real `exp1` PMIC instrumentation patch after the first live
  build exposed a missing `regmap` prototype, and preserve a clean rerun path
  for the already-dirty kernel tree by keeping the broken patch as a legacy
  reverse target.
- Commands:
  - reviewed the failed build log from the live `exp1` update run
  - reviewed the affected patch/source context:
    - `sed -n '1,220p' reference/patches/pmic-path-instrumentation-v1.patch`
    - `sed -n '1,220p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `sed -n '600,690p' scripts/lib-experiment-workflow.sh`
  - copied the broken patch aside as a compatibility reset target:
    - `cp reference/patches/pmic-path-instrumentation-v1.patch reference/patches/pmic-path-instrumentation-v1-pre-regmap-include.patch`
  - `apply_patch` updating:
    - `reference/patches/pmic-path-instrumentation-v1.patch`
    - `scripts/lib-experiment-workflow.sh`
    - `WORKLOG.md`
- Result:
  - the real `exp1` patch now also adds `#include <linux/regmap.h>` before the
    new `regmap_read()` instrumentation, which fixes the observed compiler
    error
  - the old broken `exp1` patch is now retained as
    `reference/patches/pmic-path-instrumentation-v1-pre-regmap-include.patch`
  - the shared experiment reset list now includes that legacy patch, so a
    rerun of `scripts/exp1-pmic-instrumentation-update.sh` can reverse the
    already-applied broken patch from the kernel tree and then apply the fixed
    one without manual cleanup

### Correct the experiment 5 / experiment 6 wrapper note

- Plan: fix the PMIC workflow doc so its rebuild/install scope matches the
  actual runnable wrappers and patches before handing over the final sequential
  command list.
- Commands:
  - reviewed the generated experiment wrappers and default patch contents:
    - `sed -n '1,260p' scripts/exp5-wf-gpio-mode-followup-update.sh`
    - `sed -n '1,260p' scripts/exp6-uf-gpio4-last-resort-update.sh`
    - `sed -n '1,260p' reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch`
    - `sed -n '1,260p' reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch`
  - `apply_patch` updating:
    - `docs/pmic-followup-experiments.md`
    - `WORKLOG.md`
- Result:
  - the workflow note now matches the actual runnable experiment scope:
    - `exp5` rebuilds only `gpio-tps68470.ko`
    - `exp6` rebuilds both `intel_skl_int3472_tps68470.ko` and
      `gpio-tps68470.ko`
  - the correction is documentation-only; the wrappers and default patch files
    were already aligned with the intended behavior

### Create runnable default PMIC experiment patches and add sequential-run isolation

- Plan: turn the PMIC experiment wrappers from scaffolding into a truly runnable
  sequence by creating all six default experiment patch files and teaching the
  update helper to reverse any earlier PMIC experiment patch before applying
  the selected one.
- Commands:
  - reviewed the current wrapper and patch-stack behavior:
    - `sed -n '1,320p' scripts/lib-experiment-workflow.sh`
    - `sed -n '1,320p' scripts/patch-kernel.sh`
    - `sed -n '1,260p' docs/pmic-followup-experiments.md`
  - reviewed the live kernel sources for the targeted experiment deltas:
    - `sed -n '700,840p' .../drivers/media/v4l2-core/v4l2-common.c`
    - `sed -n '1,280p' .../drivers/clk/clk-tps68470.c`
    - `sed -n '1,260p' .../drivers/regulator/tps68470-regulator.c`
    - `sed -n '1,340p' .../drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `sed -n '1,280p' .../drivers/gpio/gpio-tps68470.c`
  - regenerated each new default patch from a modified temporary copy of the
    live kernel source using `diff -u`
  - validated the result:
    - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline apply --check ...`
    - `bash -n scripts/lib-experiment-workflow.sh scripts/exp6-uf-gpio4-last-resort-update.sh`
- Result:
  - all six default PMIC experiment patch files now exist and apply cleanly:
    - `reference/patches/pmic-path-instrumentation-v1.patch`
    - `reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch`
    - `reference/patches/ms13q3-vd-1050mv-v1.patch`
    - `reference/patches/ms13q3-wf-init-value-programming-v1.patch`
    - `reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch`
    - `reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch`
  - the shared update helper now reverses any previously-applied PMIC
    experiment patch by default before applying the selected one
  - that means the six PMIC experiments can now be run sequentially on one
    kernel tree without the later runs silently becoming cumulative
  - `exp6` now rebuilds and installs both:
    - `intel_skl_int3472_tps68470.ko`
    - `gpio-tps68470.ko`
    because the last-resort `gpio.4` hypothesis needs both board-data and GPIO
    path changes
  - the repo now has a concrete default command path for each PMIC experiment:
    - `scripts/expN-...-update.sh`
    - reboot
    - `scripts/expN-...-verify.sh`

### Record the first wrapper smoke test and its limits

- Plan: preserve the first end-to-end wrapper run so the repo records what was
  actually validated, while being explicit that this was a workflow/idempotency
  check rather than a real PMIC instrumentation experiment.
- Commands:
  - reviewed the update and verify artifacts:
    - `sed -n '1,220p' runs/2026-03-09/20260309T134730-pmic-instrumentation-update/action.log`
    - `sed -n '1,220p' runs/2026-03-09/20260309T134803-pmic-instrumentation-update/action.log`
    - `sed -n '1,220p' runs/2026-03-09/20260309T134918-pmic-instrumentation-update/action.log`
    - `sed -n '1,220p' runs/2026-03-09/20260309T135102-snapshot-exp1-clean-boot/focused-summary.txt`
    - `sed -n '1,220p' runs/2026-03-09/20260309T135102-snapshot-exp1-clean-boot/experiment-journal.txt`
    - `sed -n '1,220p' runs/2026-03-09/20260309T135102-snapshot-exp1-clean-boot/pmic-reg-dump.txt`
- Result:
  - the wrapper sequence behaved as intended across:
    - `--dry-run`
    - `--no-reboot`
    - a repeated real update before reboot
    - post-reboot verify
  - all three update runs used the explicit override patch
    `reference/patches/ms13q3-int3472-tps68470-v1.patch`
  - that means this bundle validates wrapper argument handling, rebuild/install
    flow, reboot handoff, and verify capture, but does not validate the planned
    PMIC instrumentation patch for `exp1`
  - the clean-boot result stayed on the known failure:
    five `chip id read attempt ... failed: -110` lines followed by
    `failed to find sensor: -110`
  - the experiment-specific grep did not show new PMIC instrumentation lines,
    which is expected because the instrumentation patch was not part of this
    run
  - the PMIC dump returned `ERROR` for every queried register, so this run does
    not add a usable PMIC register-state datapoint either

### Normalize verify-run ownership after root-assisted capture

- Plan: keep the new verify wrappers usable from a normal user checkout even
  when one of the capture steps writes root-owned files into the run directory.
- Commands:
  - reviewed the shared helper and verify workflow note:
    - `sed -n '1,180p' scripts/lib-experiment-workflow.sh`
    - `sed -n '1,120p' docs/pmic-followup-experiments.md`
  - `apply_patch` updating:
    - `scripts/lib-experiment-workflow.sh`
    - `docs/pmic-followup-experiments.md`
    - `WORKLOG.md`
  - validated the helper and wrapper entrypoint:
    - `bash -n scripts/lib-experiment-workflow.sh`
    - `scripts/exp1-pmic-instrumentation-verify.sh --dry-run`
- Result:
  - the shared helper now checks whether anything in the verify run directory is
    owned by a different uid/gid and, if so, runs `chown -R` back to the
    invoking user
  - this closes the mixed-ownership gap after root-assisted PMIC dumps or other
    future verify-side capture steps
  - the verify wrapper still parses and resolves its commands cleanly after the
    change

### Add scripted update/reboot/verify wrappers for the six ordered PMIC follow-ups

- Plan: turn the ordered PMIC-side follow-ups into repeatable wrapper scripts
  that reuse the current patch-stack and clean-boot capture workflow, while
  adding the missing root install, `depmod`, reboot, and post-boot PMIC-dump
  steps.
- Commands:
  - reviewed the current workflow and capture helpers:
    - `find scripts -maxdepth 2 -type f | sort`
    - `sed -n '1,260p' scripts/patch-kernel.sh`
    - `sed -n '1,260p' scripts/01-clean-boot-check.sh`
    - `sed -n '1,320p' scripts/webcam-run.sh`
    - `sed -n '1,260p' docs/module-iteration.md`
    - `sed -n '1,260p' docs/test-routines.md`
  - checked the current kernel module boundaries and install paths:
    - `sed -n '1,220p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/Makefile`
    - `find /usr/lib/modules/$(uname -r)/kernel/drivers/... | rg 'tps68470|ov5675|ipu-bridge|videodev'`
  - added the shared workflow helper and per-experiment wrappers:
    - `scripts/lib-experiment-workflow.sh`
    - `scripts/exp1-pmic-instrumentation-update.sh`
    - `scripts/exp1-pmic-instrumentation-verify.sh`
    - `scripts/exp2-wf-s-i2c-ctl-update.sh`
    - `scripts/exp2-wf-s-i2c-ctl-verify.sh`
    - `scripts/exp3-ms13q3-vd-1050mv-update.sh`
    - `scripts/exp3-ms13q3-vd-1050mv-verify.sh`
    - `scripts/exp4-wf-init-value-programming-update.sh`
    - `scripts/exp4-wf-init-value-programming-verify.sh`
    - `scripts/exp5-wf-gpio-mode-followup-update.sh`
    - `scripts/exp5-wf-gpio-mode-followup-verify.sh`
    - `scripts/exp6-uf-gpio4-last-resort-update.sh`
    - `scripts/exp6-uf-gpio4-last-resort-verify.sh`
  - documented the workflow and refreshed repo entrypoints:
    - `docs/pmic-followup-experiments.md`
    - `README.md`
    - `docs/README.md`
    - `docs/module-iteration.md`
    - `docs/test-routines.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the repo now has one shared helper that does the careful parts consistently:
    - validates the kernel tree and patch path
    - applies the baseline patch stack via `scripts/patch-kernel.sh`
    - applies one experiment patch
    - rebuilds baseline plus experiment-specific module trees
    - installs `.ko.zst` files into `/usr/lib/modules/<release>/...`
    - runs `depmod`
    - writes an update log under `runs/`
    - prompts before reboot unless `--yes` is passed
  - each of the six ordered PMIC experiments now has a matching
    `*-update.sh` and `*-verify.sh` wrapper
  - the verify side now standardizes:
    - `scripts/01-clean-boot-check.sh`
    - experiment-specific journal grep
    - root PMIC register dump via `scripts/pmic-reg-dump.sh`
    - `modinfo` capture for the installed baseline and experiment modules
  - the shared helper now also supports a true `--dry-run` mode for both
    update and verify wrappers:
    - update dry-run resolves the patch path and kernel release, then prints
      the patch/build/install/reboot actions without executing them
    - verify dry-run prints the clean-boot check, journal grep, and PMIC dump
      actions without executing them
  - the new dry-run mode was exercised directly:
    - `scripts/exp1-pmic-instrumentation-update.sh --patch reference/patches/ms13q3-int3472-tps68470-v1.patch --dry-run`
    - `scripts/exp1-pmic-instrumentation-verify.sh --dry-run`
  - that smoke test confirmed:
    - the update wrapper prints the full patch/build/install/depmod/reboot flow
      without touching the kernel tree or installed modules
    - the verify wrapper prints the clean-boot check, journal grep, and PMIC
      dump steps without executing them
  - the workflow is now documented from the normal repo entrypoints instead of
    only existing in the shell history
- Decision:
  - keep the experiment wrappers as workflow scaffolding even before every
    default experiment patch file exists
  - when drafting each new PMIC patch, use the default patch filename already
    reserved by the matching wrapper unless there is a strong reason not to

### Pull more `WF` PMIC behavior into source artifacts and reassess the blocker

- Plan: widen the Windows disassembly capture so the missing `WF`
  constructor/init/config windows and the truncated `S_I2C_CTL` / GPIO helpers
  are preserved in-tree, then update the status docs to reflect what Linux still
  does not model after the latest negative staged-release runs.
- Commands:
  - reviewed the current extractor and notes:
    - `sed -n '1,260p' scripts/extract-iactrllogic64.sh`
    - `sed -n '1,260p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - verified the relevant `iactrllogic64.sys` windows directly:
    - `objdump -d -M intel --start-address=0x140012740 --stop-address=0x140012c80 ...`
    - `objdump -d -M intel --start-address=0x14001357c --stop-address=0x1400139f0 ...`
    - `objdump -d -M intel --start-address=0x1400148e4 --stop-address=0x140014c20 ...`
    - `objdump -d -M intel --start-address=0x140013ab0 --stop-address=0x140013b40 ...`
  - checked the local ACPI tuple hints:
    - `sed -n '250,420p' reference/acpi/20260308T004459-unknown-host/dsl/ssdt10.dsl`
  - `apply_patch` updating:
    - `scripts/extract-iactrllogic64.sh`
    - `docs/wf-vs-uf-gpio-analysis.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
  - regenerated the Windows analysis artifacts:
    - `scripts/extract-iactrllogic64.sh`
  - rewrote the Windows sequencing note:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
- Result:
  - the extractor now preserves the missing `WF` source windows:
    - `disasm-voltage-wf-constructor.txt`
    - `disasm-voltage-wf-initialize.txt`
    - `disasm-voltage-wf-setconf.txt`
    - widened `disasm-voltage-wf-ioactive-gpio.txt`
    - widened `disasm-voltage-wf-setvsioctl-gpio.txt`
    - widened `disasm-voltage-wf-setvsioctl-io.txt`
  - the regenerated artifacts also correct the earlier power-path filename drift:
    - `disasm-voltage-uf-poweroff.txt` now captures `0x140013214`
    - `disasm-voltage-uf-poweron.txt` now captures `0x14001357c`
    - `disasm-voltage-wf-poweron.txt` now captures `0x140013868`
  - the strongest new source-backed `WF` findings are:
    - Windows carries a five-voltage tuple:
      `VD=1050`, `VA=2800`, `VIO=1800`, `VCM=2800`, `VSIO=1800`
    - `WF::Initialize` writes PMIC value registers
      `0x41`, `0x40`, `0x42`, `0x3c`, and `0x3f`
    - `WF::SetVSIOCtl_IO` stages register `0x43` rather than treating it as a
      single generic enable
  - the three newer staged `ov5675` GPIO-release clean boots are now recorded as
    part of the live assessment:
    - `sequence=1`, `delay_us=2000`: negative
    - `sequence=2`, `delay_us=2000`: negative
    - control `sequence=0`: negative
  - the blocker is now documented more precisely:
    - the GPIO-only branch is largely exhausted
    - the next likely Linux gap is `WF` PMIC behavior, not another pure sensor
      GPIO release tweak
- Decision:
  - stop describing staged `ov5675` GPIO release as the leading next branch
  - use the recovered Windows `WF` PMIC path as the next comparison baseline
    for any Linux patch attempt

### Fix stale candidate docs and clean-boot journal anchoring

- Plan: verify the reviewer-reported consistency drift, then align the stale
  status/follow-up docs with the current `ov5675` sequencing branch and remove
  the clean-boot snapshot harness blind spot where one journal artifact only
  started at wrapper launch time.
- Commands:
  - reviewed the affected files:
    - `sed -n '1,220p' state/CONTEXT.md`
    - `sed -n '1,220p' PLAN.md`
    - `sed -n '1,220p' WORKLOG.md`
    - `sed -n '1,360p' docs/webcam-status.md`
    - `sed -n '1,220p' docs/int3472-gpio1-powerdown-active-high-followup.md`
    - `sed -n '1,320p' scripts/webcam-run.sh`
    - `sed -n '1,220p' docs/reprobe-harness.md`
  - `apply_patch` updating:
    - `README.md`
    - `docs/webcam-status.md`
    - `docs/int3472-gpio1-powerdown-active-high-followup.md`
    - `scripts/webcam-run.sh`
    - `docs/reprobe-harness.md`
    - `WORKLOG.md`
  - validated the changes:
    - `bash -n scripts/webcam-run.sh`
    - `rg -n 'Current concrete next candidate|journal-since-run-start|journal-since-capture-anchor|current-boot-start|Historical Test Flow|Patch Under Test' docs/webcam-status.md docs/int3472-gpio1-powerdown-active-high-followup.md scripts/webcam-run.sh docs/reprobe-harness.md`
    - `scripts/webcam-run.sh snapshot --label anchor-smoke --note 'smoke test capture anchor change' --runs-root /tmp/webcam-run-smoke`
    - `sed -n '1,40p' /tmp/webcam-run-smoke/2026-03-09/20260309T041529-snapshot-anchor-smoke/pre/metadata.env`
    - `sed -n '1,20p' /tmp/webcam-run-smoke/2026-03-09/20260309T041529-snapshot-anchor-smoke/summary.env`
- Result:
  - `docs/webcam-status.md` now points the live next candidate at
    `ov5675-gpio-release-sequencing-debug-v1.patch` instead of the superseded
    `GPIO1` polarity patch
  - `docs/int3472-gpio1-powerdown-active-high-followup.md` now reads as a
    historical negative-result note and redirects readers to the live
    sequencing runbook instead of presenting itself as the current candidate
  - the same follow-up doc now labels the old `INT3472` rebuild path as
    historical, so it no longer conflicts with the current module-only
    `ov5675` candidate composition
  - `scripts/webcam-run.sh` now records boot-start metadata and uses a
    capture-anchor model:
    - `snapshot` runs anchor journal capture at current boot start
    - `reprobe-modules` runs still anchor at action start
  - the misleading `journal-since-run-start.txt` artifact is replaced with
    `journal-since-capture-anchor.txt`, and the harness doc now explains the
    new semantics
  - a real snapshot smoke test under `/tmp/webcam-run-smoke` succeeded and
    confirmed the new metadata fields:
    - `boot_start_*`
    - `journal_capture_anchor_*`
    - `journal_capture_anchor_kind=current-boot-start` for `snapshot`
- Decision:
  - treat the reviewer-reported drift as fixed in-tree
  - keep using clean-boot snapshots as the primary truth source, now with the
    capture-anchor artifact aligned to the actual boot-time evidence we care
    about

### Record the negative second polarity clean boot and pivot to `ov5675` GPIO sequencing

- Plan: review the clean-boot result of the other physical-line polarity
  variant, record whether it changed the identify timeout, and if it did not,
  turn the next branch into a cheaper `ov5675` module-only sequencing debug
  experiment rather than more one-line board-data churn.
- Commands:
  - reviewed the new clean-boot run:
    - `sed -n '1,220p' runs/2026-03-09/20260309T035410-snapshot-gpio1-powerdown-active-high-v1/focused-summary.txt`
    - `sed -n '1,260p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensor-g2ti-poweron.txt`
    - `sed -n '1,260p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensor-g2ti-setgpiooutput.txt`
    - `sed -n '1,260p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-ioactive-gpio.txt`
    - `sed -n '1038,1125p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
  - `apply_patch` adding and updating:
    - `reference/patches/ov5675-gpio-release-sequencing-debug-v1.patch`
    - `docs/ov5675-gpio-release-sequencing-followup.md`
    - `scripts/01-clean-boot-check.sh`
    - `scripts/patch-kernel.sh`
    - `docs/patch-kernel-workflow.md`
    - `docs/module-iteration.md`
    - `docs/README.md`
    - `README.md`
    - `docs/webcam-status.md`
    - `docs/int3472-gpio1-powerdown-active-high-followup.md`
    - `docs/wf-vs-uf-gpio-analysis.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the clean-boot `gpio1-powerdown-active-high-v1` run is also a real
    negative result:
    - `OVTI5675:00` is still found
    - chip-ID read attempts `1/5` through `5/5` still fail with `-110`
    - `ov5675` remains unbound
    - there are still no `/dev/v4l-subdev*` nodes
  - unlike the first one-line polarity run, this second variant did not add the
    early `-517` / GPIO-provider deferral noise, so it is the cleaner polarity
    negative result
  - with both physical one-line polarity variants now negative, the next
    likely local gap is no longer which single PMIC line should be active-high
  - the next better branch is now a module-only `ov5675` sequencing test:
    - keep the current `WF` / `LNK0` board-data model
    - keep the current identify-debug branch
    - add tunable staged GPIO release order and delay in `ov5675`
  - `scripts/patch-kernel.sh` candidate mode now models that branch and also
    normalizes all three older superseded `INT3472` follow-up patches from a
    dirty kernel tree
- Decision:
  - stop spending the next cycle on one-line board-data polarity
  - use staged `ov5675` GPIO release order and delay as the next module-only
    clean-boot experiment

### Record the negative first polarity clean boot and prepare the other-line follow-up

- Plan: review the first polarity clean-boot result, record whether it moved
  the failure, and if it did not, pivot the patch stack to the other smallest
  physical-line polarity variant while keeping the kernel-tree workflow
  repeatable.
- Commands:
  - reviewed the clean-boot result:
    - `sed -n '1,220p' runs/2026-03-09/20260309T030403-snapshot-powerdown-active-high-v1/focused-summary.txt`
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|INT3472|i2c_designware|ETIMEDOUT|Failed to enable|failed to disable|regulator'`
  - `apply_patch` adding and updating:
    - `reference/patches/ms13q3-int3472-gpio1-powerdown-active-high-v1.patch`
    - `docs/int3472-gpio1-powerdown-active-high-followup.md`
    - `docs/int3472-gpio-polarity-followup.md`
    - `scripts/patch-kernel.sh`
    - `docs/patch-kernel-workflow.md`
    - `docs/module-iteration.md`
    - `docs/README.md`
    - `README.md`
    - `docs/webcam-status.md`
    - `docs/wf-vs-uf-gpio-analysis.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
  - validated the new candidate:
    - `bash -n scripts/patch-kernel.sh`
    - `scripts/patch-kernel.sh --profile candidate --status`
    - temporary-tree validation:
      - `git clone --shared --quiet ~/.cache/paru/clone/linux-mainline/src/linux-mainline ...`
      - `git -C <tmp-tree> apply reference/patches/ms13q3-int3472-tps68470-v1.patch`
      - `git -C <tmp-tree> apply --check reference/patches/ms13q3-int3472-gpio1-powerdown-active-high-v1.patch`
- Result:
  - the first one-line polarity clean boot was a real negative result:
    - `OVTI5675:00` is still found
    - chip-ID read attempts `1/5` through `5/5` still fail with `-110`
    - `ov5675` remains unbound
    - there are still no `/dev/v4l-subdev*` nodes
  - that run also showed an early `-EPROBE_DEFER` path:
    - `cannot find GPIO chip tps68470-gpio, deferring`
    - `failed to get reset-gpios: -517`
    - but probe retried and still reached the same clean-boot identify timeout
  - the next smallest physical-line experiment is now:
    - `GPIO1` => `powerdown`, `GPIO_ACTIVE_HIGH`
    - `GPIO2` => `reset`, `GPIO_ACTIVE_LOW`
  - this should be read as "other PMIC line active-high", not as strong proof
    that Linux now knows the true semantic roles
  - the first status pass exposed a real workflow bug:
    - `patch-kernel.sh` normalized the old `gpio-swap` follow-up
    - but returned early and failed to normalize the newer superseded
      `powerdown-active-high` patch
  - that bug is now fixed:
    - `scripts/patch-kernel.sh --profile candidate --status` reports the new
      `ms13q3-gpio1-powerdown-active-high` follow-up as `applicable` on the
      current dirty kernel tree
- Decision:
  - treat the first `GPIO2`-active-high polarity run as negative
  - use the `GPIO1`-active-high physical-line variant as the next module-only
    clean-boot test

### Prepare the next `INT3472` polarity follow-up after the negative `gpio-swap-v1` run

- Plan: turn the next meaningful board-data experiment into a repeatable repo
  artifact, and update `patch-kernel.sh` so it can move forward from the now
  superseded `gpio-swap` follow-up without manual cleanup in the local kernel
  tree.
- Commands:
  - reviewed the current tested stack and kernel-side rationale:
    - `sed -n '1,240p' docs/linux-board-data-candidate.md`
    - `sed -n '1,240p' docs/ov5675-powerdown-followup.md`
    - `rg -n 'GPIO1|GPIO2|powerdown|reset' docs reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1 -g '*.md' -g '*.txt'`
    - `sed -n '1,220p' scripts/patch-kernel.sh`
    - `sed -n '1,220p' docs/patch-kernel-workflow.md`
    - `sed -n '1,120p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - `apply_patch` adding and updating:
    - `reference/patches/ms13q3-int3472-powerdown-active-high-v1.patch`
    - `docs/int3472-gpio-polarity-followup.md`
    - `scripts/patch-kernel.sh`
    - `docs/patch-kernel-workflow.md`
    - `docs/module-iteration.md`
    - `docs/README.md`
    - `README.md`
    - `docs/webcam-status.md`
    - `docs/wf-vs-uf-gpio-analysis.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
  - validated the new candidate:
    - `bash -n scripts/patch-kernel.sh`
    - `scripts/patch-kernel.sh --profile candidate --status`
    - temporary-tree validation:
      - `git clone --shared --quiet ~/.cache/paru/clone/linux-mainline/src/linux-mainline ...`
      - `git -C <tmp-tree> apply reference/patches/ms13q3-int3472-tps68470-v1.patch`
      - `git -C <tmp-tree> apply --check reference/patches/ms13q3-int3472-powerdown-active-high-v1.patch`
- Result:
  - the next candidate is now a real polarity experiment:
    - keep `GPIO1` as `reset`, `GPIO_ACTIVE_LOW`
    - change `GPIO2` `powerdown` to `GPIO_ACTIVE_HIGH`
  - this is a more meaningful next step than another label-only swap because
    the current `ov5675` power sequence drives both control lines in lockstep
  - `scripts/patch-kernel.sh` now treats
    `ms13q3-int3472-powerdown-active-high-v1.patch` as the current
    `candidate` profile
  - the patch-stack workflow also now normalizes one superseded local state:
    - if the kernel tree still has `ms13q3-int3472-gpio-swap-v1.patch`
      applied, `candidate` mode reverses it first
  - validation succeeded:
    - the new patch applies cleanly after the tested board-data patch on a
      temporary clean tree
    - `scripts/patch-kernel.sh --profile candidate --status` reports the new
      follow-up as `applicable`
- Decision:
  - use this polarity variant as the next module-only clean-boot test
  - only revisit other GPIO polarity/line combinations if this first variant
    is negative

### Record the negative clean-boot `gpio-swap-v1` result

- Plan: review the first clean-boot run after the `INT3472` `GPIO1` / `GPIO2`
  role-swap patch, write down the actual result, and update the investigation
  direction if the run turns out to be low-signal.
- Commands:
  - reviewed the new clean-boot run:
    - `sed -n '1,220p' runs/2026-03-09/20260309T023655-snapshot-gpio-swap-v1/focused-summary.txt`
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|INT3472|i2c_designware|ETIMEDOUT|Failed to enable|failed to disable|regulator'`
  - re-checked the current `ov5675` power sequence and the existing Windows
    helper note:
    - `sed -n '1085,1165p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `sed -n '1,240p' docs/wf-vs-uf-gpio-analysis.md`
    - `sed -n '1,220p' docs/int3472-gpio-swap-followup.md`
  - `apply_patch` updating:
    - `docs/int3472-gpio-swap-followup.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `WORKLOG.md`
- Result:
  - the clean-boot `gpio-swap-v1` run is a real negative result:
    - `OVTI5675:00` is still found
    - `INT3472:06` is still bound
    - chip-ID read attempts `1/5` through `5/5` still fail with `-110`
    - `ov5675` remains unbound
    - there are still no `/dev/v4l-subdev*` nodes
  - the broader boot log also still shows the same follow-on controller and
    cleanup fallout after the failed identify stage:
    - repeated `i2c_designware.1: controller timed out`
    - `VSIO`, `CORE`, and `ANA` disable failures
    - regulator-core warnings after the bus is already wedged
  - the most important new interpretation is that the role-swap patch was also
    low-signal:
    - current `ov5675_power_on()` drives both control lines together
    - both lines are set to logical `1` before rail enable
    - both lines are set to logical `0` after the stabilization delay
    - both lines return to logical `1` on power-off
  - so a pure `reset` / `powerdown` label swap with the same active-low flags
    does not materially change the physical waveform during probe
- Decision:
  - stop treating label-only swaps as a strong next-step class
  - treat `GPIO1` / `GPIO2` polarity changes as the next meaningful
    board-data-space experiment
  - keep `WF` / `LNK0` as the primary model until stronger evidence justifies a
    `UF` / `gpio.4` pivot

### Prepare the next module-only `INT3472` GPIO role-swap experiment

- Plan: turn the next most defensible Linux experiment into a repeatable repo
  artifact: one small board-data patch, one exact module-only rebuild/install
  flow, and a patch-stack update so `candidate` now matches the real next test.
- Commands:
  - reviewed the current patch-stack and module-only workflow:
    - `git status -sb`
    - `sed -n '1,220p' scripts/patch-kernel.sh`
    - `sed -n '1,260p' docs/patch-kernel-workflow.md`
    - `sed -n '1,220p' docs/module-iteration.md`
  - reviewed the current MSI board-data and earlier board-data note:
    - `sed -n '330,390p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `sed -n '1,220p' docs/linux-board-data-candidate.md`
  - `apply_patch` adding and updating:
    - `reference/patches/ms13q3-int3472-gpio-swap-v1.patch`
    - `docs/int3472-gpio-swap-followup.md`
    - `scripts/patch-kernel.sh`
    - `docs/patch-kernel-workflow.md`
    - `docs/module-iteration.md`
    - `docs/README.md`
    - `README.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
  - validated the new candidate:
    - `bash -n scripts/patch-kernel.sh`
    - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline apply --check /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/patches/ms13q3-int3472-gpio-swap-v1.patch`
    - `scripts/patch-kernel.sh --profile candidate --status`
- Result:
  - the next smallest Linux follow-up is now captured as
    `reference/patches/ms13q3-int3472-gpio-swap-v1.patch`
  - this patch keeps the same MSI `INT3472` board-data entry and the same PMIC
    lines, but swaps only their semantic roles:
    - `GPIO1` => `powerdown`
    - `GPIO2` => `reset`
  - this follows the current evidence ordering:
    - `WF` / `LNK0` is still the best-supported path
    - `GPIO1` / `GPIO2` still look like the right control-line pair
    - role assignment is still unproven
  - `scripts/patch-kernel.sh` now treats that role-swap patch as the current
    `candidate` profile instead of the older negative `powerdown` branch
  - `docs/int3472-gpio-swap-followup.md` now gives the exact user-run flow:
    - apply candidate stack
    - rebuild only `drivers/platform/x86/intel/int3472`
    - replace only `intel_skl_int3472_tps68470.ko.zst`
    - reboot
    - run `scripts/01-clean-boot-check.sh --label gpio-swap-v1`
  - validation succeeded on the current local kernel tree:
    - the patch applies cleanly
    - `scripts/patch-kernel.sh --profile candidate --status` reports the new
      `ms13q3-gpio-swap` follow-up as `applicable`
- Decision:
  - use the role-swap test before polarity or `gpio.4` / `UF` experiments
  - keep the test module-local and clean-boot based

### Clarify whether `WF` / `UF` maps to RGB vs IR sensors on this laptop

- Plan: answer whether the captured Windows helper split is actually the normal
  webcam vs Windows Hello IR split, or whether that is still only a plausible
  but unproven interpretation.
- Commands:
  - reviewed local ACPI camera-link and live-state evidence:
    - `sed -n '1238,1265p' reference/acpi/20260308T004459-unknown-host/dsl/ssdt17.dsl`
    - `sed -n '1,260p' reference/acpi/20260308T004459-unknown-host/live-linux-acpi-state.txt`
    - `find /sys/bus/acpi/devices -maxdepth 1 -type l | xargs -r -n1 basename | rg 'OVTI|HM1|INT3472|LNK|IR|OV'`
    - `for d in /sys/bus/acpi/devices/OVTI13B1:00 /sys/bus/acpi/devices/OVTI01AF:00 /sys/bus/acpi/devices/OVTI01AF:01 /sys/bus/acpi/devices/OVTI01AF:02; do ...; done`
  - reviewed the two main camera-related Windows package INFs:
    - `iconv -f utf-16le -t utf-8 reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/extracted/hm1092.inf | sed -n '1,180p'`
    - `reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/extracted/ov5675.inf`
  - updated:
    - `docs/wf-vs-uf-gpio-analysis.md`
    - `WORKLOG.md`
- Result:
  - the MSI Windows package really does include an IR-oriented sensor path:
    - `hm1092.inf` installs `ACPI\\HIMX1092`
    - it carries explicit `IRFlashLedIntensity` and `IRSensor` registry hints
  - that makes a normal-camera plus IR-camera design plausible in the package
    as a whole
  - but the local machine evidence still does not justify saying `WF` = RGB and
    `UF` = IR on this exact laptop:
    - the only live active sensor path remains `OVTI5675:00` at `LNK0`
    - `WFCS` still points to `LNK0`
    - `LNK1` exists in firmware but is not active
    - other firmware-described sensor links exist but are currently disabled
    - there is no live `HIMX1092` / `HM1092` ACPI sensor exposed on this Linux
      install
  - the best current interpretation is still that `WF` and `UF` are Windows
    helper or board families, not yet a proven RGB-vs-IR split for this model
- Decision:
  - keep treating `WF` / `UF` as control-driver helper families first
  - do not use an assumed RGB-vs-IR mapping as the basis for the next Linux
    patch step without stronger local evidence

### Analyze the Windows `WF` vs `UF` helper split before changing Linux GPIO wiring

- Plan: inspect the newer clean-boot `-110` identify-timeout baseline against
  the Windows helper-family split, then document whether the next Linux follow
  up should still stay on the current `GPIO1` / `GPIO2` model or whether the
  evidence now justifies a different PMIC GPIO path.
- Commands:
  - reviewed the current repo state and entrypoint docs:
    - `git status -sb`
    - `sed -n '1,240p' state/CONTEXT.md`
    - `sed -n '1,220p' PLAN.md`
    - `sed -n '1,220p' WORKLOG.md`
    - `sed -n '1,260p' docs/webcam-status.md`
    - `sed -n '1,220p' README.md`
    - `sed -n '1,220p' docs/README.md`
  - reviewed the current Windows sequencing note:
    - `sed -n '1,240p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - reviewed the current Linux MSI board-data and TPS68470 GPIO numbering:
    - `sed -n '330,430p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `sed -n '1,220p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
  - extracted the relevant Windows helper and ACPI references:
    - `sed -n '1,220p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensor-g2ti-poweron.txt`
    - `sed -n '1,220p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensor-g2ti-poweroff.txt`
    - `sed -n '1,220p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-ioactive-gpio.txt`
    - `sed -n '1,220p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-uf-setvactl.txt`
    - `sed -n '1,220p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-addresses.txt`
    - `sed -n '1,220p' reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-xrefs.txt`
    - `sed -n '40,90p' reference/acpi/20260308T004459-unknown-host/dsl/ssdt1.dsl`
    - `sed -n '1500,1565p' reference/acpi/20260308T004459-unknown-host/dsl/ssdt17.dsl`
    - `rg -n 'WFCS|UFCS|LNK0|LNK1|C0TP|MiCaTabl|OVTI5675|INT3472:06' reference/acpi/20260308T004459-unknown-host/dsl/ssdt1.dsl reference/acpi/20260308T004459-unknown-host/dsl/ssdt17.dsl`
  - `apply_patch` adding and updating:
    - `docs/wf-vs-uf-gpio-analysis.md`
    - `docs/README.md`
    - `README.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the Windows package really does contain two `TPS68470` helper families:
    - `WF`
    - `UF`
  - `CrdG2TiSensor::SensorPowerOn` branches into either
    `Tps68470VoltageWF::PowerOn` or `Tps68470VoltageUF::PowerOn`, so the MSI
    package is not describing only one board wiring
  - the `WF` helper path still provides the strongest direct match to the
    current Linux MSI hypothesis:
    - `IoActive_GPIO` programs registers `0x16` and `0x18`
    - those are Linux `GPCTL1A` and `GPCTL2A`
    - that keeps `GPIO1` / `GPIO2` as the best-supported camera-control pair
  - the `UF` helper path adds a real caution:
    - `Tps68470VoltageUF::SetVACtl` reads and writes `GPDO` register `0x27`
    - it toggles bit `0x10`
    - in Linux numbering that would be regular `gpio.4`
  - but the local ACPI evidence still favors `WF`, not `UF`:
    - `WFCS = "\\_SB.PC00.LNK0"`
    - `UFCS = "\\_SB.PC00.LNK1"`
    - this laptop's active sensor path is already known to be `LNK0`
    - `MiCaTabl` still routes the active PMIC companion through `CLP0` for the
      `LNK0` path when `C0TP > 1`
  - therefore the cleanest next Linux experiments remain:
    - `GPIO1` / `GPIO2` role swap
    - `GPIO1` / `GPIO2` polarity variants
    - remaining `WF`-side sequencing detail
  - the analysis does not justify a first next step that blindly pivots Linux
    board data to `gpio.4`
- Decision:
  - keep the clean-boot `-110` identify timeout as the current primary
    baseline
  - keep `WF` / `LNK0` as the primary model for this laptop
  - use `GPIO1` / `GPIO2` semantics and polarity as the next rational Linux
    test space before revisiting the `UF` / `gpio.4` branch

### Record the clean-boot identify-debug result from `journalctl -b -k`

- Plan: confirm whether the first-load identify-debug boot finally reaches the
  chip-ID path, convert that boot log into the new primary failure baseline,
  and update the clean-boot wrapper so future boot checkpoints preserve the
  identify lines directly.
- Commands:
  - reviewed the live boot log directly:
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|tps68470|INT3472|intel-ipu7|ipu7|chip id|power on|GPIO|gpio|Failed to enable|failed to power on|failed to find sensor|probe with driver ov5675 failed|extra post-power-on delay|sensor identified on attempt'`
  - confirmed the active debug module parameters:
    - `cat /sys/module/ov5675/parameters/identify_retry_count`
    - `cat /sys/module/ov5675/parameters/identify_retry_delay_us`
    - `cat /sys/module/ov5675/parameters/extra_post_power_on_delay_us`
  - confirmed driver binding state:
    - `readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || echo int3472-unbound`
    - `readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo ov5675-unbound`
  - attempted a normal clean-boot checkpoint:
    - `scripts/01-clean-boot-check.sh --label identify-debug-v1-boot --note "clean boot with ov5675 identify debug params"`
  - `apply_patch` adding and updating:
    - `scripts/01-clean-boot-check.sh`
    - `docs/test-routines.md`
    - `docs/ov5675-identify-debug-followup.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the clean-boot identify-debug run is the first trustworthy sensor-side
    result after the earlier `-5` ambiguity:
    - `ov5675_identify_module()` is reached
    - chip-ID attempts 1 through 5 all fail with `-110`
    - `failed to find sensor` now also reports `-110`
  - confirmed debug module parameters on the live boot:
    - `identify_retry_count=5`
    - `identify_retry_delay_us=2000`
    - `extra_post_power_on_delay_us=0`
  - `INT3472:06` remains bound, while `OVTI5675:00` remains unbound
  - this strongly suggests the remaining blocker is not merely the old
    collapsed error handling or a missing retry loop; it is a real transport /
    wake-up / sequencing failure at chip-ID read time
  - the attempted `01-clean-boot-check.sh` run failed to archive because
    `runs/2026-03-09/` is currently root-owned from earlier sudo-driven runs
  - updated `scripts/01-clean-boot-check.sh` so future clean-boot checkpoints
    include the identify-debug lines directly
- Decision:
  - treat repeated clean-boot chip-ID read timeouts `-110` as the new baseline
  - de-prioritize simple identify-delay tuning as the leading standalone fix
  - shift the next patch focus back toward GPIO semantics, polarity, or
    remaining PMIC wake-up sequencing

### Clarify in AGENTS that `sudo` and `reboot` are user-run steps

- Plan: add an explicit repo-local reminder that privileged commands and
  reboots are user-run steps, so future sessions do not blur the boundary when
  proposing kernel install, module install, or clean-boot tests.
- Commands:
  - reviewed the current repo policy:
    - `AGENTS.md`
  - `apply_patch` adding and updating:
    - `AGENTS.md`
    - `WORKLOG.md`
- Result:
  - `AGENTS.md` now explicitly says:
    - `sudo` steps are user-run unless the user explicitly asks to run them and
      the environment permits it
    - `reboot` is user-run
    - when a next step needs either one, the agent should provide the exact
      commands and say what those steps are meant to validate
- Decision:
  - treat privilege and reboot boundaries as an explicit part of repo workflow,
    not just an implicit environment constraint.

### Record the first identify-debug reload result and tighten the next test plan

- Plan: preserve the first run after installing the identify-debug `ov5675`
  module build, make sure the worklog captures what it actually did and did not
  tell us, and update the next-step plan so we stop over-interpreting
  reload-after-failure runs.
- Commands:
  - reviewed the new reload run:
    - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/`
    - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/focused-summary.txt`
    - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/post/journal-since-run-start.txt`
  - reviewed the identify-debug wrapper to confirm what it currently captures:
    - `scripts/03-ov5675-identify-debug-check.sh`
  - `apply_patch` adding and updating:
    - `scripts/03-ov5675-identify-debug-check.sh`
    - `docs/test-routines.md`
    - `docs/ov5675-identify-debug-followup.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the identify-debug `ov5675` build is installed and the reload wrapper ran
    successfully enough to archive a normal snapshot under:
    - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/`
  - but the first reload-only run still did not reach the new chip-ID logging:
    - `ov5675 i2c-OVTI5675:00: setup of GPIO reset failed: -110`
    - `ov5675 i2c-OVTI5675:00: failed to get reset-gpios: -110`
    - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
  - there were no identify-attempt logs in that run, so it did not narrow the
    remaining clean-boot `-5` failure yet
  - the likely reason is the same one we have seen in earlier reload-only
    attempts:
    - once the boot-time probe has already failed, the reload path can die
      earlier and become non-diagnostic
  - updated `scripts/03-ov5675-identify-debug-check.sh` so its focused summary
    now includes the `reset-gpios` failure lines instead of hiding them
- Decision:
  - treat the first identify-debug reload as an intermediate checkpoint, not as
    a new root-cause signal
  - the next trustworthy use of the debug branch is a clean boot with the
    identify-debug module parameters applied on first load
  - until that run exists, the last strong primary result is still the clean
    boot `ov5675 ... failed to find sensor: -5`

## 2026-03-08

### Record the current Windows-vs-Linux assessment and prepare an identify-debug branch

- Plan: capture the current assessment in a dated worklog entry, then turn the
  remaining uncertainty into a module-only `ov5675` debug branch that can tell
  us whether the next problem is timing, GPIO semantics, or a deeper transport
  failure.
- Commands:
  - reviewed the recovered Windows sequencing notes:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensor-g2ti-poweron.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensor-g2ti-setgpiooutput.txt`
  - reviewed the current Linux sensor path:
    - `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - reviewed the current reload wrapper and doc indexes:
    - `scripts/02-ov5675-reload-check.sh`
    - `docs/test-routines.md`
    - `README.md`
    - `docs/README.md`
  - validated the new debug artifacts:
    - `bash -n scripts/03-ov5675-identify-debug-check.sh`
    - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline apply --check reference/patches/ov5675-identify-debug-v1.patch`
  - `apply_patch` adding and updating:
    - `docs/ov5675-identify-debug-followup.md`
    - `reference/patches/ov5675-identify-debug-v1.patch`
    - `scripts/03-ov5675-identify-debug-check.sh`
    - `docs/test-routines.md`
    - `README.md`
    - `docs/README.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the current Linux path matches the Windows bring-up only at a high level:
    - board-data is active
    - `ipu-bridge` is fixed
    - rail order now matches the recovered Windows `VA -> VD -> VSIO` shape
    - two PMIC GPIOs are exposed as `reset` and `powerdown`
  - but Windows `SensorPowerOn` still includes additional conditional helper
    calls that Linux has not matched yet
  - Linux also currently throws away the underlying I2C transport error during
    chip-ID reads by collapsing failed transfers to plain `-EIO`
  - the new debug patch candidate addresses that by:
    - preserving negative I2C error codes
    - logging per-attempt chip-ID failures
    - adding tunable identify retries
    - adding tunable extra post-power-on delay
  - the new numbered wrapper `scripts/03-ov5675-identify-debug-check.sh` makes
    that branch easy to test after a module-only rebuild
  - the patch candidate applies cleanly to the current local `linux-mainline`
    worktree state, and the new wrapper passes `bash -n`
- Decision: use the identify-debug branch before guessing another support fix,
  because the next useful result is a better failure signal, not another blind
  semantic change.

### Record the negative `powerdown-v1` clean boot and add Codex resume notes

- Plan: preserve the first clean-boot result after the `powerdown` follow-up,
  update the repo entrypoints so they reflect that negative result, and add
  exact local `codex resume` instructions so the next session can be resumed
  without guesswork.
- Commands:
  - reviewed the new clean-boot run:
    - `runs/2026-03-08/20260308T160828-snapshot-powerdown-v1/`
    - `runs/2026-03-08/20260308T160828-snapshot-powerdown-v1/focused-summary.txt`
  - checked local Codex resume syntax:
    - `codex --help`
    - `codex resume --help`
  - identified the current local session id from Codex history:
    - `019cc8a9-ae0e-7dc0-9b99-c293ea51b666`
  - `apply_patch` adding and updating:
    - `README.md`
    - `docs/webcam-status.md`
    - `docs/ov5675-powerdown-followup.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - the first clean boot after `ov5675-powerdown-followup-v1.patch` did not
    change the failure mode:
    - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
    - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`
    - no `/dev/v4l-subdev*`
  - this means consuming `powerdown` alone is not sufficient on this laptop
  - the likely next patch space is now:
    - remaining GPIO semantics or polarity
    - extra post-power-on delay
    - board-data regulator-consumer or sequencing follow-up
  - `README.md` and `state/CONTEXT.md` now include exact local `codex resume`
    commands so the next session can be recovered quickly
- Decision: treat `powerdown-v1` as a negative result and stop treating simple
  `powerdown` consumption as the leading standalone fix.

### Add an idempotent `patch-kernel.sh` for the current patch stack

- Plan: stop relying on hand-applied patch sequences in the local
  `linux-mainline` tree and replace them with a script that can detect
  already-applied patches, apply only what is missing, and expose the current
  stack state clearly.
- Commands:
  - reviewed the current patch inventory:
    - `find reference/patches -maxdepth 1 -type f | sort`
  - reviewed the current local kernel tree state:
    - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline status --short`
  - reviewed the current module-iteration doc:
    - `sed -n '1,220p' docs/module-iteration.md`
  - mechanically validated the patch order against a clean temp clone of the
    local kernel tree:
    - `ms13q3-int3472-tps68470-v1.patch`
    - `ipu-bridge-ovti5675-v1.patch`
    - `ov5675-serial-power-on-v1.patch`
    - `ov5675-powerdown-followup-v1.patch`
  - `apply_patch` adding and updating:
    - `scripts/patch-kernel.sh`
    - `docs/patch-kernel-workflow.md`
    - `README.md`
    - `docs/README.md`
    - `docs/module-iteration.md`
    - `WORKLOG.md`
- Result:
  - added `scripts/patch-kernel.sh`
  - the script is idempotent per patch:
    - skips already-applied patches
    - applies missing patches
    - stops on conflicts
  - added two profiles:
    - `tested`
    - `candidate`
  - validated that the current ordered stack applies cleanly to a clean temp
    clone of the local `linux-mainline` tree
  - verified two important edge cases before committing:
    - higher-order follow-up patches can still satisfy earlier patch markers
    - `--status` now evaluates the selected profile in order on a temporary
      clone of the current tree state, so dependent follow-up patches do not
      show false conflicts on a clean base tree
- Decision: use `scripts/patch-kernel.sh --status` as the first check before
  rebuilding modules or rebooting into a newly patched tree.

### Record the clean serial-power result and pivot to `powerdown` GPIO handling

- Plan: preserve the first clean-boot result after the serial power-on patch,
  confirm whether it really fixed the `dvdd` timeout, and turn the next clean
  failure into the next small module-only patch candidate.
- Commands:
  - reviewed the new clean-boot run:
    - `runs/2026-03-08/20260308T151653-snapshot-serial-power-v1/`
    - `runs/2026-03-08/20260308T151653-snapshot-serial-power-v1/focused-summary.txt`
  - reviewed the relevant boot log and driver state:
    - `journalctl -b -k --no-pager | rg 'TPS68470 REVID|Found supported sensor|Connected 1 cameras|Failed to enable|failed to power on|failed to find sensor|probe with driver ov5675 failed'`
    - `readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || echo int3472-unbound`
    - `readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo ov5675-unbound`
  - reviewed the current `ov5675` identify path and board-data wiring:
    - `drivers/media/i2c/ov5675.c`
    - `drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `drivers/media/i2c/ov5693.c`
    - `drivers/media/i2c/ov2740.c`
  - `apply_patch` adding and updating:
    - `docs/ov5675-powerdown-followup.md`
    - `reference/patches/ov5675-powerdown-followup-v1.patch`
    - `docs/webcam-status.md`
    - `docs/ov5675-power-on-order.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the serial power-on follow-up was a real improvement:
    - the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
    - `ov5675` now gets past the earlier rail-enable failure
  - the new clean-boot failure is:
    - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
  - that means the current blocker is no longer missing graph hookup or rail
    enable order; it is now sensor identification
  - the leading next local hypothesis is:
    - board data already provides both `reset` and `powerdown`
    - `ov5675` still only consumes `reset`
    - the next smallest follow-up is to add optional `powerdown` handling
- Decision: treat the serial power-on patch as a successful narrowing step and
  shift the next module-only iteration from regulator order to second-GPIO
  handling.

### Add numbered checkpoint scripts for clean-boot and ov5675-reload testing

- Plan: make the current iteration loop easier to repeat and easier to compare
  by adding small numbered wrappers around the existing harness rather than
  relying on ad-hoc terminal commands and notes.
- Commands:
  - reviewed the existing harness and docs:
    - `find scripts -maxdepth 2 -type f | sort`
    - `sed -n '1,260p' scripts/webcam-run.sh`
    - `sed -n '1,260p' docs/reprobe-harness.md`
  - reviewed the current failure mode:
    - `journalctl -b -k --no-pager | rg 'Failed to enable|failed to power on|failed to find sensor|probe with driver ov5675 failed|OVTI5675'`
    - `journalctl -b -k --no-pager | rg 'setup of GPIO reset failed|failed to get reset-gpios'`
  - `apply_patch` adding and updating:
    - `scripts/01-clean-boot-check.sh`
    - `scripts/02-ov5675-reload-check.sh`
    - `docs/test-routines.md`
    - `README.md`
    - `docs/README.md`
    - `docs/reprobe-harness.md`
    - `WORKLOG.md`
- Result:
  - added two numbered wrappers on top of `scripts/webcam-run.sh`
  - `01-clean-boot-check.sh` captures the primary clean-boot checkpoint and
    writes a focused summary into the run directory
  - `02-ov5675-reload-check.sh` captures the current reload-only checkpoint and
    writes a focused summary based on journal lines since reload start
  - the wrappers keep using normal `runs/...` directories, so they fit the
    existing archival workflow
  - the current reload-only result also clarified why the wrappers are useful:
    - the clean boot showed `Failed to enable dvdd: -ETIMEDOUT`
    - the later reload-only attempt shifted to
      `setup of GPIO reset failed: -110`
    - that is treated as secondary fallout after the earlier bus timeout, not
      as the primary blocker
- Decision: use `01-clean-boot-check.sh` as the main truth source when a clean
  reboot is available; treat reload-only checks as secondary because they can
  reflect fallout from an earlier wedged PMIC/I2C state.
### Record the clean combined-patch boot result and pivot to `ov5675` power-on sequencing

- Plan: preserve the first clean combined-patch boot, resolve the earlier
  dummy-regulator ambiguity, and turn the new `dvdd` timeout into the next
  concrete module-only patch target.
- Commands:
  - reviewed the new clean-boot run:
    - `runs/2026-03-08/20260308T143023-snapshot-clean-boot-after-ipu-bridge/`
  - reviewed the user-run checks:
    - `journalctl -b -k --no-pager | rg 'TPS68470 REVID|Found supported sensor|Connected 1 cameras|supply avdd|supply dovdd|supply dvdd|failed to find sensor|probe with driver ov5675 failed'`
    - `readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || echo int3472-unbound`
    - `readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo ov5675-unbound`
    - `find /dev -maxdepth 1 -name 'v4l-subdev*' | sort`
  - extracted the sharper failure lines from the same boot:
    - `journalctl -b -k --no-pager | rg 'Failed to enable|failed to power on|ov5675 i2c-OVTI5675:00|tps68470|TPS68470 REVID'`
  - reviewed the relevant kernel paths:
    - `drivers/media/i2c/ov5675.c`
    - `drivers/regulator/core.c`
    - `drivers/regulator/tps68470-regulator.c`
  - `apply_patch` adding and updating:
    - `runs/2026-03-08/20260308T143023-snapshot-clean-boot-after-ipu-bridge/manual-followup.txt`
    - `docs/ov5675-power-on-order.md`
    - `reference/patches/ov5675-serial-power-on-v1.patch`
    - `docs/webcam-status.md`
    - `docs/ipu-bridge-ovti5675-candidate.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the clean combined-patch boot is much better than the earlier disturbed
    session:
    - `INT3472:06` binds cleanly
    - `OVTI5675` is still recognized by `ipu-bridge`
    - the dummy-regulator warnings do not appear
  - the remaining failure is now specific:
    - `Failed to enable dvdd: -ETIMEDOUT`
    - `ov5675 i2c-OVTI5675:00: failed to power on: -110`
  - that means the current blocker is no longer:
    - missing board data
    - missing graph endpoint hookup
    - missing regulator lookup
  - the current blocker is now:
    - `ov5675_power_on()` failing while enabling `dvdd`
  - the next targeted local hypothesis is:
    - Linux should try a serial rail-enable order matching recovered Windows
      sequencing:
      - `avdd`
      - `dvdd`
      - `dovdd`
- Decision: stop using `media-ctl` as the main signal for now; until
  `ov5675_power_on()` succeeds there will still be no sensor subdevice to show.

### Record the first `ipu-bridge` success and narrow the remaining question to a clean-boot regulator check

- Plan: preserve the first successful `ipu-bridge` `OVTI5675` result, but
  document carefully that the later regulator failure is not yet a clean
  verdict because the `INT3472` companion was already in a broken state from
  earlier manual reprobe work.
- Commands:
  - reviewed the user-run bridge-test output:
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|firmware graph|firmware node|xvclk|reset|regulator|ipu7'`
    - `readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo unbound`
    - `readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || echo int3472-unbound`
  - reviewed live and captured state:
    - `lsmod | rg 'ipu_bridge|ov5675|intel_skl_int3472|tps68470|intel_ipu7'`
    - `runs/2026-03-08/20260308T134757-snapshot-after-ipu-bridge-ovti5675/`
    - earlier context line:
      - `int3472-tps68470 i2c-INT3472:06: INT3472 seems to have no dependents`
  - `apply_patch` adding and updating:
    - `runs/2026-03-08/20260308T134757-snapshot-after-ipu-bridge-ovti5675/manual-followup.txt`
    - `docs/ipu-bridge-ovti5675-candidate.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the `ipu-bridge` follow-up patch clearly worked:
    - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
    - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
    - the old `ov5675 ... no firmware graph endpoint found` line disappeared
  - the failure moved forward again:
    - `ov5675` now reaches regulator lookup
    - then reports `avdd` / `dovdd` / `dvdd` not found and falls back to dummy
      regulators
    - then fails sensor detect with `-5`
  - important nuance:
    - this happened after an earlier manual reprobe had already produced
      `INT3472 seems to have no dependents`
    - by the time of live follow-up, `i2c-INT3472:06` was unbound
    - so this run proves the bridge fix, but does **not** yet give a clean
      fresh-boot verdict on the regulator path
- Decision: the next test should be a fresh boot with both patches already
  installed, then a clean baseline capture before any manual reprobe.

### Record the `ov5675` diagnostic result and draft the `ipu-bridge` follow-up

- Plan: preserve the first diagnostic-patch run result, reduce the remaining
  blocker to the next concrete kernel file, and turn that into the next
  module-only patch candidate.
- Commands:
  - reviewed the user-run diagnostic output:
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|firmware graph|firmware node|xvclk|reset|regulator|ipu7'`
    - `ls -l /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || true`
    - `media-ctl -p -d /dev/media0`
    - `find /dev -maxdepth 1 -name 'v4l-subdev*' | sort`
  - reviewed the new captured runs:
    - `runs/2026-03-08/20260308T133322-snapshot-before-ov5675-diag/`
    - `runs/2026-03-08/20260308T133515-snapshot-after-ov5675-diag/`
    - `runs/2026-03-08/20260308T133658-reprobe-modules-after-ov5675-diag/`
  - reviewed the bridge and sensor code:
    - `drivers/media/pci/intel/ipu-bridge.c`
    - `drivers/media/i2c/ov5675.c`
    - `drivers/platform/x86/intel/int3472/common.c`
  - `apply_patch` adding and updating:
    - `runs/2026-03-08/20260308T133515-snapshot-after-ov5675-diag/manual-followup.txt`
    - `reference/patches/ipu-bridge-ovti5675-v1.patch`
    - `docs/ipu-bridge-ovti5675-candidate.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the diagnostic patch produced the first explicit `ov5675` probe error:
    - `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`
  - this means the remaining blocker is now more specific than "sensor probe
    still fails":
    - the sensor client exists
    - the `ov5675` driver is probing
    - the failure happens before chip-ID and streaming logic
  - `ipu_bridge` is loaded on the same kernel, but local `ipu-bridge.c` only
    creates software-node graph endpoints for sensors in
    `ipu_supported_sensors[]`
  - `OVTI5675` is absent from that table
  - local `ov5675.c` expects a single link-frequency at `450000000`
  - drafted the next minimal patch candidate in
    `reference/patches/ipu-bridge-ovti5675-v1.patch`
- Decision: shift the next module-only test from `ov5675.c` to `ipu-bridge.c`;
  the leading hypothesis is now missing `OVTI5675` bridge support, not missing
  PMIC board data.
### Draft `ov5675` diagnostic patch and tighten the module-only integration workflow

- Plan: turn the silent `ov5675` early-exit theory into a real patch artifact,
  and document the exact module-only apply/build/install/reload steps against
  the current `linux-mainline` package layout.
- Commands:
  - reviewed the current `ov5675` probe path:
    - `sed -n '1120,1385p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `rg -n "return -ENXIO|fwnode_graph_get_next_endpoint|dev_err_probe|chip ID|xvclk|reset" ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
  - verified the installed module layout:
    - `ls /lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko.zst`
    - `modinfo -F filename ov5675`
  - `apply_patch` adding and updating:
    - `reference/patches/ov5675-probe-diagnostics-v1.patch`
    - `docs/ov5675-diagnostic-patch.md`
    - `docs/module-iteration.md`
    - `docs/README.md`
    - `README.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - confirmed the current `ov5675` driver has two silent early `-ENXIO` exits
    in `ov5675_get_hwcfg()`:
    - no firmware node
    - no firmware graph endpoint
  - drafted `reference/patches/ov5675-probe-diagnostics-v1.patch` to expose
    those failure paths and to log regulator and endpoint-parse errors via
    `dev_err_probe()`
  - documented the exact module-only integration loop in
    `docs/ov5675-diagnostic-patch.md`
  - corrected the earlier install guidance to match the real Arch module
    layout:
    - installed modules are `.ko.zst`
    - the clean replacement path is to overwrite the packaged `.ko.zst`
      filename, then run `depmod`
- Decision: next test should use the new `ov5675` diagnostic patch with a
  module-only rebuild instead of another full kernel compile.
### Record `v1` patched-kernel result and document module-only iteration

- Plan: preserve the first successful boot and validation results from the
  patched `MS-13Q3` board-data kernel, capture the user-run `ov5675` follow-up
  bind attempt, and document a faster module-only iteration path for the next
  patches.
- Commands:
  - reviewed committed and untracked run evidence:
    - `runs/2026-03-08/20260308T065505-snapshot-after-v1-board-data-boot/*`
    - `runs/2026-03-08/20260308T124909-snapshot-after-v1-board-data-boot/*`
  - reviewed the user-provided terminal transcript for:
    - `readlink -f /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo unbound`
    - `sudo modprobe -r ov5675`
    - `sudo modprobe ov5675`
    - `echo i2c-OVTI5675:00 | sudo tee /sys/bus/i2c/drivers/ov5675/bind`
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|tps68470|INT3472|supply|reset|powerdown|clk'`
    - `media-ctl -p -d /dev/media0`
    - `v4l2-ctl --list-devices`
    - `find /dev -maxdepth 1 -name 'v4l-subdev*' | sort`
  - reviewed kernel build layout for faster iteration:
    - `drivers/platform/x86/intel/int3472/Makefile`
    - `drivers/media/i2c/Makefile`
    - `drivers/media/pci/intel/Makefile`
    - `.config` entries for:
      - `CONFIG_INTEL_SKL_INT3472`
      - `CONFIG_VIDEO_OV5675`
      - `CONFIG_IPU_BRIDGE`
      - `CONFIG_GPIO_TPS68470`
      - `CONFIG_REGULATOR_TPS68470`
  - `apply_patch` updating:
    - `WORKLOG.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `docs/webcam-status.md`
    - `docs/linux-board-data-candidate.md`
    - `docs/module-iteration.md`
    - `runs/2026-03-08/20260308T124909-snapshot-after-v1-board-data-boot/manual-followup.txt`
- Result:
  - the first patched kernel booted successfully as `7.0.0-rc2-1-mainline-dirty`
  - the original blocker is gone:
    - `No board-data found for this model` no longer appears
  - the patched kernel moved the failure forward usefully:
    - `i2c-OVTI5675:00` now exists
    - `intel-ipu7 ... no subdev found in graph` still remains
    - the graph still has no sensor entity
    - there are still no `/dev/v4l-subdev*` nodes
  - the user-run follow-up bind attempt failed with:
    - `tee: /sys/bus/i2c/drivers/ov5675/bind: No such device or address`
  - that means the next blocker is now `ov5675` probe / bind, not the original
    missing `tps68470_board_data` match
  - documented the practical faster loop for next edits:
    - `intel_skl_int3472_tps68470`, `ov5675`, `ipu-bridge`, and the relevant
      TPS68470 helper pieces are all modules in the current test kernel
    - next iterations can usually use module-only rebuild/install instead of a
      full `makepkg`
- Decision: keep the `v1` board-data patch as the correct first-stage fix and
  switch to module-only iteration for the next diagnostic `ov5675` / `ipu-bridge`
  work.

### Preserve the reordered manual sensor-check batch and refresh current `linux-mainline` source status

- Plan: commit the reordered manual sensor-check attempt as evidence, distinguish the dry-run from the real execute run, and re-check the current `linux-mainline` package-cache layout before moving to a patched-kernel test.
- Commands:
  - reviewed:
    - `git status --short`
    - `runs/2026-03-08/20260308T021210-manual-i2c-sensor-check/script.log`
    - `runs/2026-03-08/20260308T021300-manual-i2c-sensor-check-second-manual-check/script.log`
    - `runs/2026-03-08/20260308T021300-manual-i2c-sensor-check-second-manual-check/metadata.env`
  - checked current `linux-mainline` package cache:
    - `git -C /home/lhl/.cache/paru/clone/linux-mainline/linux-mainline describe --tags --always`
    - `git -C /home/lhl/.cache/paru/clone/linux-mainline/linux-mainline rev-parse --short HEAD`
    - `find /home/lhl/.cache/paru/clone/linux-mainline -maxdepth 2 -type d | sort`
    - `git --git-dir=/home/lhl/.cache/paru/clone/linux-mainline/linux-mainline show HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c | rg -n 'MS-13Q3|Micro-Star|Prestige|INT3472:06|driver_data =|DMI_'`
    - `git --git-dir=/home/lhl/.cache/paru/clone/linux-mainline/linux-mainline show HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c | tail -n 80`
    - temp check:
      - extracted `tps68470_board_data.c` from the bare cache into a temp tree
      - `git apply --check /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/patches/ms13q3-int3472-tps68470-v1.patch`
  - `apply_patch` updating:
    - `WORKLOG.md`
    - `state/CONTEXT.md`
    - `docs/kernel-tree-status.md`
- Result:
  - `20260308T021210-manual-i2c-sensor-check` is only a dry-run confirmation of the reordered script plan
  - `20260308T021300-manual-i2c-sensor-check-second-manual-check` is the actual second execute run, but it failed on the very first `REVID` read
  - that means the second execute run did **not** exercise the reordered sequence at all; it only preserves evidence that the I2C controller was still wedged from the previous manual PMIC experiment
  - the current `linux-mainline` package cache layout is now:
    - package root: `~/.cache/paru/clone/linux-mainline`
    - bare Git cache: `~/.cache/paru/clone/linux-mainline/linux-mainline`
    - no editable `src/linux-mainline` worktree exists until `makepkg` prepare/build creates it
  - the current cached upstream source is:
    - describe: `v7.0-rc2-467-g4ae12d8bd9a8`
    - commit: `4ae12d8bd9a8`
  - the current cached `tps68470_board_data.c` still only contains Surface Go/2/3 and Dell 7212 entries; it still does **not** contain MSI `MS-13Q3` or `i2c-INT3472:06`
  - the current first-pass patch candidate `reference/patches/ms13q3-int3472-tps68470-v1.patch` still applies cleanly to the current cached `v7.0-rc2` board-data source content
- Decision: preserve this probe batch, but stop using additional manual PMIC pokes as the main path; the next highest-value test is a patched `linux-mainline` build using the current `v7.0-rc2` source worktree.

### Record first executed manual TPS68470 sensor-check run and tighten the sequence

- Plan: review the first live userland PMIC-poke run, preserve the resulting evidence, and adjust the script so the next run tests the sensor immediately after passthrough enable instead of failing on a follow-up PMIC read.
- Commands:
  - reviewed:
    - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/script.log`
    - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/pre-pmic-regs.txt`
    - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/post-reset-regs.txt`
    - `journalctl -k --since '2026-03-08 02:05:30' --until '2026-03-08 02:07:30'`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - `apply_patch` updating:
    - `scripts/i2c-sensor-check.sh`
    - `WORKLOG.md`
- Result:
  - the first executed manual run reached the PMIC cleanly and confirmed the corrected baseline state:
    - `REVID=0x21`
    - `VIOVAL=0x34`
    - `VSIOVAL=0x34`
    - `VACTL=0x00`
    - `VDCTL=0x04`
  - the run stayed healthy through:
    - voltage programming
    - full 19.2 MHz clock programming
    - GPIO1/GPIO2 mode changes
  - the first operation after setting `S_I2C_CTL` to `0x03` failed, and the kernel logged repeated `i2c_designware.1: controller timed out`
  - that means the current script ordering was non-diagnostic:
    - it proved the bus break happened at or immediately after passthrough enable
    - it did **not** prove the sensor failed to answer chip-ID reads
  - the script now makes `S_I2C_CTL` the final PMIC write before direct sensor reads and makes post-passthrough PMIC snapshots / cleanup best-effort instead of fatal
- Decision: keep the first executed run as evidence; use the reordered script for the next manual check if we want one more high-risk sanity test.

### Harden manual TPS68470 sensor-check experiment script

- Plan: keep the manual PMIC poke path available as an explicit experiment, but make it less misleading by matching the kernel clock path more closely, removing non-diagnostic `i2cdetect` scans, and defaulting to dry-run.
- Commands:
  - reviewed:
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/clk/clk-tps68470.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `docs/reprobe-harness.md`
  - `apply_patch` rewriting:
    - `scripts/i2c-sensor-check.sh`
  - validated:
    - `bash -n scripts/i2c-sensor-check.sh`
    - `scripts/i2c-sensor-check.sh` (dry-run only)
- Result:
  - the manual script now programs the full 19.2 MHz TPS68470 clock sequence instead of only toggling `PLLCTL`
  - it explicitly writes `VIOVAL`, `VSIOVAL`, `VAVAL`, and `VDVAL`, so it no longer depends on inherited PMIC state from a previous boot or run
  - it now uses read-modify-write updates for GPIO and regulator enable registers instead of clobbering whole register values
  - it removed `i2cdetect` bus scans and uses direct chip-ID reads only, which makes a negative result less misleading
  - it defaults to dry-run and requires `--execute` for actual writes
  - it logs each run under `runs/YYYY-MM-DD/...`
  - no live hardware execution was performed as part of this edit; only dry-run validation was done
- Decision: keep; this is still a higher-risk experiment than the safe reprobe harness, but it is now a more controlled sanity-check path and a failed result should be easier to interpret.

### Draft first Linux `MS-13Q3` `tps68470_board_data` patch candidate

- Plan: turn the ACPI plus Windows sequencing evidence into a concrete first-pass Linux patch candidate and a test note that is specific enough for the first patched reprobe.
- Commands:
  - reviewed Linux consumer expectations:
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/include/linux/platform_data/tps68470.h`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
  - generated a patch candidate from a modified temp copy of:
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - wrote:
    - `reference/patches/ms13q3-int3472-tps68470-v1.patch`
    - `docs/linux-board-data-candidate.md`
  - validated:
    - `git apply --check /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/patches/ms13q3-int3472-tps68470-v1.patch`
- Result:
  - drafted the first testable Linux patch candidate for this laptop
  - mapped regulators for `i2c-OVTI5675:00` as:
    - `avdd` via `TPS68470_ANA`
    - `dvdd` via `TPS68470_CORE`
    - `dovdd` via `TPS68470_VSIO`
  - mapped the active PMIC device as `i2c-INT3472:06`
  - used PMIC regular GPIO 1 / GPIO 2 as the initial camera-control candidate because the Windows path reconfigures `GPCTL1A` and `GPCTL2A`
  - recorded the main remaining risk explicitly:
    - upstream `ov5675.c` only consumes `reset`
    - Windows appears to use two PMIC GPIO lines
    - board-data alone may not be sufficient for a full bring-up
- Decision: keep; this is the minimum concrete patch path that can falsify or confirm the current MSI board-data hypothesis quickly.

### Deepen `iactrllogic64.sys` extraction for `VoltageWF` and sensor-power sequencing

- Plan: promote the recovered Windows `VoltageWF` and `CrdG2TiSensor` power-path behavior into first-class repo artifacts so the Linux patch-design step can rely on durable evidence instead of transient terminal analysis.
- Commands:
  - reviewed and extended `scripts/extract-iactrllogic64.sh`
  - inspected targeted disassembly around:
    - `0x140011ae0` through `0x140011ff4`
    - `0x140012c90` through `0x14001357c`
    - `0x1400146a8` through `0x140014b60`
  - correlated those regions against:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-addresses.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-xrefs.txt`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/include/linux/mfd/tps68470.h`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
  - `apply_patch` adding:
    - new extractor outputs for `VoltageWF::PowerOn/PowerOff`, `IoActive/IoIdle`, and `CrdG2TiSensor::*`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
- Result:
  - confirmed `Tps68470VoltageWF::PowerOn` is an orchestration path, not a single register write:
    - it stages VA, VD, VSIO, and VCM helper calls and logs steps `0x20` through `0x24`
  - confirmed `Tps68470VoltageWF::PowerOff` tears down VA, VD, and VCM explicitly, while `VSIO` is handled through a separate IO-state path
  - confirmed `Tps68470VoltageWF::IoActive` / `IoIdle` use a refcount around `S_I2C_CTL` `0x43`
  - confirmed `Tps68470VoltageWF::IoActive_GPIO` reconfigures `GPCTL1A` `0x16` and `GPCTL2A` `0x18`
  - narrowed the Linux GPIO hypothesis:
    - this MSI path likely uses PMIC regular GPIO 1 and GPIO 2
    - this does not look like the Surface Go style use of logical outputs `s_enable` / `s_resetn`
- Decision: keep; this is the first durable extraction step that materially constrains the Linux board-data design.

### Complete first ACPI capture with committed DSL and live Linux state

- Plan: finish the first ACPI evidence set so the repo contains the actual disassembly outputs and live ACPI/sysfs snapshot, then fix the capture script so future runs reproduce the same layout without manual cleanup.
- Commands:
  - regenerated DSL from the existing capture in temp:
    - copied `reference/acpi/20260308T004459-unknown-host/tables/*.dat` to `/tmp/ms13q3-acpi-commit/`
    - `iasl -d dsdt.dat`
    - `iasl -d ssdt*.dat`
  - refreshed committed analysis files:
    - regenerated `reference/acpi/20260308T004459-unknown-host/camera-related-hits.txt`
    - generated `reference/acpi/20260308T004459-unknown-host/live-linux-acpi-state.txt`
    - removed accidental duplicate `reference/acpi/20260308T004459-unknown-host/tables/*.dsl`
  - `apply_patch` updating:
    - `scripts/capture-acpi.sh`
    - `reference/acpi/20260308T004459-unknown-host/README.md`
    - `docs/tps68470-reverse-engineering.md`
    - `state/CONTEXT.md`
- Result:
  - committed the first full reviewed ACPI evidence set for this laptop, including `dsdt.dsl`, `ssdt*.dsl`, valid `camera-related-hits.txt`, and `live-linux-acpi-state.txt`
  - confirmed the live Linux snapshot matches the reviewed firmware path:
    - `OVTI5675:00` at `\_SB_.LNK0`
    - `INT3472:06` at `\_SB_.CLP0`
    - inactive alternate `INT3472:00` at `\_SB_.DSC0`
  - confirmed `dsdt.dsl` disassembles cleanly only as a standalone `iasl -d dsdt.dat` pass on this firmware; the combined namespace mode fails with `AE_ALREADY_EXISTS`
  - fixed `scripts/capture-acpi.sh` so future runs:
    - disassemble lowercase `dsdt.dat` / `ssdt*.dat`
    - keep `.dsl` outputs under `dsl/` instead of scattering them under `tables/`
    - capture `live-linux-acpi-state.txt` automatically
- Decision: keep; this turns the ACPI capture into a self-contained, reproducible reference instead of a partially reviewed raw dump.

### Review first ACPI capture and correlate it with live Linux plus Windows artifacts

- Plan: disassemble the captured ACPI tables from a writable temp area, identify the machine's active camera path, map that to the live ACPI/sysfs state, and fix the capture script based on the first-run failure.
- Commands:
  - regenerated DSL from the committed capture in temp:
    - copied `reference/acpi/20260308T004459-unknown-host/tables/*.dat` to `/tmp/ms13q3-acpi-review/`
    - `iasl -e ssdt*.dat -d dsdt.dat`
    - `iasl -d ssdt*.dat`
  - reviewed ACPI structure:
    - `/tmp/ms13q3-acpi-review/ssdt17.dsl`
    - `/tmp/ms13q3-acpi-review/dsdt-disasm.log`
    - `/tmp/ms13q3-acpi-review/ssdt-disasm.log`
  - reviewed live ACPI/sysfs state:
    - `/sys/bus/acpi/devices/OVTI5675:00/*`
    - `/sys/bus/acpi/devices/INT3472:06/*`
    - `/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-INT3472:06/*`
  - reviewed Linux-side consumers and PMIC register definitions:
    - `drivers/media/i2c/ov5675.c`
    - `drivers/platform/x86/intel/int3472/tps68470.c`
    - `drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `drivers/clk/clk-tps68470.c`
    - `drivers/regulator/tps68470-regulator.c`
    - `include/linux/mfd/tps68470.h`
  - `apply_patch` fixing `scripts/capture-acpi.sh` and updating the canonical note and state files
- Result:
  - confirmed the camera topology lives in `ssdt17.dat` / `MiCaTabl`, which defines six `LNK*` sensor links, six `DSC*` `INT3472` PMIC nodes, and six `CLP*` `INT3472` PMIC nodes backed by an `MNVS` operation region
  - confirmed the live active sensor is `OVTI5675:00` at ACPI path `\_SB_.LNK0` with `status=15`
  - confirmed the live active PMIC companion is `INT3472:06` at ACPI path `\_SB_.CLP0` with `status=15`, and its physical Linux device is `i2c-INT3472:06`
  - confirmed the alternate `DSC0` `INT3472:00` path exists but is inactive on this machine
  - confirmed `CDEP()` in the ACPI table selects `DSC0 + I2C bus` only when `C0TP == 1`, but returns `CLP0` when `C0TP > 1`; this laptop is therefore on the Windows PMIC companion path, not the simpler discrete path
  - confirmed the Windows `StartClock` register sequence maps directly to Linux TPS68470 clock registers:
    - `0x06` `POSTDIV2`
    - `0x07` `BOOSTDIV`
    - `0x08` `BUCKDIV`
    - `0x09` `PLLSWR`
    - `0x0A` `XTALDIV`
    - `0x0B` `PLLDIV`
    - `0x0C` `POSTDIV`
    - `0x0D` `PLLCTL`
    - `0x10` `CLKCFG2`
  - confirmed `ov5675` expects regulators `avdd`, `dovdd`, and `dvdd`, plus a `reset` GPIO and a 19.2 MHz clock
  - confirmed the likely blocker is now narrower:
    - missing MSI-specific `tps68470_board_data` for `i2c-INT3472:06`
    - likely with `OVTI5675:00`-specific regulator consumer mappings and GPIO policy
    - not just a missing DMI string
  - fixed `scripts/capture-acpi.sh` so future runs disassemble lowercase `dsdt.dat` and `ssdt*.dat` files correctly
- Decision: keep; this is the first machine-specific ACPI-to-Linux path confirmation and it narrows the next patch-design work to MSI `TPS68470` board data and PMIC policy.

### Commit first ACPI capture for MSI `MS-13Q3`

- Plan: commit the first real root-collected ACPI capture from this laptop before deeper analysis, and record both the successful raw dump and the script failure that left the DSL pass incomplete.
- Commands:
  - `sudo scripts/capture-acpi.sh`
  - reviewed:
    - `reference/acpi/20260308T004459-unknown-host/metadata.env`
    - `reference/acpi/20260308T004459-unknown-host/dmi.txt`
    - `reference/acpi/20260308T004459-unknown-host/acpidump.txt`
    - `reference/acpi/20260308T004459-unknown-host/acpixtract.log`
    - `reference/acpi/20260308T004459-unknown-host/dsl/ssdt-disasm.log`
- Result:
  - captured the first in-repo raw ACPI dump for this exact machine under `reference/acpi/20260308T004459-unknown-host/`
  - confirmed DMI identity from the same capture:
    - product: `Prestige 13 AI+ Evo A2VMG`
    - board: `MS-13Q3`
    - BIOS: `E13Q3IMS.109`
    - BIOS date: `09/04/2024`
  - confirmed the raw dump contains camera-relevant `INT3472` and `CLDB` strings
  - confirmed binary ACPI tables were extracted successfully under `tables/`
  - confirmed the first `iasl` disassembly attempt failed because `scripts/capture-acpi.sh` expected uppercase `DSDT.dat` and `SSDT*.dat` while this run produced lowercase `dsdt.dat` and `ssdt*.dat`
  - confirmed `camera-related-hits.txt` is empty in this first run because the DSL generation step failed
- Decision: keep; the raw capture is valid and should be preserved now, then analyzed and followed by a script fix in a separate step.

### Add canonical ACPI plus Windows-control-logic reverse-engineering workflow

- Plan: make the ACPI capture and Windows `iactrllogic64.sys` analysis reproducible in-repo, then write one canonical note that preserves the concrete reverse-engineering results.
- Commands:
  - checked current constraints:
    - `which acpidump`
    - `sudo -n true`
    - `ls -l /sys/firmware/acpi/tables`
    - `acpidump -b`
  - added scripts:
    - `scripts/capture-acpi.sh`
    - `scripts/extract-iactrllogic64.sh`
  - generated Windows analysis artifacts:
    - `scripts/extract-iactrllogic64.sh`
  - reviewed generated outputs:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/debug-directory.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/pe-header-and-imports.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-addresses.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoron.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoroff.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-start.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-confighclkab.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvactl.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvsioctl-gpio.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-register-write-wrapper.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-transport-helper.txt`
- Result:
  - added a root-capable ACPI capture helper that stores reproducible evidence under `reference/acpi/`
  - confirmed raw ACPI table capture is still blocked from the current unprivileged session because `/sys/firmware/acpi/tables/*` is root-readable only
  - generated a stable in-repo analysis tree for `iactrllogic64.sys`
  - confirmed the Windows driver contains named `TPS68470` sensor, clock, voltage, GPIO, and flash routines plus `CommonFunc::Cmd_SensorPowerOn` / `Cmd_SensorPowerOff`
  - confirmed the binary build provenance:
    - PDB path `W:\repo\w\camerasw\Source\Camera\Platform\LNL\x64\Release\iactrllogic64.pdb`
    - PDB GUID `804BA0D7-738B-4CC9-8027-7AF3103C24B5`
  - recovered a concrete `Tps68470Clock::StartClock` write sequence using registers `0x0a`, `0x08`, `0x07`, `0x0b`, `0x0c`, `0x06`, `0x10`, `0x09`, and `0x0d`
  - recovered a `ConfigHCLKAB` helper that reads and masks register `0x0d` before writing it back
  - recovered a common register-write helper at `0x140010be0` that retries through `0x1400110f4`
  - recovered `VoltageWF` examples that read/modify/write at least registers `0x47` and `0x43`
- Decision: keep; this is now the canonical reverse-engineering base for the next ACPI capture and Linux patch-design pass.

### Commit first baseline snapshot and reprobe run set

- Plan: record the first real `runs/` output from the safe harness so the baseline failure state and exact reprobe behavior are preserved in git.
- Commands:
  - `scripts/webcam-run.sh snapshot --label baseline --note "before first reprobe"`
  - `sudo scripts/webcam-run.sh reprobe-modules --label first-reprobe --note "baseline reprobe after boot"`
  - reviewed:
    - `runs/2026-03-08/20260308T001800-snapshot-baseline/summary.env`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/summary.env`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/action.log`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/journal-since-run-start.txt`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/media-ctl-media0.txt`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/v4l2-list-devices.txt`
- Result:
  - captured the first baseline snapshot and first real reprobe run under `runs/2026-03-08/`
  - confirmed the reprobe sequence completed successfully with no module-load failures
  - confirmed the same blocker reproduces cleanly after reprobe:
    - `TPS68470 REVID: 0x21`
    - `error -ENODEV: No board-data found for this model`
    - `intel-ipu7 ... no subdev found in graph`
  - confirmed `media-ctl` still shows an IPU-only topology with no sensor subdevice attached after reprobe
- Decision: keep; this is the baseline evidence batch for future diffs against patched kernels or new sequencing hypotheses.

### Add related MSI Summit 13 low-level Linux repo as a future comparison reference

- Plan: capture a nearby MSI Lunar Lake Linux-support repo that is not webcam-specific but may still hold useful board-level patterns for later comparison.
- Commands:
  - opened `https://github.com/greymouser/Summit-13-AI-Evo-A2VM`
  - `apply_patch` adding `reference/greymouser-summit-13-ai-evo-a2vm.md`
  - `apply_patch` updating `reference/README.md`, `README.md`, and `state/CONTEXT.md`
- Result:
  - added a reference note for the related `MSI Summit 13 AI+ Evo A2VMTG` / `MS-13P5` repo
  - captured that its visible Linux focus is currently IIO sensor support and audio mute / speaker LED control
  - recorded it as a future low-level comparison source rather than a direct webcam bring-up reference
- Decision: keep; related MSI platform work may expose useful DMI, ACPI, firmware, or vendor-integration patterns later.

### Build safe snapshot/reprobe harness for repeatable Linux testing

- Plan: add a low-risk harness that records every meaningful reprobe attempt with enough evidence to analyze failures later, without doing raw PMIC or I2C register writes.
- Commands:
  - inspected current repo docs and plan files
  - inspected current sysfs driver hooks for `int3472-tps68470` and `ov5675`
  - inspected current module state and kernel logs
  - `apply_patch` adding `scripts/webcam-run.sh`
  - `apply_patch` adding `docs/reprobe-harness.md`
  - `apply_patch` adding `runs/README.md`
  - `apply_patch` updating `README.md`, `docs/README.md`, `PLAN.md`, and `state/CONTEXT.md`
  - `bash -n scripts/webcam-run.sh`
  - `scripts/webcam-run.sh snapshot --runs-root /tmp/...`
  - `scripts/webcam-run.sh reprobe-modules --dry-run --runs-root /tmp/...`
- Result:
  - added `scripts/webcam-run.sh` with two actions: `snapshot` and `reprobe-modules`
  - each run now captures pre/post state, exact step order, filtered kernel logs, media/V4L2 output, and relevant sysfs state under `runs/`
  - the harness is explicitly limited to snapshot and module reload activity; it does not do `i2cset`, raw `i2ctransfer` writes, or address-scanning `i2cdetect`
  - documented the run layout and usage in `docs/reprobe-harness.md`
  - smoke-tested `snapshot` and `reprobe-modules --dry-run` successfully using temporary run roots under `/tmp`
- Decision: keep; this gives us a repeatable low-risk testing baseline before any deeper reverse engineering or kernel patching.

## 2026-03-07

### Snapshot Torvalds `HEAD` `int3472` subtree for upstream comparison

- Plan: capture the current upstream `drivers/platform/x86/intel/int3472/` tree from Torvalds Linux `HEAD` and compare it against the local `v6.19` snapshot.
- Commands:
  - opened `https://web.git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/platform/x86/intel/int3472`
  - opened `https://github.com/torvalds/linux/tree/master/drivers/platform/x86/intel/int3472`
  - `git ls-remote https://github.com/torvalds/linux.git HEAD`
  - sparse-cloned Torvalds Linux `HEAD` and copied `drivers/platform/x86/intel/int3472/`
  - `git diff --no-index --stat -- reference/linux-mainline-v6.19/drivers/platform/x86/intel/int3472 reference/linux-torvalds-head/drivers/platform/x86/intel/int3472`
- Result:
  - captured Torvalds `HEAD` at `4ae12d8bd9a830799db335ee661d6cbc6597f838`
  - added an in-repo upstream snapshot under `reference/linux-torvalds-head/`
  - confirmed that only `discrete.c` and `tps68470.c` differ from the local `v6.19` snapshot
  - did not observe a new MSI board-data entry in `tps68470_board_data.c`
- Decision: keep; this narrows the current upstream delta and confirms that plain upstream drift has not already fixed the MSI board-data gap.

### Vendor Windows package trees, TPS68470 PDF, and local `int3472` kernel snapshot

- Plan: move the active binary artifacts and local source snapshot into `reference/` so future reverse engineering does not depend on `/tmp` or the paru cache path.
- Commands:
  - `git lfs track 'reference/windows-driver-packages/**/*.cab' 'reference/windows-driver-packages/**/*.sys' 'reference/windows-driver-packages/**/*.dll' 'reference/windows-driver-packages/**/*.bin' 'reference/windows-driver-packages/**/*.aiqb' 'reference/windows-driver-packages/**/*.cpf' 'reference/windows-driver-packages/**/*.cat' 'reference/windows-driver-packages/**/*.bmp'`
  - copied `/tmp/int3472-winpkg/intel-control-logic-71.26100.23.20279.cab`
  - copied `/tmp/int3472-winpkg/extracted`
  - copied `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
  - copied `/tmp/ovti5675-msi/extracted2`
  - `git lfs track 'reference/**/*.pdf'`
  - copied `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/`
- Result:
  - vendored the two Windows package trees into `reference/windows-driver-packages/`
  - enabled Git LFS for the binary-heavy Windows-package payloads and for PDFs under `reference/`
  - added a local reference copy of `drivers/platform/x86/intel/int3472/` from the inspected `v6.19` tree
  - added `reference/tps68470.pdf` to the repo as a local PMIC datasheet reference
- Decision: keep; this lowers future setup cost and gives us stable in-repo inputs for both Windows-package and kernel-source analysis.

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

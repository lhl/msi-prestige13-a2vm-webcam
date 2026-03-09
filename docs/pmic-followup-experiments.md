# PMIC Follow-Up Experiment Workflow

Updated: 2026-03-09

This note turns the current ordered PMIC follow-up list into repeatable
update-and-verify workflows.

As of the completed `2026-03-09` PMIC batch:

- `exp1` through `exp9` are completed historical experiments
- the highest-value next kernel-side follow-up is `exp10`
- `exp7` established that `VSIO` enable on `S_I2C_CTL` `0x43` is the first
  PMIC transaction after which readback collapses to `-110`
- `exp8` confirmed the same failure point with a narrower trace:
  - `ANA` enable still succeeds
  - `CORE` enable still succeeds
  - the combined `VSIO` enable on `0x43` still returns success but immediate
    readback fails with `-110`
- `exp9` answered the split-step question:
  - IO-side `BIT(1)` writes and reads back cleanly as `0x02`
  - the wedge begins only after the later GPIO-side `BIT(0)` update
- `exp10` now tests the obvious next behavior:
  - keep `BIT(1)` in the regulator path
  - do not assert `BIT(0)` there

## Goal

Make each PMIC experiment runnable with the same high-safety pattern:

1. apply the current baseline patch stack with `scripts/patch-kernel.sh`
2. apply one experiment patch
3. rebuild only the required module subtrees
4. install the resulting `.ko.zst` files into `/usr/lib/modules/<release>/...`
5. run `depmod`
6. reboot once
7. run a clean-boot verification wrapper that reuses `scripts/01-clean-boot-check.sh`
   and adds an experiment-specific journal grep plus a root PMIC dump

## Important guardrails

- The update wrappers are meant to be run from this repo checkout.
- They default to the current local `linux-mainline` tree:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
- They default their temporary build/status files to a repo-local temp
  directory:
  - `.tmp/`
  - override by exporting `TMPDIR` before running a wrapper if needed
- They default to the repo's current best baseline profile:
  - `candidate`
- They require the experiment patch file to exist.
  - If the default patch file has not been created yet, the wrapper stops with a
    clear error and tells you to create it or pass `--patch FILE`.
- The current default experiment patch files now exist under:
  - `reference/patches/`
- They compare the kernel tree's `make kernelrelease` value against `uname -r`
  by default.
  - This is intentional. It reduces the chance of installing modules into the
    wrong release.
  - Override only if you mean it:
    - `--module-release <release>`
- They do not force an immediate reboot without confirmation unless you pass
  `--yes`.
- They now support `--dry-run`.
  - This validates arguments, patch-path resolution, and kernel-release
    selection, then prints the actions without patching, building, installing
    modules, running `depmod`, rebooting, or executing the verify-side capture.
- They write an update log under `runs/<date>/...-update/` before reboot.
- They now reset the known experiment-touched source files back to kernel
  `HEAD` before reapplying the baseline profile and the selected experiment
  patch.
  - This is intentionally stronger than trying to reverse the old experiment
    patch in place.
  - It keeps `exp2` from accidentally becoming `exp1 + exp2`, and it is more
    robust when an experiment patch is revised between runs.
  - Use `--keep-experiment-patches` only if you intentionally want cumulative
    patching.

## Shared behavior

All experiment `*-update.sh` wrappers do this:

- log the intended kernel tree, baseline profile, patch path, build dirs, and
  module install targets
- attempt `scripts/patch-kernel.sh --status` for visibility
  - if status cannot be captured (for example temp-directory space/quota
    pressure while creating the temporary status tree), the wrapper logs a warning and
    continues with baseline apply
- apply the selected baseline profile
- apply the experiment patch if it is not already present
- rebuild the baseline module set:
  - `intel_skl_int3472_tps68470.ko`
  - `ipu-bridge.ko`
  - `ov5675.ko`
- rebuild and install any extra modules required by the experiment
- run `sudo depmod -a <release>`
- prompt for reboot

All experiment `*-verify.sh` wrappers do this after reboot:

- run `scripts/01-clean-boot-check.sh`
- append an experiment-specific journal extract to the run directory
- run `sudo scripts/pmic-reg-dump.sh` and save the output into the same run
  directory
- capture `modinfo` for the baseline plus experiment-specific modules
- normalize the run-directory ownership back to the invoking user if any
  root-assisted step left files owned by `root`

## Experiment order

### 1. PMIC path instrumentation

Purpose:
- prove whether the expected PMIC clock/regulator path actually fires on the
  failing clean boot

Default patch:
- `reference/patches/pmic-path-instrumentation-v1.patch`

Extra module rebuild/install:
- `videodev.ko`
- `clk-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp1-pmic-instrumentation-update.sh`
- `scripts/exp1-pmic-instrumentation-verify.sh`

### 2. `WF` `S_I2C_CTL` staging

Purpose:
- test the strongest direct Windows-vs-Linux delta around register `0x43`

Default patch:
- `reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch`

Extra module rebuild/install:
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp2-wf-s-i2c-ctl-update.sh`
- `scripts/exp2-wf-s-i2c-ctl-verify.sh`

### 3. `MS-13Q3` `VD` to `1050 mV`

Purpose:
- test the one clear recovered voltage mismatch between Windows and Linux

Default patch:
- `reference/patches/ms13q3-vd-1050mv-v1.patch`

Extra module rebuild/install:
- `intel_skl_int3472_tps68470.ko`

Scripts:
- `scripts/exp3-ms13q3-vd-1050mv-update.sh`
- `scripts/exp3-ms13q3-vd-1050mv-verify.sh`

### 4. `WF::Initialize`-style value programming

Purpose:
- test whether Linux needs an explicit board-specific equivalent of the Windows
  `WF` initialize write sequence before sensor power-on

Default patch:
- `reference/patches/ms13q3-wf-init-value-programming-v1.patch`

Extra module rebuild/install:
- `intel_skl_int3472_tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp4-wf-init-value-programming-update.sh`
- `scripts/exp4-wf-init-value-programming-verify.sh`

### 5. `WF` GPIO mode follow-up

Purpose:
- revisit PMIC GPIO mode semantics only after the higher-signal PMIC rail and
  pass-through experiments above

Default patch:
- `reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`

Scripts:
- `scripts/exp5-wf-gpio-mode-followup-update.sh`
- `scripts/exp5-wf-gpio-mode-followup-verify.sh`

### 6. `UF` `gpio.4` last resort

Purpose:
- preserve a controlled path for the lowest-priority `UF` / `gpio.4` hypothesis
  without pretending it is the current best branch

Default patch:
- `reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch`

Extra module rebuild/install:
- `intel_skl_int3472_tps68470.ko`
- `gpio-tps68470.ko`

Scripts:
- `scripts/exp6-uf-gpio4-last-resort-update.sh`
- `scripts/exp6-uf-gpio4-last-resort-verify.sh`

### 7. Raw PMIC regmap trace

Purpose:
- capture raw PMIC register operations inside the Linux clock and regulator
  paths during the failing clean boot
- record:
  - register
  - mask / value
  - regmap return code
  - immediate readback

Default patch:
- `reference/patches/pmic-raw-regmap-trace-v1.patch`

Extra module rebuild/install:
- `clk-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp7-pmic-raw-regmap-trace-update.sh`
- `scripts/exp7-pmic-raw-regmap-trace-verify.sh`

Observed outcome:
- informative, but too broad for routine reruns
- healthy PMIC access persisted through:
  - clock setup
  - `ANA` enable
  - `CORE` enable
- the first bad PMIC transaction was:
  - `VSIO` enable on `S_I2C_CTL` `0x43`
- after that point:
  - immediate readback failed with `-110`
  - `i2c_designware.1` entered a timeout storm
  - later PMIC accesses also failed with `-110`

### 8. Focused `S_I2C_CTL` trace

Purpose:
- keep the high-value `exp7` signal around `S_I2C_CTL` `0x43`
- log only the minimum PMIC transitions needed to confirm the failure point:
  - `ANA` enable
  - `CORE` enable
  - `VSIO` enable / disable on `S_I2C_CTL`
- avoid broad PMIC snapshotting once the bus starts timing out

Default patch:
- `reference/patches/pmic-si2c-ctl-focused-trace-v1.patch`

Extra module rebuild/install:
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp8-s-i2c-ctl-focused-trace-update.sh`
- `scripts/exp8-s-i2c-ctl-focused-trace-verify.sh`

Observed outcome:
- confirmed `exp7` with a narrower trace
- `ANA` and `CORE` enable still read back cleanly
- `VSIO` enable on `0x43` still reports:
  - `update_ret=0`
  - immediate `after_ret=-110`
- the timeout storm was smaller than `exp7`, but still large enough to add
  about a minute of boot delay on the observed run

### 9. Split-step `S_I2C_CTL` trace

Purpose:
- keep the narrower `exp8` scope
- split the `VSIO` enable path into:
  - IO-side `BIT(1)` update with immediate readback
  - GPIO-side `BIT(0)` update with immediate readback
- determine which substep actually wedges PMIC access

Default patch:
- `reference/patches/pmic-si2c-ctl-split-step-trace-v1.patch`

Extra module rebuild/install:
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp9-s-i2c-ctl-split-step-trace-update.sh`
- `scripts/exp9-s-i2c-ctl-split-step-trace-verify.sh`

Observed outcome:
- `BIT(1)` is clean:
  - `before=0x00`
  - `after=0x02`
  - `after_ret=0`
- the wedge begins on `BIT(0)`:
  - `before=0x02`
  - `update_ret=0`
  - `after_ret=-110`
- this run failed earlier than the older identify-timeout path:
  - `ov5675 ... failed to power on: -110`

### 10. `BIT(1)`-only `S_I2C_CTL`

Purpose:
- keep only the IO-side `BIT(1)` behavior in the regulator `VSIO` enable path
- do not assert `BIT(0)` there
- test whether the bus stays alive long enough to reach sensor identify again

Default patch:
- `reference/patches/pmic-si2c-ctl-bit1-only-v1.patch`

Extra module rebuild/install:
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp10-s-i2c-ctl-bit1-only-update.sh`
- `scripts/exp10-s-i2c-ctl-bit1-only-verify.sh`

## Typical usage

Update, install modules, and reboot for experiment 2:

```bash
scripts/exp2-wf-s-i2c-ctl-update.sh
```

The script will stop if the default patch file does not exist yet. To test a
patch from a different path:

```bash
scripts/exp2-wf-s-i2c-ctl-update.sh \
  --patch /path/to/ms13q3-wf-s-i2c-ctl-staging-v1.patch
```

Skip the reboot prompt while still doing the patch/build/install work:

```bash
scripts/exp2-wf-s-i2c-ctl-update.sh --no-reboot
```

Preview the full update flow without touching the kernel tree or installed
modules:

```bash
scripts/exp2-wf-s-i2c-ctl-update.sh \
  --patch /path/to/ms13q3-wf-s-i2c-ctl-staging-v1.patch \
  --dry-run
```

After reboot into the same kernel release, run the matching verify wrapper:

```bash
scripts/exp2-wf-s-i2c-ctl-verify.sh
```

Preview the clean-boot verification steps without running them:

```bash
scripts/exp2-wf-s-i2c-ctl-verify.sh --dry-run
```

Current highest-priority run:

```bash
scripts/exp10-s-i2c-ctl-bit1-only-update.sh
```

After reboot:

```bash
scripts/exp10-s-i2c-ctl-bit1-only-verify.sh
```

## Why the verify wrappers always do a PMIC dump

The clean-boot journal remains the primary truth source, but the PMIC dump is a
useful secondary check for all PMIC-side follow-ups because it captures:

- value-register state
- `S_I2C_CTL`
- clock registers
- GPIO control/data registers

The dump happens after the clean-boot checkpoint, not before it, so it does not
replace the boot log and it does not make claims it cannot support.

## Current interpretation

Use these wrappers in the same order as the current technical ranking:

1. instrumentation
2. `S_I2C_CTL` staging
3. `VD=1050 mV`
4. `WF::Initialize` value programming
5. `WF` GPIO mode follow-up
6. `UF` `gpio.4` last resort
7. broad raw PMIC regmap trace
8. focused `S_I2C_CTL` trace

That ordering still matches the current source-backed assessment in:

- `docs/webcam-status.md`
- `docs/wf-vs-uf-gpio-analysis.md`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`

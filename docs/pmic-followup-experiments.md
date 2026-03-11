# PMIC Follow-Up Experiment Workflow

Updated: 2026-03-11

This note turns the current ordered PMIC follow-up list into repeatable
update-and-verify workflows.

As of the completed `2026-03-11` `exp12` follow-up and the staged
`exp13`-`exp17` branch set:

- `exp1` through `exp12` are completed historical experiments
- `exp13` through `exp17` are now staged repo-local experiments:
  - patch files exist under `reference/patches/`
  - matching `update` / `verify` wrappers exist under `scripts/`
  - none of those five staged branches has been run yet
- `exp10` remains the best current PMIC state
- `exp11` was the first late-phase `BIT(0)` experiment and came back negative
- `exp12` was the first Antti-inspired daisy-chain cross-check and came back
  negative as a fix:
  - the daisy-chain input-mode setup landed
  - Linux immediately re-drove `GPIO1` / `GPIO2` back to output mode
  - the sensor failure shape stayed at `-121`
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
- `exp10` is still the best verified PMIC state:
  - keep `BIT(1)` in the regulator path
  - do not assert `BIT(0)` there
- `exp12` answered the first low-effort daisy-chain question:
  - yes, Antti-style daisy-chain mode can be enabled on `GPIO1` / `GPIO2`
  - but the current `MS-13Q3` sensor lookup immediately collides with it

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
- The current default experiment patch files for implemented wrappers exist
  under:
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
- `tps68470-regulator.ko`
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

Observed outcome:
- `ANA` enables cleanly:
  - `before=0x00`
  - `after=0x01`
- `CORE` enables cleanly:
  - `before=0x04`
  - `after=0x05`
- `VSIO BIT(1)` enables and disables cleanly:
  - enable `before=0x00` -> `after=0x02`
  - disable `before=0x02` -> `after=0x00`
- the old PMIC timeout storm is gone
- the sensor gets back to chip-ID reads, but all five now fail with `-121`
  instead of `-110`

Interpretation:
- removing early `BIT(0)` is a real improvement, not a clean negative
- the PMIC/I2C path now stays alive through the sensor identify window
- the remaining question is what later wake-up behavior is still missing:
  - a later `BIT(0)` phase
  - or some separate reset / powerdown sequencing detail

### 11. Later GPIO-phase `BIT(0)`

Purpose:
- keep `exp10`'s `BIT(1)`-only regulator path
- assert `BIT(0)` later, when the sensor-control GPIOs actually transition into
  their active low state
- test whether this later PMIC GPIO-active phase is where the board really
  wants `SetVSIOCtl_GPIO`

Default patch:
- `reference/patches/pmic-si2c-ctl-late-gpio-bit0-v1.patch`

Extra module rebuild/install:
- `tps68470-regulator.ko`
- `gpio-tps68470.ko`

Scripts:
- `scripts/exp11-s-i2c-ctl-late-gpio-bit0-update.sh`
- `scripts/exp11-s-i2c-ctl-late-gpio-bit0-verify.sh`

Observed outcome:
- `ANA`, `CORE`, and regulator-side `VSIO BIT(1)` still read back cleanly
- chip-ID behavior stays at `-121`
- when the late GPIO hook fires, PMIC access wedges again:
  - `pmic_gpio: sensor-gpio.1 value=0 ... before=0x02 update_ret=0 after_ret=-110`
- the old `i2c_designware.1: controller timed out` storm returns

Interpretation:
- this specific later GPIO-phase `BIT(0)` hook is negative
- `exp10` remains the best clean-boot PMIC state
- the remaining question is more specific now:
  - why did the observed hook only fire on `sensor-gpio.1`
  - and what is the real Windows analogue of `SetVSIOCtl_GPIO`

### 12. Antti-inspired daisy-chain cross-check

Purpose:
- try the lowest-effort local version of Antti Laakso's Prestige 14
  daisy-chain idea without pretending that the full Prestige 14 board-data
  model must match this `MS-13Q3`
- enable `tps68470` daisy-chain mode on PMIC `GPIO1` / `GPIO2`
- keep the current `MS-13Q3` `reset` / `powerdown` lookup on those pins so
  the logs can show whether Linux later re-drives them out of input mode

Default patch:
- `reference/patches/ms13q3-daisy-chain-crosscheck-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`

Scripts:
- `scripts/exp12-ms13q3-daisy-chain-crosscheck-update.sh`
- `scripts/exp12-ms13q3-daisy-chain-crosscheck-verify.sh`

Observed outcome:
- the Antti-inspired input-mode setup really landed:
  - `probe-after gpio.1 ... ctl=0x00`
  - `probe-after gpio.2 ... ctl=0x00`
- Linux then immediately reclaimed both lines as outputs:
  - `direction-output-after gpio.1 ... ctl=0x02`
  - `direction-output-after gpio.2 ... ctl=0x02`
- the clean-boot sensor failure shape stayed at:
  - `chip id read attempt 1/5 failed: -121`
  - `...`
  - `failed to find sensor: -121`
- the old timeout storm did not return on this run

Interpretation:
- the low-effort daisy-chain cross-check is negative as a direct fix
- it is still useful because it proves the current `MS-13Q3` `GPIO1` /
  `GPIO2` lookup model and the Antti daisy-chain model are immediately
  competing with each other
- if a stronger daisy-chain branch is ever attempted, it should stop treating
  `GPIO1` / `GPIO2` as the direct sensor-control outputs rather than merely
  enabling daisy-chain mode on top of the current lookup table
- this run should be read as a wiring-model cross-check layered on the already
  installed regulator behavior, not as a fresh replacement for the verified
  `exp10` PMIC baseline
- the `exp12` wrappers now reinstall `tps68470-regulator.ko` too so future
  reruns do not accidentally inherit an older PMIC experiment module

## Staged next branch set

The next four experiments are the wiring-model branch set, and `exp17` is the
explicit PMIC-side follow-up after that set.

They are deliberately ordered so the first question is not "which GPIO is
right?" but "can Linux stop overriding the Antti-style daisy-chain setup at
all?"

### 13. Daisy-chain isolation without OVTI5675 use of `GPIO1` / `GPIO2`

Purpose:
- run the first actual test of the Antti wiring model on this laptop rather
  than another collision test
- keep the verified `exp10` PMIC baseline in place
- enable daisy-chain on `GPIO1` / `GPIO2`
- stop exposing `GPIO1` / `GPIO2` to `OVTI5675:00` as `reset` /
  `powerdown` consumers

Default patch:
- `reference/patches/ms13q3-daisy-chain-isolation-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp13-ms13q3-daisy-chain-isolation-update.sh`
- `scripts/exp13-ms13q3-daisy-chain-isolation-verify.sh`

Implemented patch shape:
- start from the `exp10` `S_I2C_CTL BIT(1)`-only regulator behavior
- keep `daisy_chain_enable = true` for `MS-13Q3`
- remove the current `OVTI5675:00` lookup entries on `GPIO1` / `GPIO2`
- add narrow logging for any later attempt to drive `GPIO1` / `GPIO2` back to
  output mode
- add a one-shot `dump_stack()` when daisy-chain mode is enabled and an output
  transition is attempted on `GPIO1` or `GPIO2`
- extend the daisy-chain logging so `GPIO7` and `GPIO9` activity is visible
  during the same boot

Current status:
- staged only
- not yet run

Minimum useful success:
- `GPIO1` / `GPIO2` stay in input mode for the whole `ov5675` probe window
- the failure shape changes away from the flat current `exp10` / `exp12`
  `-121` pattern

Useful negative:
- the sensor still fails, but the logs prove that Linux no longer reclaims
  `GPIO1` / `GPIO2`
- that would move the next question from "board code still wrong" to "which
  remote control line is correct"
- or the branch fails its no-reclaim goal, but the one-shot stack dump
  immediately identifies who is still driving `GPIO1` / `GPIO2`

Failure that invalidates the branch:
- any later `direction-output-after gpio.1` or `gpio.2`
- any new consumer still toggling `GPIO1` / `GPIO2` as outputs

Interpretation:
- if this branch cannot keep `GPIO1` / `GPIO2` in daisy-chain input mode, the
  board modeling is still wrong before any GPIO7 / GPIO9 inference matters
- if reclaim still happens, the stack dump should let the next patch target the
  exact call path instead of repeating blind logging

### 14. Daisy-chain plus `GPIO9` as the first remote control-line candidate

Purpose:
- test the first Antti-style remote GPIO candidate under the current `ov5675`
  driver constraints
- keep `GPIO1` / `GPIO2` reserved for daisy-chain only
- avoid inventing a full two-line mapping before one remote line shows any
  signal

Default patch:
- `reference/patches/ms13q3-daisy-chain-gpio9-reset-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp14-ms13q3-daisy-chain-gpio9-reset-update.sh`
- `scripts/exp14-ms13q3-daisy-chain-gpio9-reset-verify.sh`

Implemented patch shape:
- carry forward the `exp13` daisy-chain isolation branch
- add a single `OVTI5675:00` `reset` lookup on `GPIO9`
- do not expose a `powerdown` line in this branch
- keep the `GPIO1` / `GPIO2` / `GPIO7` / `GPIO9` instrumentation

Current status:
- staged only
- not yet run

Why `GPIO9` first:
- Antti's working Prestige 14 series uses `GPIO_LOOKUP_IDX(..., 9, "reset", 0,
  ...)`
- current `ov5675` only consumes `reset` index `0` plus optional `powerdown`
  index `0`, so `GPIO9` is the closest literal first test of that model

Minimum useful success:
- `GPIO9` toggles during sensor power-on
- `GPIO1` / `GPIO2` stay in daisy-chain mode
- the result improves beyond a flat repeated `-121` read failure

Useful negative:
- behavior stays at `-121`, but `GPIO9` clearly becomes the active Linux
  control line and `GPIO1` / `GPIO2` remain untouched

Interpretation:
- a flat negative here means "GPIO9 alone is insufficient" more than
  "Antti's whole model is wrong"

### 15. Daisy-chain plus `GPIO7` as the alternate remote control-line candidate

Purpose:
- test the second Antti remote GPIO candidate with the same isolated
  daisy-chain setup
- answer whether `GPIO7` is the more credible primary line on this board when
  current `ov5675` can only consume one `reset` GPIO directly

Default patch:
- `reference/patches/ms13q3-daisy-chain-gpio7-reset-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp15-ms13q3-daisy-chain-gpio7-reset-update.sh`
- `scripts/exp15-ms13q3-daisy-chain-gpio7-reset-verify.sh`

Implemented patch shape:
- carry forward the `exp13` daisy-chain isolation branch
- add a single `OVTI5675:00` `reset` lookup on `GPIO7`
- do not expose a `powerdown` line in this branch
- keep the same `GPIO1` / `GPIO2` / `GPIO7` / `GPIO9` instrumentation

Current status:
- staged only
- not yet run

Minimum useful success:
- `GPIO7` toggles during sensor power-on
- `GPIO1` / `GPIO2` stay in daisy-chain mode
- failure shape improves relative to `exp10` / `exp12`

Useful negative:
- behavior is still flat `-121`, but the logs prove `GPIO7` can be isolated as
  the only Linux-visible control line without reintroducing the `GPIO1` /
  `GPIO2` collision

Interpretation:
- `exp14` and `exp15` together are meant to answer line identity under current
  driver limits, not to prove final reset versus powerdown semantics

### 16. Daisy-chain plus the best two-line `GPIO7` / `GPIO9` approximation

Purpose:
- run the closest current-driver approximation of Antti's working Prestige 14
  board data
- test whether this laptop needs both remote lines once one-line branches have
  been isolated first

Default patch:
- `reference/patches/ms13q3-daisy-chain-gpio7-gpio9-approx-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp16-ms13q3-daisy-chain-gpio7-gpio9-approx-update.sh`
- `scripts/exp16-ms13q3-daisy-chain-gpio7-gpio9-approx-verify.sh`

Implemented patch shape:
- carry forward the cleanest `exp13` branch
- keep `GPIO1` / `GPIO2` reserved for daisy-chain only
- expose both remote lines to `OVTI5675:00`
- current default mapping:
  - `reset` => `GPIO9`
  - `powerdown` => `GPIO7`
- if `exp14` or `exp15` produces a clearly stronger line candidate, preserve
  that line as `reset` and use the other as `powerdown`
- keep the same four-line instrumentation

Current status:
- staged only
- not yet run

Why this is only `exp16`:
- the current `MS-13Q3` `GPIO1` / `GPIO2` model was never validated strongly
- the earlier swap/polarity results were low-signal because `ov5675` drives
  both descriptors together
- a two-line remote mapping is easier to interpret after the single-line
  `GPIO9` and `GPIO7` branches have been run first

Minimum useful success:
- `GPIO1` / `GPIO2` remain daisy-chain inputs
- the remote two-line waveform reaches `ov5675`
- probe behavior moves later, changes shape, or binds the sensor

Useful negative:
- the branch stays at `-121`, but with no `GPIO1` / `GPIO2` reclaim and clear
  `GPIO7` / `GPIO9` activity

Interpretation:
- if `exp16` is still flat, the next branch after it should revisit later
  PMIC-side behavior only on top of the clean daisy-chain mapping, not on top
  of the old `GPIO1` / `GPIO2` board data

### 17. Clean daisy-chain plus targeted `BIT(0)` re-test

Purpose:
- explicitly test the remaining hypothesis that `S_I2C_CTL BIT(0)` only
  becomes safe once `GPIO1` / `GPIO2` are truly left in daisy-chain input
  mode
- turn the current vague "revisit later `BIT(0)`" note into a concrete yes/no
  experiment

Preconditions:
- `exp13` must first prove that Linux no longer reclaims `GPIO1` / `GPIO2`
- use the cleanest daisy-chain-isolated parent branch from `exp13` through
  `exp16`
- prefer the best remote-line branch if one of `exp14` through `exp16` shows a
  stronger signal than `exp13` alone

Default patch:
- `reference/patches/ms13q3-daisy-chain-bit0-retest-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp17-ms13q3-daisy-chain-bit0-retest-update.sh`
- `scripts/exp17-ms13q3-daisy-chain-bit0-retest-verify.sh`

Implemented patch shape:
- carry forward the current default clean daisy-chain-isolated branch
- keep the one-shot reclaim `dump_stack()` guard in place
- reintroduce `S_I2C_CTL BIT(0)` in one narrowly instrumented location only
- log the exact pre-write and post-write `S_I2C_CTL` state as in the earlier
  PMIC-focused branches
- treat any return of the old timeout storm as an immediate negative

Current status:
- staged only
- not yet run

Minimum useful success:
- `BIT(0)` now reads back cleanly without re-wedging PMIC access
- the sensor failure shape changes again or binds

Useful negative:
- the old `-110` / timeout-storm behavior returns immediately even though
  `GPIO1` / `GPIO2` stayed in daisy-chain input mode
- that would kill the "BIT(0) only becomes safe after clean daisy-chain"
  hypothesis quickly

Interpretation:
- `exp17` is meant to validate or kill one remaining PMIC-side idea after the
  wiring-model collision has been removed
- it should not be mixed back into the old `GPIO1` / `GPIO2` direct-control
  board model

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

Current best PMIC experiment state:

```bash
exp10 = BIT(1)-only regulator path
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

Use the implemented wrappers and the staged next branch set according to the
current evidence:

1. Keep `exp10` as the best verified PMIC state when you need the cleanest
   current branch.
2. Treat `exp11` as a completed negative, not as a baseline.
3. Treat `exp12` as a completed negative that proved the current `GPIO1` /
   `GPIO2` lookup model immediately collides with Antti-style daisy-chain
   setup.
4. Run `exp13` through `exp16` as the next ordered wiring-model branch set:
   - `exp13` proves whether Linux can leave `GPIO1` / `GPIO2` alone
   - `exp14` tests `GPIO9` as the first remote candidate
   - `exp15` tests `GPIO7` as the alternate remote candidate
   - `exp16` is the closest current-driver approximation of Antti's working
     remote-line model
5. Run `exp17` as the explicit PMIC-side follow-up after a clean daisy-chain
   branch exists.
   - re-test `BIT(0)` only after `exp13` proves no reclaim
6. Use `exp1` through `exp9` as the historical evidence chain that narrowed
   the problem to `S_I2C_CTL` behavior and competing GPIO interpretations.

That ordering still matches the current source-backed assessment in:

- `docs/webcam-status.md`
- `docs/wf-vs-uf-gpio-analysis.md`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`

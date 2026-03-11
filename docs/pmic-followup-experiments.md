# PMIC Follow-Up Experiment Workflow

Updated: 2026-03-12

This note turns the current ordered PMIC follow-up list into repeatable
update-and-verify workflows.

As of `2026-03-12`, raw Bayer capture is working on the `exp18` branch with
explicit `media-ctl` pipeline setup:

- `exp1` through `exp18` are completed historical experiments
- `exp18` is now the best current local branch:
  - stock regulator-side `VSIO` enable read back cleanly as `0x03`
  - the old timeout storm did not return
  - the media graph gained `ov5675 10-0036`
- `exp19` reused that exact `exp18` patch and answered the first raw userspace
  capture question:
  - `/dev/video0` opened cleanly
  - buffer allocation and queueing succeeded
  - `VIDIOC_STREAMON` failed with `Link has been severed`
  - the raw output file stayed at `0` bytes
- a later no-reboot userland format sweep narrowed that capture result
  further:
  - `/dev/video0` through `/dev/video7` all accepted `VIDIOC_S_FMT` to
    `4096x3072 BA10`
  - all eight nodes still failed `VIDIOC_STREAMON` with `Link has been
    severed`
  - all eight raw output files stayed at `0` bytes
- `exp10` remains the best older PMIC control baseline
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
- `exp13` answered the first clean daisy-chain-isolation question:
  - yes, once Linux stops exporting `GPIO1` / `GPIO2` to `OVTI5675:00`, it
    leaves them in daisy-chain input mode for the full observed probe window
  - no, that alone does not wake the sensor; the failure shape still ends at
    repeated `-121`
- `exp14` answered the first remote-line question:
  - yes, `GPIO9` becomes an active Linux-visible remote line
  - no, `GPIO9` alone is not sufficient; the failure shape still ends at
    repeated `-121`
- `exp15` answered the second remote-line question:
  - yes, `GPIO7` becomes an active Linux-visible remote line
  - no, `GPIO7` alone is not sufficient; the failure shape still ends at
    repeated `-121`
- `exp16` answered the best current-driver two-line question:
  - yes, `GPIO7` and `GPIO9` can both be active during the identify window
  - no, the two-line approximation still does not move the sensor off
    repeated `-121`
- `exp17` answered the remaining clean-branch PMIC-side tail:
  - yes, one later `BIT(0)` write on `sensor-gpio.9` is safe and reads back
    as `0x03`
  - no, that still does not move the sensor off repeated `-121`
- `exp18` answered the last narrow Antti-parity PMIC comparison:
  - yes, full standard `VSIO` enable is safe on top of the clean daisy-chain
    branch
  - yes, the sensor now binds into the media graph as `ov5675 10-0036`
  - no, the verify-side PMIC dump path is still not trustworthy after boot

## Goal

Make each PMIC experiment runnable with the same high-safety pattern:

1. apply the current baseline patch stack with `scripts/patch-kernel.sh`
2. apply one experiment patch
3. rebuild only the required module subtrees
4. install the resulting `.ko.zst` files into `/usr/lib/modules/<release>/...`
5. run `depmod`
6. reboot once
7. run a clean-boot verification wrapper that reuses
   `scripts/01-clean-boot-check.sh` and adds an experiment-specific journal
   grep plus a root PMIC dump, or for `exp19`, a userspace capture check

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

The PMIC-side experiment `*-verify.sh` wrappers through `exp18` do this after
reboot:

- run `scripts/01-clean-boot-check.sh`
- append an experiment-specific journal extract to the run directory
- run `sudo scripts/pmic-reg-dump.sh` and save the output into the same run
  directory
- capture `modinfo` for the baseline plus experiment-specific modules
- normalize the run-directory ownership back to the invoking user if any
  root-assisted step left files owned by `root`

`exp19` is the first capture-focused exception:

- its update wrapper still uses the shared experiment workflow
- its verify wrapper runs `scripts/04-userspace-capture-check.sh`
- it records userspace streaming artifacts instead of a PMIC dump

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

## Antti-model branch set

`exp13` through `exp17` now answer the clean daisy-chain-isolation,
single-line remote, current two-line remote, and clean-branch later-`BIT(0)`
questions.

They were deliberately ordered so the remaining question would not stay at
"does Linux still reclaim the daisy-chain lines?" or "which lone remote line
is right?" The result after `exp18` is that the named branch set is no longer
blocked on PMIC `BIT(0)` safety: standard `VSIO` is now safe on the clean
daisy-chain branch and the sensor binds into the media graph.

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
- completed on `2026-03-11`
- update run:
  - `runs/2026-03-11/20260311T184340-ms13q3-daisy-chain-isolation-update/`
- verify run:
  - `runs/2026-03-11/20260311T184614-snapshot-exp13-clean-boot/`

Observed outcome:
- positive for wiring isolation, negative as a direct fix
- `GPIO1` / `GPIO2` stayed in input mode for the observed `ov5675` probe
  window
- no later `direction-output-after gpio.1` or `gpio.2` lines appeared
- the one-shot reclaim `dump_stack()` guard never fired
- `GPIO7` / `GPIO9` remained untouched in this branch
- chip-ID behavior stayed flat at repeated `-121`

Key lines:
- `exp13_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp13_daisy: probe-after gpio.2 ... ctl=0x00`
- `pmic_focus: enable-bit1-only VSIO ... after=0x02`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Interpretation:
- `exp13` answered the reclaim question positively:
  once Linux stops exposing `GPIO1` / `GPIO2` to `OVTI5675:00`, it can leave
  them in daisy-chain input mode
- the daisy-chain collision is no longer the leading blocker
- the remote-line branch set later showed that `GPIO9`, `GPIO7`, and the
  current two-line approximation are all active but still insufficient under
  current driver limits

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
- completed on `2026-03-11`
- update run:
  - `runs/2026-03-11/20260311T185841-ms13q3-daisy-chain-gpio9-reset-update/`
- verify run:
  - `runs/2026-03-11/20260311T190240-snapshot-exp14-clean-boot/`

Observed outcome:
- positive for remote-line activation, negative as a direct fix
- `GPIO1` / `GPIO2` stayed in daisy-chain input mode
- `GPIO9` was actively driven by Linux during probe
- `GPIO9` reached observed `SGPO = 0x04` during the identify window
- chip-ID behavior still stayed flat at repeated `-121`

Key lines:
- `exp14_daisy: direction-output-after gpio.9 ...`
- `exp14_daisy: set-after gpio.9 ... sgpo_ret=0 sgpo=0x04`
- `exp14_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp14_daisy: probe-after gpio.2 ... ctl=0x00`
- `ov5675 ... chip id read attempt 5/5 failed: -121`

Interpretation:
- `GPIO9` is now an observed Linux-visible remote control line on this board
- `GPIO9` alone is insufficient as the only reset line under current driver
  limits
- `exp15` did not overturn the current default mapping, so `exp16` should keep
  `GPIO9` as `reset` and pair it with `GPIO7` as the first two-line
  approximation

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
- completed on `2026-03-11`
- update run:
  - `runs/2026-03-11/20260311T194617-ms13q3-daisy-chain-gpio7-reset-update/`
- verify run:
  - `runs/2026-03-11/20260311T195819-snapshot-exp15-clean-boot/`

Observed outcome:
- positive for remote-line activation, negative as a direct fix
- `GPIO1` / `GPIO2` stayed in daisy-chain input mode
- `GPIO7` was actively driven by Linux during probe
- `GPIO7` reached observed `SGPO = 0x01` during the identify window
- chip-ID behavior still stayed flat at repeated `-121`
- verify-side PMIC dump did not complete because the sudo prompt timed out

Key lines:
- `exp15_daisy: direction-output-after gpio.7 ...`
- `exp15_daisy: set-after gpio.7 ... sgpo_ret=0 sgpo=0x01`
- `exp15_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp15_daisy: probe-after gpio.2 ... ctl=0x00`
- `ov5675 ... chip id read attempt 5/5 failed: -121`
- `sudo: timed out reading password`

Interpretation:
- `GPIO7` is now an observed Linux-visible remote control line on this board
- `GPIO7` alone is insufficient as the only reset line under current driver
  limits
- `exp14` and `exp15` together show that both single-line remote candidates
  are active but individually insufficient
- `exp16` later tested that current two-line `GPIO9` / `GPIO7`
  approximation directly

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
- current evidence note:
  - `exp14` showed `GPIO9` is active but insufficient alone
  - `exp15` showed `GPIO7` is active but insufficient alone
  - keep `GPIO9` as `reset` and `GPIO7` as `powerdown` for the first two-line
    approximation because neither lone-line run clearly displaced that default
- keep the same four-line instrumentation

Current status:
- completed on `2026-03-11`
- update run:
  - `runs/2026-03-11/20260311T202133-ms13q3-daisy-chain-gpio7-gpio9-approx-update/`
- verify run:
  - `runs/2026-03-11/20260311T202258-snapshot-exp16-clean-boot/`

Observed outcome:
- positive for combined remote-line activation, negative as a direct fix
- `GPIO1` / `GPIO2` stayed in daisy-chain input mode
- `GPIO7` and `GPIO9` were both actively driven during the identify window
- observed combined `SGPO` reached `0x05`
- chip-ID behavior still stayed flat at repeated `-121`
- verify-side PMIC dump returned `ERROR` for all registers again

Key lines:
- `exp16_daisy: set-after gpio.7 ... sgpo_ret=0 sgpo=0x01`
- `exp16_daisy: set-after gpio.9 ... sgpo_ret=0 sgpo=0x05`
- `exp16_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp16_daisy: probe-after gpio.2 ... ctl=0x00`
- `ov5675 ... chip id read attempt 5/5 failed: -121`
- `0x43   = ERROR   # S_I2C_CTL`

Interpretation:
- the best current-driver `GPIO9` / `GPIO7` approximation is active but still
  insufficient
- under current `ov5675` limits, the direct remote-line mapping question is
  now largely exhausted
- `exp17` later showed that one clean-remote-branch `BIT(0)` re-test is safe,
  but still insufficient

### 17. Clean daisy-chain plus targeted `BIT(0)` re-test

Purpose:
- explicitly test the remaining hypothesis that `S_I2C_CTL BIT(0)` only
  becomes safe once `GPIO1` / `GPIO2` are truly left in daisy-chain input
  mode
- turn the current vague "revisit later `BIT(0)`" note into a concrete yes/no
  experiment

Preconditions:
- `exp13` already proved that Linux no longer reclaims `GPIO1` / `GPIO2` once
  those lines stop being exported to `OVTI5675:00`
- use the cleanest remote-line parent branch from `exp14` through `exp16`
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
- completed on `2026-03-11`
- update run:
  - `runs/2026-03-11/20260311T203041-ms13q3-daisy-chain-bit0-retest-update/`
- verify run:
  - `runs/2026-03-11/20260311T203557-snapshot-exp17-clean-boot/`

Minimum useful success:
- `BIT(0)` now reads back cleanly without re-wedging PMIC access
- the sensor failure shape changes again or binds

Observed outcome:
- positive for safe later `BIT(0)`, negative as a direct fix
- `GPIO1` / `GPIO2` stayed in daisy-chain input mode
- `GPIO7` and `GPIO9` were both actively driven during the identify window
- the late PMIC write on `sensor-gpio.9` read back cleanly:
  - `before=0x02`
  - `after=0x03`
- chip-ID behavior still stayed flat at repeated `-121`
- the old timeout storm did not return
- verify-side PMIC dump returned `ERROR` for all registers again

Key lines:
- `exp17_daisy: probe-after gpio.1 ... ctl=0x00`
- `exp17_daisy: probe-after gpio.2 ... ctl=0x00`
- `exp17_daisy: set-after gpio.7 ... sgpo_ret=0 sgpo=0x01`
- `exp17_daisy: set-after gpio.9 ... sgpo_ret=0 sgpo=0x05`
- `exp17_pmic_gpio: sensor-gpio.9 value=0 ... before=0x02 ... after=0x03`
- `ov5675 ... chip id read attempt 5/5 failed: -121`
- `pmic_focus: disable-bit1-only VSIO reg=S_I2C_CTL(0x43) ... before=0x03 ... after=0x01`

Interpretation:
- `exp17` kills the simple "any later `BIT(0)` is toxic" hypothesis
- it also proves that one safe later `BIT(0)` placement is still not enough to
  wake the sensor
- the remaining direct PMIC question should now move to standard `VSIO` on top
  of the same clean branch

### 18. Clean daisy-chain plus standard `VSIO` enable

Purpose:
- test the cleanest remaining Antti-vs-local PMIC delta
- keep the clean daisy-chain-isolated `GPIO9` / `GPIO7` branch
- remove the local `BIT(1)`-only `VSIO` workaround
- restore standard `VSIO` enable behavior while keeping focused PMIC logging

Default patch:
- `reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/exp18-ms13q3-daisy-chain-standard-vsio-update.sh`
- `scripts/exp18-ms13q3-daisy-chain-standard-vsio-verify.sh`

Implemented patch shape:
- carry forward the clean daisy-chain isolation and `GPIO9` / `GPIO7` mapping
- keep the one-shot reclaim `dump_stack()` guard in place
- remove the `exp17` late GPIO-phase `BIT(0)` hook
- restore standard regulator-side `VSIO` enable / disable behavior
- keep focused PMIC readback logging around `S_I2C_CTL`, `VACTL`, and `VDCTL`
- keep the current focused logging asymmetry on disable:
  - `ANA` and `VSIO` disable transitions are logged
  - `CORE` disable still falls through the plain helper because exp18 is
    targeting the PMIC path around `S_I2C_CTL`, not PLL teardown

Current status:
- completed on `2026-03-11`
- result:
  - `S_I2C_CTL` read back cleanly as `0x03` on enable and `0x00` on disable
  - `GPIO1` / `GPIO2` stayed isolated in daisy-chain mode
  - `GPIO7` / `GPIO9` were both active during the identify window
  - the media graph gained `ov5675 10-0036` linked into `Intel IPU7 CSI2 0`
  - the verify-side PMIC dump still came back all `ERROR`

Minimum useful success:
- standard `VSIO` enable now reads back cleanly on the clean daisy-chain
  branch
- the sensor failure shape changes materially or binds

Useful negative:
- the old early `S_I2C_CTL` wedge returns immediately even on top of the clean
  daisy-chain branch
- that would strengthen the case that the local `BIT(1)`-only workaround is a
  real board-specific requirement candidate

Interpretation:
- `exp18` proves the old early `BIT(0)` wedge was not board-intrinsic in the
  abstract; it depended on the older non-isolated branch shape
- the main Antti-parity PMIC question is now answered positively on `MS-13Q3`
- the next work should move to capture validation, userspace behavior, and
  remaining post-boot PMIC visibility gaps

### 19. Userspace capture validation on the positive `exp18` branch

Purpose:
- keep the positive `exp18` kernel branch unchanged
- stop spending the next iteration on PMIC readback visibility first
- determine whether normal Linux userspace can actually stream frames on the
  first local branch that binds `ov5675`

Default patch:
- `reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch`

Extra module rebuild/install:
- `gpio-tps68470.ko`
- `tps68470-regulator.ko`

Scripts:
- `scripts/04-userspace-capture-check.sh`
- `scripts/05-userspace-format-sweep.sh`
- `scripts/exp19-ms13q3-userspace-capture-validation-update.sh`
- `scripts/exp19-ms13q3-userspace-capture-validation-verify.sh`

Implemented workflow shape:
- reuse the `exp18` patch unchanged as the kernel baseline
- capture a normal post-boot snapshot first
- inspect the current media graph and selected `/dev/video*` node
- attempt a raw `v4l2-ctl` streaming capture on `/dev/video0` by default
- if that first stream fails later at `VIDIOC_STREAMON`, use
  `scripts/05-userspace-format-sweep.sh` as the repeatable no-reboot
  multi-node format-alignment follow-up
- record:
  - stream exit status
  - raw-output file size
  - selected media-graph lines
  - selected V4L2 node lines
  - relevant kernel log lines since the capture started

Current status:
- completed on `2026-03-11`
- update run:
  - `runs/2026-03-11/20260311T223549-ms13q3-userspace-capture-validation-update/`
- verify run:
  - `runs/2026-03-11/20260311T223717-snapshot-exp19-userspace-capture/`

Minimum useful success:
- `v4l2-ctl --stream-mmap` completes and writes a non-empty raw file
- no new `ov5675`, `intel-ipu7`, or `isys` failure appears during the stream

Useful negative:
- userspace streaming times out or fails even though the media graph still
  shows `ov5675 10-0036`
- that would narrow the remaining blocker to capture-path configuration,
  permissions, or userspace-facing driver behavior rather than first sensor
  bind

Observed outcome:
- negative, but high-signal
- the media graph still showed `ov5675 10-0036` linked into
  `Intel IPU7 CSI2 0`
- `/dev/video0` still reported capture and streaming capability
- `VIDIOC_REQBUFS`, `VIDIOC_CREATE_BUFS`, `VIDIOC_QUERYBUF`, `VIDIOC_G_FMT`,
  and all four `VIDIOC_QBUF` calls succeeded
- `VIDIOC_STREAMON` then failed with `Link has been severed`
- `v4l2-ctl` exited `0` anyway, but the raw output file stayed at `0` bytes
- no matching kernel journal lines were emitted during the capture attempt

Interpretation:
- `exp19` proved the current blocker was no longer first bind or basic node
  presence
- the later no-reboot format sweep ruled out the simple node-format mismatch
- the actual root cause was identified by `scripts/06-media-pipeline-setup.sh`:
  - the CSI2-to-capture link was not enabled
  - the CSI2 pad formats did not match the sensor output
  - once both were fixed with `media-ctl`, `STREAMON` succeeded and raw Bayer
    frames were captured

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

## Why the PMIC-side verify wrappers do a PMIC dump

The clean-boot journal remains the primary truth source, but the PMIC dump is a
useful secondary check for the PMIC-side follow-ups through `exp18` because it
captures:

- value-register state
- `S_I2C_CTL`
- clock registers
- GPIO control/data registers

The dump happens after the clean-boot checkpoint, not before it, so it does not
replace the boot log and it does not make claims it cannot support.

`exp19` is intentionally different:

- it does not ask a new PMIC-state question
- it asks whether the positive `exp18` branch can actually stream frames from
  userspace
- its verify wrapper therefore records userspace capture artifacts instead of
  another PMIC dump

## Current interpretation

**Raw Bayer capture is now working** on the `exp18` branch with explicit
`media-ctl` pipeline setup.

1. Use `exp18` as the current kernel branch.
2. Use `scripts/06-media-pipeline-setup.sh` for repeatable capture validation.
3. The `STREAMON` "Link has been severed" failure was caused by missing
   userspace `media-ctl` link enable + pad format setup, not by a kernel or
   firmware gap.
4. The `media-ctl -R` route command returns `ENOTSUP` on IPU7 CSI2 entities;
   link enable + format alignment alone is sufficient.
5. All earlier experiments (`exp1` through `exp18`) form the historical
   evidence chain that narrowed the PMIC, GPIO, and wiring model until the
   sensor bound and streamed.
6. Remaining work is now cleanup, upstreamability, and higher-level tool
   testing -- not basic bring-up.

That matches the current assessment in:

- `docs/webcam-status.md`
- `docs/wf-vs-uf-gpio-analysis.md`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`

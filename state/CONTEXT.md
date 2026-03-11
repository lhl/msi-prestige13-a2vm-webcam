# Context

Updated: 2026-03-11

## Objective

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG,
or reduce the remaining blocker to a specific upstream patch or vendor-only gap
with strong evidence.

## Resume

- Repo root:
  - `/home/lhl/github/lhl/msi-prestige13-a2vm-webcam`
- Fastest way back into the latest repo session:
  - `cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam && codex resume --last`
- Picker filtered to this repo:
  - `cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam && codex resume`
- Show all recorded sessions:
  - `codex resume --all`

## Current State

- IPU7 core support is present and firmware loads.
- `OVTI5675:00` is the correct sensor path.
- the validated `tested` patch stack is:
  - `ms13q3-int3472-tps68470-v1.patch`
  - `ipu-bridge-ovti5675-v1.patch`
  - `ov5675-serial-power-on-v1.patch`
- what those three patches already fixed:
  - the old `No board-data found for this model` failure is gone
  - `ipu-bridge` now finds `OVTI5675:00` and reports one connected camera
  - the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
- the current best PMIC experiment clean-boot blocker is now:
  - `chip id read attempt 1/5 failed: -121`
  - `...`
  - `chip id read attempt 5/5 failed: -121`
  - `failed to find sensor: -121`
  - `probe with driver ov5675 failed with error -121`
  - `ov5675` remains unbound
  - there are still no `/dev/v4l-subdev*` nodes

## What March 9 Added

- `exp1` PMIC instrumentation proved:
  - `ov5675` gets a real clock provider via the common clock framework
  - `tps68470_clk_prepare()` really runs
  - the remaining blocker is not a dummy xvclk path
- `exp2` staged `S_I2C_CTL` was informative but not a clean negative:
  - the helper path runs
  - `S_I2C_CTL` still reads back as `0x00`
  - unwind later hits `VSIO: failed to disable: -ETIMEDOUT`
- `exp3` `VD = 1050 mV` was a clean negative
- `exp4` `WF::Initialize`-style value programming really executed, but still
  ended at the same `-110` identify timeout
- `exp5` `WF` GPIO mode follow-up was negative
- `exp6` `UF` / `gpio.4` last resort was negative
- `exp7` raw PMIC regmap trace isolated the first bad PMIC transaction:
  - PMIC access is healthy through clock setup plus `ANA` and `CORE` enable
  - the first bad operation is `VSIO` enable on `S_I2C_CTL` `0x43`
  - the `regmap_update_bits()` call returns `0`, but the immediate readback is
    already `-110`
  - after that point, `i2c_designware.1` starts timing out and later PMIC
    accesses collapse to `-110`
- `exp8` focused `S_I2C_CTL` trace confirmed the same failure point with a
  narrower patch:
  - `ANA` and `CORE` still read back cleanly
  - the combined `VSIO` write to `0x43` still returns success but immediate
    readback fails with `-110`
  - the timeout storm still persists, though without the `exp7` emergency-mode
    outcome
- `exp9` split-step `S_I2C_CTL` trace answered the next narrow question:
  - IO-side `BIT(1)` reads back cleanly as `0x02`
  - the wedge begins only after the later GPIO-side `BIT(0)` update
  - the run now fails earlier at `ov5675 ... failed to power on: -110`
- `exp10` `BIT(1)`-only `S_I2C_CTL` changed the failure shape again:
  - `ANA`, `CORE`, and `VSIO BIT(1)` all read back cleanly
  - the old `i2c_designware.1` timeout storm is gone
  - the sensor gets back to chip-ID reads, but they now fail with `-121`
  - `VSIO BIT(1)` also disables cleanly on unwind
- `exp11` tested one later GPIO-phase `BIT(0)` hook:
  - chip-ID behavior stayed at `-121`
  - the observed late `BIT(0)` event was:
    - `pmic_gpio: sensor-gpio.1 value=0 ... before=0x02 update_ret=0 after_ret=-110`
  - after that point, the old timeout storm returned
  - so `exp10` remains the best clean-boot PMIC state
- the post-boot PMIC dump path is still not usable:
  - `scripts/pmic-reg-dump.sh` returned `ERROR` for all registers in
    representative PMIC experiment runs

## What March 11 Added

- preserved a full repo-local review of Antti Laakso's March 10, 2026 Prestige
  14 patch thread under:
  - `docs/antti-prestige14-thread-review.md`
- recorded the main new upstream-relevance conclusion:
  - another MSI `OV5675` / `TPS68470` wiring pattern likely exists
  - on that pattern, `GPIO1` / `GPIO2` are used for daisy-chain mode rather
    than as the direct sensor-control pair
- ran `exp12` as a separate Antti-inspired cross-check:
  - patch:
    - `reference/patches/ms13q3-daisy-chain-crosscheck-v1.patch`
  - scripts:
    - `scripts/exp12-ms13q3-daisy-chain-crosscheck-update.sh`
    - `scripts/exp12-ms13q3-daisy-chain-crosscheck-verify.sh`
  - behavior:
    - enable daisy-chain mode on `GPIO1` / `GPIO2`
    - keep the current `MS-13Q3` `reset` / `powerdown` lookup on those same
      pins
    - log whether Linux later re-drives them out of input mode
  - status:
    - negative as a direct fix
    - proved that Linux immediately re-drives both lines back to output mode
    - first run should be read as layered on the previously installed
      regulator behavior
    - the `exp12` wrappers now reinstall `tps68470-regulator.ko` too so
      reruns restore the baseline regulator module explicitly
    - do not replace `exp10` as the best verified PMIC baseline
- planned the next ordered Antti-model branch set:
  - `exp13`: keep `exp10`, enable daisy-chain, and stop exposing `GPIO1` /
    `GPIO2` to `OVTI5675:00`
  - `exp14`: carry `exp13` forward and test `GPIO9` as the first remote
    control-line candidate
  - `exp15`: carry `exp13` forward and test `GPIO7` as the alternate remote
    control-line candidate
  - `exp16`: carry the clean daisy-chain branch forward and test the best
    current-driver `GPIO7` / `GPIO9` approximation
- added two planning refinements from follow-up review:
  - `exp13` should be self-diagnosing with a one-shot `dump_stack()` if
    `GPIO1` / `GPIO2` still get re-driven as outputs
  - `exp17` should exist as an explicit clean-daisy-chain `BIT(0)` re-test
    after `exp13` proves no reclaim
- recorded one important design constraint for those branches:
  - current `ov5675` only consumes `reset` index `0` plus optional
    `powerdown` index `0`
  - Antti's dual-reset board data therefore cannot be copied literally without
    either single-line candidate runs first or an `ov5675` consumer change

## Current Interpretation

- We are past the broad platform-support and board-data stage.
- We are at the hard last-mile stage where the sensor exists but never wakes
  enough to answer chip-ID reads.
- Simple GPIO label / polarity / release-order guesses are mostly exhausted.
- the current Linux `GPIO1` / `GPIO2` board model is still only a candidate,
  not a validated wiring map
- Antti Laakso's working Prestige 14 patch is now the strongest external
  wiring model for the next branch set
- The strongest remaining gap is PMIC-side behavior Linux still does not model
  correctly, especially around:
  - whether Linux should stop using `GPIO1` / `GPIO2` as direct sensor-control
    outputs on this board
  - which remote line, `GPIO9` or `GPIO7`, is the first credible sensor
    control candidate under current `ov5675` limits
  - where the later `S_I2C_CTL` `BIT(0)` phase belongs, if anywhere, once the
    daisy-chain wiring branch is isolated
  - why the current late hook only showed up on `sensor-gpio.1`
  - PMIC value/register state truth during the failing identify window
  - higher-level Windows config feeding `WF::SetConf` and selecting `WF`
    versus `UF`

## Next Best Steps

1. Keep `exp10` as the best PMIC state when resuming.
   - `BIT(1)` in the regulator path
   - no early or currently-modeled late `BIT(0)` write
2. Treat `exp12` as completed collision evidence, not as a clean Antti-model
   test.
   - it proved the current `GPIO1` / `GPIO2` lookup immediately overrides
     daisy-chain setup
3. Stage `exp13` next.
   - keep daisy-chain on `GPIO1` / `GPIO2`
   - remove `OVTI5675:00` use of those lines entirely
   - prove whether Linux can leave them in input mode for the full probe
4. Stage `exp14` and `exp15` after `exp13`.
   - test `GPIO9` and `GPIO7` separately as the first remote control-line
     candidates under current `ov5675` driver constraints
5. Stage `exp16` only after the single-line branches.
   - use the clean daisy-chain branch plus the best two-line `GPIO7` / `GPIO9`
     approximation
6. Keep `exp13` self-diagnosing.
   - if reclaim still happens, the one-shot stack dump should identify the
     output-driving call path immediately
7. Stage `exp17` after `exp13` proves no reclaim.
   - re-test `S_I2C_CTL BIT(0)` only on top of the cleanest daisy-chain
     branch from `exp13` through `exp16`
8. Fix or replace the post-boot PMIC dump path so we can observe real register
   state after a failed clean boot.
9. Extract more of the higher-level Windows config path above `WF::SetConf`.
10. Do not rerun the broad `exp7` snapshot patch as a default path; it amplified
   the timeout storm enough to interact badly with boot.

## Key Paths

- Local kernel package root:
  - `~/.cache/paru/clone/linux-mainline`
- Editable kernel worktree:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
- Patch-stack workflow:
  - `docs/patch-kernel-workflow.md`
  - `scripts/patch-kernel.sh`
- PMIC experiment workflow:
  - `docs/pmic-followup-experiments.md`
  - `scripts/lib-experiment-workflow.sh`
- Complete March 9 report:
  - `docs/20260309-status-report.md`
- Short live status:
  - `docs/webcam-status.md`
- Windows PMIC analysis:
  - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - `docs/wf-vs-uf-gpio-analysis.md`

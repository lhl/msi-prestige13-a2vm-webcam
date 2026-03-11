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
- the current best local branch is now `exp18`:
  - standard regulator-side `VSIO` enable read back cleanly as `0x03`
  - the old timeout storm did not return
  - the media graph gained `ov5675 10-0036` linked into `Intel IPU7 CSI2 0`
  - `/dev/v4l-subdev0` now exists
- the remaining blocker is now after sensor bind:
  - the first raw `/dev/video0` stream now fails at `VIDIOC_STREAMON` with
    `Link has been severed`
  - the raw output file stays at `0` bytes
  - a later no-reboot sweep forced `/dev/video0` through `/dev/video7` to
    `4096x3072 BA10`
  - all eight nodes accepted `VIDIOC_S_FMT`
  - all eight still failed `VIDIOC_STREAMON` with `Link has been severed`
  - post-boot PMIC dumping still returns `ERROR` for every register

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
- staged the next ordered Antti-model branch set with repo-local patch and
  wrapper pairs, then ran it through `exp17`:
  - `exp13`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-isolation-v1.patch`
    - scripts:
      - `scripts/exp13-ms13q3-daisy-chain-isolation-update.sh`
      - `scripts/exp13-ms13q3-daisy-chain-isolation-verify.sh`
  - `exp14`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-gpio9-reset-v1.patch`
    - scripts:
      - `scripts/exp14-ms13q3-daisy-chain-gpio9-reset-update.sh`
      - `scripts/exp14-ms13q3-daisy-chain-gpio9-reset-verify.sh`
  - `exp15`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-gpio7-reset-v1.patch`
    - scripts:
      - `scripts/exp15-ms13q3-daisy-chain-gpio7-reset-update.sh`
      - `scripts/exp15-ms13q3-daisy-chain-gpio7-reset-verify.sh`
  - `exp16`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-gpio7-gpio9-approx-v1.patch`
    - scripts:
      - `scripts/exp16-ms13q3-daisy-chain-gpio7-gpio9-approx-update.sh`
      - `scripts/exp16-ms13q3-daisy-chain-gpio7-gpio9-approx-verify.sh`
  - `exp17`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-bit0-retest-v1.patch`
    - scripts:
      - `scripts/exp17-ms13q3-daisy-chain-bit0-retest-update.sh`
      - `scripts/exp17-ms13q3-daisy-chain-bit0-retest-verify.sh`
- preserved the two key branch-shape refinements from follow-up review:
  - `exp13` is self-diagnosing with a one-shot `dump_stack()` if `GPIO1` /
    `GPIO2` still get re-driven as outputs
  - `exp17` exists as an explicit clean-daisy-chain `BIT(0)` re-test after
    `exp13` proves no reclaim
- recorded one important design constraint for those branches:
  - current `ov5675` only consumes `reset` index `0` plus optional
    `powerdown` index `0`
  - Antti's dual-reset board data therefore cannot be copied literally without
    either single-line candidate runs first or an `ov5675` consumer change
- staged the next follow-up as `exp19`:
  - keep the positive `exp18` patch unchanged
  - add `scripts/04-userspace-capture-check.sh`
  - use a custom verify wrapper to record raw userspace streaming on
    `/dev/video0`
- ran `exp19` and recorded the first userspace-capture result:
  - update run:
    - `runs/2026-03-11/20260311T223549-ms13q3-userspace-capture-validation-update/`
  - verify run:
    - `runs/2026-03-11/20260311T223717-snapshot-exp19-userspace-capture/`
  - result:
    - negative, but high-signal
    - `/dev/video0` opened cleanly
    - buffer allocation and queueing succeeded
    - `VIDIOC_STREAMON` failed with `Link has been severed`
    - the raw output file stayed at `0` bytes
    - no matching kernel journal lines appeared during the capture attempt
- ran a no-reboot userspace format sweep on the same positive `exp18` boot:
  - run:
    - `runs/2026-03-11/20260311T232226-userland-format-sweep/`
  - result:
    - negative, but high-signal
    - `/dev/video0` through `/dev/video7` all accepted `VIDIOC_S_FMT` to
      `4096x3072 BA10`
    - all eight nodes still failed `VIDIOC_STREAMON` with
      `Link has been severed`
    - all eight raw output files stayed at `0` bytes
    - no matching kernel journal lines appeared during the sweep
- ran `exp13` and recorded the first clean daisy-chain-isolation result:
  - update run:
    - `runs/2026-03-11/20260311T184340-ms13q3-daisy-chain-isolation-update/`
  - verify run:
    - `runs/2026-03-11/20260311T184614-snapshot-exp13-clean-boot/`
  - result:
    - positive for wiring isolation, negative as a direct fix
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - no later `direction-output-after gpio.1` / `gpio.2`
    - no one-shot reclaim `dump_stack()`
    - sensor failure remained flat at repeated `-121`
- ran `exp14` and recorded the first remote-line candidate result:
  - update run:
    - `runs/2026-03-11/20260311T185841-ms13q3-daisy-chain-gpio9-reset-update/`
  - verify run:
    - `runs/2026-03-11/20260311T190240-snapshot-exp14-clean-boot/`
  - result:
    - positive for remote-line activation, negative as a direct fix
    - `direction-output-after gpio.9 ...`
    - `set-after gpio.9 ... sgpo=0x04`
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - sensor failure remained flat at repeated `-121`
- ran `exp15` and recorded the second remote-line candidate result:
  - update run:
    - `runs/2026-03-11/20260311T194617-ms13q3-daisy-chain-gpio7-reset-update/`
  - verify run:
    - `runs/2026-03-11/20260311T195819-snapshot-exp15-clean-boot/`
  - result:
    - positive for remote-line activation, negative as a direct fix
    - `direction-output-after gpio.7 ...`
    - `set-after gpio.7 ... sgpo=0x01`
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - sensor failure remained flat at repeated `-121`
    - verify-side PMIC dump did not complete:
      - `sudo: timed out reading password`
- ran `exp16` and recorded the first two-line remote approximation result:
  - update run:
    - `runs/2026-03-11/20260311T202133-ms13q3-daisy-chain-gpio7-gpio9-approx-update/`
  - verify run:
    - `runs/2026-03-11/20260311T202258-snapshot-exp16-clean-boot/`
  - result:
    - positive for combined remote-line activation, negative as a direct fix
    - `set-after gpio.7 ... sgpo=0x01`
    - `set-after gpio.9 ... sgpo=0x05`
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - sensor failure remained flat at repeated `-121`
    - verify-side PMIC dump returned `ERROR` for all registers again
- ran `exp17` and recorded the clean daisy-chain late-`BIT(0)` re-test result:
  - update run:
    - `runs/2026-03-11/20260311T203041-ms13q3-daisy-chain-bit0-retest-update/`
  - verify run:
    - `runs/2026-03-11/20260311T203557-snapshot-exp17-clean-boot/`
  - result:
    - positive for safe later `BIT(0)`, negative as a direct fix
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - `set-after gpio.7 ... sgpo=0x01`
    - `set-after gpio.9 ... sgpo=0x05`
    - `exp17_pmic_gpio ... before=0x02 ... after=0x03`
    - no `controller timed out` return
    - sensor failure remained flat at repeated `-121`
    - `disable-bit1-only VSIO ... before=0x03 ... after=0x01`
    - verify-side PMIC dump returned `ERROR` for all registers again

## Current Interpretation

- We are past the broad platform-support and board-data stage.
- We are at the hard last-mile stage where the sensor binds into the media
  graph, but userspace capture is still unproven.
- Simple GPIO label / polarity / release-order guesses are mostly exhausted.
- the current Linux `GPIO1` / `GPIO2` board model is still only a candidate,
  not a validated wiring map
- Antti Laakso's working Prestige 14 patch is now the strongest external
  wiring model for the next branch set
- `exp13` proved that once Linux stops exporting `GPIO1` / `GPIO2` to the
  sensor, it can leave those lines in daisy-chain input mode
- `exp14` proved that `GPIO9` is an active remote line, but insufficient alone
- `exp15` proved that `GPIO7` is an active remote line, but insufficient alone
- `exp16` proved that the current two-line `GPIO9` / `GPIO7` approximation can
  drive both remote lines together, but is still insufficient
- `exp17` proved that one late `S_I2C_CTL BIT(0)` assertion on the clean
  remote-line branch is safe and reads back as `0x03`, but is still
  insufficient
- `exp18` is now completed evidence:
  - standard regulator-side `VSIO` enable read back cleanly as `0x03` on the
    clean daisy-chain branch
  - the old timeout storm did not return
  - the media graph gained `ov5675 10-0036` linked into `Intel IPU7 CSI2 0`
  - the verify-side PMIC dump still came back all `ERROR`
- `exp19` is now completed evidence:
  - the first raw userspace stream on `/dev/video0` got through open, buffer
    setup, and queueing
  - `VIDIOC_STREAMON` then failed with `Link has been severed`
  - the raw output file stayed empty
- the later no-reboot userspace format sweep is now completed evidence too:
  - `/dev/video0` through `/dev/video7` all accepted `4096x3072 BA10`
  - all eight nodes still failed `VIDIOC_STREAMON` with
    `Link has been severed`
  - the default `/dev/video0` format mismatch was therefore not sufficient to
    explain the failure
- The strongest remaining gap is no longer basic PMIC `BIT(0)` safety; it is
  now:
  - why `STREAMON` still fails on the positive `exp18` branch after node-side
    format alignment
  - reliable post-boot PMIC dump visibility after a successful sensor bind
  - whether explicit media-pad programming is still missing or the gap is
    deeper in `isys`
  - whether any remaining Antti-parity cleanup is needed only for
    upstreamability, not basic sensor bring-up
  - higher-level Windows config feeding `WF::SetConf` and selecting `WF`
    versus `UF`

## Next Best Steps

1. Use `exp18` as the best current local branch when resuming.
   - standard `VSIO` now reads back cleanly as `0x03`
   - the old timeout storm does not return
   - the media graph now contains `ov5675 10-0036`
2. Treat `exp19` as completed evidence.
   - `/dev/video0` opened and queued buffers successfully
   - `VIDIOC_STREAMON` failed with `Link has been severed`
   - the raw output file stayed empty
3. Treat the no-reboot `4096x3072 BA10` sweep across `/dev/video0` through
   `/dev/video7` as completed negative evidence too.
   - all eight nodes accepted `VIDIOC_S_FMT`
   - all eight nodes still failed `VIDIOC_STREAMON`
4. Investigate whether the remaining severed-link failure needs explicit
   media-pad programming or reflects a deeper `isys` capture-path gap.
5. Treat `exp12` as completed collision evidence, not as a clean Antti-model
   test.
   - it proved the current `GPIO1` / `GPIO2` lookup immediately overrides
     daisy-chain setup
6. Treat `exp13` as completed evidence, not as the next branch to run.
   - it proved Linux can leave `GPIO1` / `GPIO2` in daisy-chain input mode
   - it did not improve the repeated `-121` chip-ID failure
7. Treat `exp14` as completed evidence, not as the next branch to run.
   - it proved `GPIO9` is active
   - it also proved `GPIO9` alone is insufficient
8. Treat `exp15` as completed evidence, not as the next branch to run.
   - it proved `GPIO7` is active
   - it also proved `GPIO7` alone is insufficient
9. Treat `exp16` as completed evidence, not as the next branch to run.
   - it proved the current two-line approximation drives both remote lines
   - it also proved the clean remote-line branch still stays flat at `-121`
10. Treat `exp17` as completed evidence, not as a future branch.
   - it proved one late `S_I2C_CTL BIT(0)` write is safe on the clean
     remote-line branch
   - the observed PMIC write moved `S_I2C_CTL` from `0x02` to `0x03`
   - the sensor still stayed flat at `-121`
11. Treat `exp18` as completed positive evidence.
   - standard `VSIO` enable read back cleanly as `0x03`
   - the old timeout storm did not return
   - the media graph now contains `ov5675 10-0036`
11. Treat the post-boot PMIC dump path as secondary to the new `STREAMON`
    failure until the capture-path result is understood.
12. Fix or replace the post-boot PMIC dump path so we can observe real register
   state after a successful sensor bind.
13. Extract more of the higher-level Windows config path above `WF::SetConf`.
14. Do not rerun the broad `exp7` snapshot patch as a default path; it amplified
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
  - `scripts/04-userspace-capture-check.sh`
  - `scripts/exp19-ms13q3-userspace-capture-validation-update.sh`
  - `scripts/exp19-ms13q3-userspace-capture-validation-verify.sh`
- Complete March 9 report:
  - `docs/20260309-status-report.md`
- Short live status:
  - `docs/webcam-status.md`
- Windows PMIC analysis:
  - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - `docs/wf-vs-uf-gpio-analysis.md`

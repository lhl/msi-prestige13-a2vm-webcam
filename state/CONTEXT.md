# Context

Updated: 2026-03-09

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
- the current clean-boot blocker is still:
  - `chip id read attempt 1/5 failed: -110`
  - `...`
  - `chip id read attempt 5/5 failed: -110`
  - `failed to find sensor: -110`
  - `probe with driver ov5675 failed with error -110`
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
- the post-boot PMIC dump path is still not usable:
  - `scripts/pmic-reg-dump.sh` returned `ERROR` for all registers in
    representative PMIC experiment runs

## Current Interpretation

- We are past the broad platform-support and board-data stage.
- We are at the hard last-mile stage where the sensor exists but never wakes
  enough to answer chip-ID reads.
- Simple GPIO label / polarity / release-order guesses are mostly exhausted.
- The strongest remaining gap is PMIC-side behavior Linux still does not model
  correctly, especially around:
  - `S_I2C_CTL` `0x43` as the first operation that wedges PMIC readback
  - PMIC value/register state truth during the failing identify window
  - higher-level Windows config feeding `WF::SetConf` and selecting `WF`
    versus `UF`

## Next Best Steps

1. Run the split-step PMIC follow-up that keeps the `0x43` signal but separates
   the Windows-like IO-side and GPIO-side updates:
   - immediate next wrapper:
     - `scripts/exp9-s-i2c-ctl-split-step-trace-update.sh`
     - reboot
     - `scripts/exp9-s-i2c-ctl-split-step-trace-verify.sh`
2. Fix or replace the post-boot PMIC dump path so we can observe real register
   state after a failed clean boot.
3. Extract more of the higher-level Windows config path above `WF::SetConf`.
4. Do not rerun the broad `exp7` snapshot patch as a default path; it amplified
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

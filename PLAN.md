# Webcam Bring-Up Plan

Updated: 2026-03-09

This is the active plan after the completed March 9 PMIC experiment batch.

## Goal

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG,
or reduce the remaining blocker to a specific upstream patch or vendor-only gap
with strong evidence.

## Current Assessment

- IPU7 core support is present enough to enumerate the Lunar Lake IPU and load
  firmware.
- `OVTI5675:00` is the correct sensor path.
- the current `tested` patch stack is still valid:
  - `ms13q3-int3472-tps68470-v1.patch`
  - `ipu-bridge-ovti5675-v1.patch`
  - `ov5675-serial-power-on-v1.patch`
- what that stack already fixed:
  - the old `No board-data found for this model` failure is gone
  - `ipu-bridge` now finds `OVTI5675:00`
  - the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
- the current remaining clean-boot blocker is stable and narrow:
  - `chip id read attempt 1/5 failed: -110`
  - `...`
  - `chip id read attempt 5/5 failed: -110`
  - `failed to find sensor: -110`
  - `probe with driver ov5675 failed with error -110`
- completed negative branches:
  - `GPIO1` / `GPIO2` role swap
  - both one-line polarity variants
  - staged `ov5675` GPIO release `sequence=1`
  - staged `ov5675` GPIO release `sequence=2`
  - staged `ov5675` GPIO release control `sequence=0`
  - `exp3` `VD = 1050 mV`
  - `exp5` `WF` GPIO mode follow-up
  - `exp6` `UF` / `gpio.4` last resort
- completed high-signal PMIC findings:
  - `exp1` proved the clock path is real, not a dummy fallback
  - `exp2` reached the staged `S_I2C_CTL` path, but readback stayed `0x00`
    and unwind hit `VSIO: failed to disable: -ETIMEDOUT`
  - `exp4` proved a `WF::Initialize`-style value-programming hook executed,
    but that alone still did not wake the sensor
- current leading interpretation:
  - the remaining gap is PMIC-side behavior, not basic platform support
  - we are missing either exact PMIC control behavior, exact runtime
    conditions, or exact sensor control waveform truth

## Workstreams

### 1. PMIC state truth

- [ ] Instrument raw PMIC regmap activity around:
  - `S_I2C_CTL` `0x43`
  - `VSIOVAL` `0x40`
  - `VAVAL` `0x41`
  - `VDVAL` `0x42`
  - `VACTL` `0x47`
  - `VDCTL` `0x48`
- [ ] Log write intent, raw return code, and readback result for the PMIC
  operations that matter on this board.
- [ ] Capture the unwind path as carefully as the enable path so failures such
  as the `exp2` `VSIO` disable timeout can be interpreted.

### 2. Post-boot PMIC visibility

- [ ] Determine why `scripts/pmic-reg-dump.sh` still returns `ERROR` for every
  register after boot even though the kernel can identify the PMIC.
- [ ] Decide whether the fix is:
  - corrected userspace access path
  - different bus / timing assumptions
  - or a kernel-side debug dump instead of `i2cget`

### 3. Windows config-path extraction

- [ ] Recover more of the code above `WF::SetConf` so the source of the
  five-value tuple is clearer.
- [ ] Recover the runtime conditions that choose the `WF` versus `UF` path on
  this laptop.
- [ ] Determine whether a board-specific config blob or policy object exists in
  the Windows driver path that Linux does not model yet.

### 4. Patch design

- [ ] Use the PMIC instrumentation plus improved Windows reconstruction to
  decide whether a second PMIC behavior patch batch is justified.
- [ ] Avoid blind GPIO-only follow-ups unless new evidence makes one credible.
- [ ] Keep full kernel rebuilds as fallback only when module-local iteration is
  no longer enough.

## Near-Term Priority

1. Treat the completed March 9 PMIC batch as the new baseline, not as pending
   work.
2. Do not spend more time on pure GPIO permutations for now.
3. Put the next experiment budget into:
   - raw PMIC regmap instrumentation
   - repairing PMIC readback visibility
   - deeper Windows config-path extraction
4. Keep using:
   - `scripts/patch-kernel.sh`
   - `scripts/exp*-*-update.sh`
   - `scripts/exp*-*-verify.sh`
   - `scripts/01-clean-boot-check.sh`
   to keep evidence reproducible

## Open Questions

- Why does the Linux `exp2` staged `S_I2C_CTL` path read back `0x00` even
  though the helper path runs?
- Why does userspace PMIC register dumping fail completely after boot when the
  kernel can still log `TPS68470 REVID: 0x21`?
- What exact higher-level Windows configuration feeds `WF::SetConf` on this
  laptop?
- What exact conditions choose `WF` versus `UF` in the Windows power path?
- Are we missing one more PMIC-side control write, or are we missing the exact
  electrical timing on reset / powerdown?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- a full March 9 status report under `docs/`
- reference-backed Windows PMIC notes under `reference/windows-driver-analysis/`
- current support summary under `docs/webcam-status.md`
- if feasible, the next patch-ready note for tighter PMIC instrumentation

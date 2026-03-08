# Context

Updated: 2026-03-08

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
- Current session id at this checkpoint:
  - `019cc8a9-ae0e-7dc0-9b99-c293ea51b666`
  - resume directly with:
    - `codex resume 019cc8a9-ae0e-7dc0-9b99-c293ea51b666`

## Current State

- IPU7 core support is present and firmware loads.
- `OVTI5675:00` is the correct sensor path.
- The validated `tested` patch stack is:
  - `ms13q3-int3472-tps68470-v1.patch`
  - `ipu-bridge-ovti5675-v1.patch`
  - `ov5675-serial-power-on-v1.patch`
- What those three patches already fixed:
  - the old `No board-data found for this model` failure is gone
  - `ipu-bridge` now finds `OVTI5675:00` and reports one connected camera
  - the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
- Current clean-boot blocker:
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`
  - `ov5675` remains unbound
  - there are still no `/dev/v4l-subdev*` nodes

## Latest Negative Result

- The first `candidate` follow-up,
  `reference/patches/ov5675-powerdown-followup-v1.patch`, was tested on a
  clean boot.
- Run directory:
  - `runs/2026-03-08/20260308T160828-snapshot-powerdown-v1/`
- High-value lines:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`
- Conclusion:
  - consuming `powerdown` alone did not move the failure forward

## Next Best Steps

1. Keep using `scripts/patch-kernel.sh` to make the local patch stack
   repeatable.
2. Decide the next smallest module-only follow-up:
   - remaining GPIO semantics or polarity around the second control line
   - extra post-power-on delay before chip-ID read
   - board-data regulator consumer or sequencing detail
3. Re-test every small patch with a clean boot:
   - `scripts/01-clean-boot-check.sh --label ... --note ...`
4. Keep full kernel rebuilds as a fallback only when a change stops being
   module-local.

## Key Paths

- Local kernel package root:
  - `~/.cache/paru/clone/linux-mainline`
- Cached bare kernel repo:
  - `~/.cache/paru/clone/linux-mainline/linux-mainline`
- Editable kernel worktree:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
- Patch-stack workflow:
  - `docs/patch-kernel-workflow.md`
  - `scripts/patch-kernel.sh`
- Module-only rebuild/install workflow:
  - `docs/module-iteration.md`
- Current technical status:
  - `docs/webcam-status.md`

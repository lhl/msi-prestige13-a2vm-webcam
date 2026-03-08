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

## Latest Debug Result

- Installed the identify-debug `ov5675` module build and ran:
  - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/`
- High-value lines since reload:
  - `ov5675 i2c-OVTI5675:00: setup of GPIO reset failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to get reset-gpios: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Conclusion:
  - the debug module is installed and the reload wrapper works
  - but reload-after-failure still dies before chip-ID reads
  - the next trustworthy debug test must apply the module parameters on first
    load at clean boot

## Next Best Steps

1. Keep using `scripts/patch-kernel.sh` to make the local patch stack
   repeatable.
2. Apply the identify-debug module parameters on first load at clean boot.
   - easiest path:
     - temporary `modprobe.d` override:
       - `options ov5675 identify_retry_count=5 identify_retry_delay_us=2000 extra_post_power_on_delay_us=0`
   - then capture with:
     - `scripts/01-clean-boot-check.sh --label identify-debug-v1-boot`
3. Use that clean-boot debug result to decide whether the next real fix is:
   - remaining GPIO semantics or polarity
   - extra post-power-on timing
   - board-data regulator consumer or sequencing detail
4. Keep clean-boot checkpoints as the primary truth source and treat
   reload-only debug checks as secondary once the boot-time path has already
   failed.

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

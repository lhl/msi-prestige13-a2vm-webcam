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
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
  - `ov5675` remains unbound
  - there are still no `/dev/v4l-subdev*` nodes

## Latest Debug Result

- Clean boot with identify-debug module parameters active on first load:
  - `identify_retry_count=5`
  - `identify_retry_delay_us=2000`
  - `extra_post_power_on_delay_us=0`
- High-value boot lines:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Conclusion:
  - the clean-boot identify-debug run replaced the old ambiguous `-5` result
    with the real remaining sensor-side error
  - `ov5675_identify_module()` is reached, but every chip-ID read times out
    with `-110`
  - the next likely patch space is now `GPIO1` / `GPIO2` semantics, polarity,
    or remaining PMIC wake-up sequencing, not mere identify retries
  - the newer Windows-helper analysis does show a separate `UF` path that
    touches what Linux would call `gpio.4`, but current ACPI evidence still
    keeps this laptop aligned with the `WF` / `LNK0` path

## Next Best Steps

1. Keep using `scripts/patch-kernel.sh` to make the local patch stack
   repeatable.
2. Use the clean-boot `-110` identify timeout as the new baseline.
3. Next fix candidates to test:
   - `GPIO1` / `GPIO2` role swap
   - `GPIO1` / `GPIO2` polarity variants
   - board-data regulator consumer or sequencing detail
   - deeper `WF`-side PMIC or sensor wake-up sequencing from the Windows path
4. Do not jump to a `gpio.4` / `UF` redesign first:
   - Windows supports both helper families
   - local ACPI still favors `WFCS -> LNK0`
5. Keep clean-boot checkpoints as the primary truth source. Reload-only checks
   are still secondary once the boot-time path has already failed.

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
- `WF` vs `UF` Windows helper analysis:
  - `docs/wf-vs-uf-gpio-analysis.md`

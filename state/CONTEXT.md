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
  - the `gpio-swap-v1` clean-boot run did not change that pattern
  - the three staged `ov5675` GPIO-release clean boots from `2026-03-09` also
    did not change that pattern:
    - `sequence=1`, `delay_us=2000`
    - `sequence=2`, `delay_us=2000`
    - control `sequence=0`
  - the latest Windows-source pull now shows concrete `WF` PMIC behavior that
    Linux does not yet model:
    - default/configured voltage tuple `1050 / 2800 / 1800 / 2800 / 1800`
    - PMIC value-register writes `0x41`, `0x40`, `0x42`, `0x3c`, `0x3f`
    - staged `S_I2C_CTL` handling around register `0x43`
- The repo now also has scripted update/reboot/verify wrappers for the six
  ordered PMIC follow-ups:
  - `scripts/exp1-pmic-instrumentation-update.sh`
  - `scripts/exp2-wf-s-i2c-ctl-update.sh`
  - `scripts/exp3-ms13q3-vd-1050mv-update.sh`
  - `scripts/exp4-wf-init-value-programming-update.sh`
  - `scripts/exp5-wf-gpio-mode-followup-update.sh`
  - `scripts/exp6-uf-gpio4-last-resort-update.sh`

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
- Clean boot with the `INT3472` `GPIO1` / `GPIO2` role-swap follow-up:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `... 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Clean boot with the first polarity follow-up
  (`GPIO2` `powerdown` => `GPIO_ACTIVE_HIGH`):
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `... 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Clean boot with the second polarity follow-up
  (`GPIO1` `powerdown` => `GPIO_ACTIVE_HIGH`):
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
  - `... 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Clean boot with staged `ov5675` GPIO release `sequence=1`,
  `delay_us=2000`:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: applying gpio release sequence=1 delay_us=2000`
  - `... 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Clean boot with staged `ov5675` GPIO release `sequence=2`,
  `delay_us=2000`:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `ov5675 i2c-OVTI5675:00: applying gpio release sequence=2 delay_us=2000`
  - `... 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Clean boot with control `ov5675` GPIO release `sequence=0`:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `... 5/5 failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`
- Conclusion:
  - the clean-boot identify-debug run replaced the old ambiguous `-5` result
    with the real remaining sensor-side error
  - `ov5675_identify_module()` is reached, but every chip-ID read times out
    with `-110`
  - the clean-boot `gpio-swap-v1` run was negative and also clarified that
    pure label swaps are low-signal with the current `ov5675` power sequence,
    because both control lines are driven in lockstep
  - the first one-line polarity follow-up on `GPIO2` was also negative
  - the second one-line polarity follow-up on `GPIO1` was also negative
  - the three staged `ov5675` GPIO-release clean boots were also negative
  - the latest Windows-source pull now shows that Linux still lacks some
    `WF`-side PMIC behavior:
    - value-register programming
    - staged `S_I2C_CTL` handling
    - possibly the correct `VD` / `CORE` voltage assumption
  - the next likely patch space is now PMIC-side `WF` modeling, not another
    `ov5675`-only GPIO release variation
  - the newer Windows-helper analysis does show a separate `UF` path that
    touches what Linux would call `gpio.4`, but current ACPI evidence still
    keeps this laptop aligned with the `WF` / `LNK0` path

## Next Best Steps

1. Keep using `scripts/patch-kernel.sh` to make the local patch stack
   repeatable.
2. Use the clean-boot `-110` identify timeout as the new baseline.
3. Treat the staged `ov5675` GPIO-release runs as negative:
   - `sequence=1`, `delay_us=2000`
   - `sequence=2`, `delay_us=2000`
   - control `sequence=0`
4. Next fix candidates to test:
   - `WF` value-register programming
   - staged `S_I2C_CTL` handling
   - current Linux `CORE` / `VD` voltage assumptions
5. Use the matching `scripts/exp*-*-update.sh` and `scripts/exp*-*-verify.sh`
   wrappers to keep those follow-ups repeatable across patching, module
   install, reboot, and clean-boot verification.
6. Do not jump to a `gpio.4` / `UF` redesign first:
   - Windows supports both helper families
   - local ACPI still favors `WFCS -> LNK0`
7. Keep clean-boot checkpoints as the primary truth source. Reload-only checks
   are still secondary once the boot-time path has already failed.
8. Keep the latest Windows-source artifacts close at hand:
   - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
   - `docs/wf-vs-uf-gpio-analysis.md`

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
- PMIC experiment workflow:
  - `docs/pmic-followup-experiments.md`
  - `scripts/lib-experiment-workflow.sh`
  - `scripts/exp1-pmic-instrumentation-update.sh`
  - `scripts/exp2-wf-s-i2c-ctl-update.sh`
  - `scripts/exp3-ms13q3-vd-1050mv-update.sh`
  - `scripts/exp4-wf-init-value-programming-update.sh`
  - `scripts/exp5-wf-gpio-mode-followup-update.sh`
  - `scripts/exp6-uf-gpio4-last-resort-update.sh`
- Windows `WF` power-path note:
  - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
- Next module-only sequencing follow-up:
  - `docs/ov5675-gpio-release-sequencing-followup.md`
  - `docs/int3472-gpio1-powerdown-active-high-followup.md`
  - `docs/int3472-gpio-polarity-followup.md`
  - `docs/int3472-gpio-swap-followup.md`

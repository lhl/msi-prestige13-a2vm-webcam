# `INT3472` GPIO Polarity Follow-Up

Updated: 2026-03-09

This note captures the next smallest `INT3472` board-data experiment after the
negative clean-boot `gpio-swap-v1` result.

## Why This Is Next

The clean-boot `gpio-swap-v1` run was useful, but it also exposed an important
limitation in the previous hypothesis:

- current `ov5675_power_on()` drives both control lines in lockstep
- both lines are driven to logical `1` before rail enable
- both lines are driven to logical `0` after the stabilization delay
- both lines return to logical `1` on power-off

That means a pure `reset` / `powerdown` label swap with both lines still
`GPIO_ACTIVE_LOW` is close to a physical no-op.

So the next meaningful electrical change is polarity, not another label-only
swap.

## Current Best Candidate

Patch file:

- `reference/patches/ms13q3-int3472-powerdown-active-high-v1.patch`

Patch shape:

- keep the current tested MSI board-data structure
- keep the original `GPIO1` => `reset`
- keep the original `GPIO2` => `powerdown`
- change only `GPIO2` `powerdown` polarity:
  - from `GPIO_ACTIVE_LOW`
  - to `GPIO_ACTIVE_HIGH`

## Why This Variant First

This is the smallest polarity experiment that materially changes the current
Linux waveform while staying closest to the tested board-data shape.

Reasoning:

- the clean-boot `-110` timeout still happens at chip-ID read time
- Windows and ACPI evidence still keep this laptop on the `WF` / `LNK0` path
- the earlier role-swap result no longer argues for more label-only changes
- in many sensor designs, `reset` is active-low while `powerdown` is the line
  more likely to have board-specific polarity behavior

This is still a hypothesis, not a confirmed wiring map. It is simply the next
best module-local test.

## Validation Result

The candidate is ready for module-only testing:

- `git apply --check` succeeds after applying
  `ms13q3-int3472-tps68470-v1.patch` to a temporary clean kernel tree
- `scripts/patch-kernel.sh --profile candidate --status` reports:
  - `ms13q3-board-data` => `applied`
  - `ipu-bridge-ovti5675` => `applied`
  - `ov5675-serial-power-on` => `applied`
  - `ms13q3-powerdown-active-high` => `applicable`

That status check also confirms the updated patch-stack workflow can handle a
local kernel tree that still has the older superseded `gpio-swap` follow-up in
its working state.

## Expected Signal

Minimum useful success:

- the repeated clean-boot chip-ID read timeouts `-110` disappear
- or the failure moves later and changes shape

Stronger success:

- `ov5675` binds
- `/dev/v4l-subdev*` appears
- the media graph gains the sensor entity

Negative result:

- the clean-boot result is unchanged:
  - repeated chip-ID read timeouts `-110`

If this first polarity variant is negative, the next sensible branch is:

- try the opposite PMIC line as the polarity change target
- or test a dual-line polarity variant

## Patch-Stack Note

The earlier `ms13q3-int3472-gpio-swap-v1.patch` follow-up is now a superseded
negative experiment.

`scripts/patch-kernel.sh` now treats the new polarity patch as the current
`candidate` and is expected to normalize an already-dirty local kernel tree by
reversing the older `gpio-swap` follow-up before applying the new candidate.

## Module-Only Test Flow

User-run commands:

```bash
cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam
scripts/patch-kernel.sh --profile candidate --status
scripts/patch-kernel.sh --profile candidate

cd ~/.cache/paru/clone/linux-mainline/src/linux-mainline
make M=drivers/platform/x86/intel/int3472 modules

zstd -T0 -f \
  drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko \
  -o /tmp/intel_skl_int3472_tps68470.ko.zst

sudo install -Dm644 /tmp/intel_skl_int3472_tps68470.ko.zst \
  /usr/lib/modules/$(uname -r)/kernel/drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko.zst

sudo depmod -a "$(uname -r)"
reboot
```

After reboot:

```bash
cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam
scripts/01-clean-boot-check.sh \
  --label powerdown-active-high-v1 \
  --note "fresh boot after INT3472 powerdown active-high follow-up"
```

## Actual Clean-Boot Result

Run:

- `runs/2026-03-09/20260309T030403-snapshot-powerdown-active-high-v1/focused-summary.txt`

Observed result:

- `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
- `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
- `... 5/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

Additional boot-log detail:

- `ov5675 i2c-OVTI5675:00: cannot find GPIO chip tps68470-gpio, deferring`
- `ov5675 i2c-OVTI5675:00: failed to get reset-gpios: -517`

That early `-EPROBE_DEFER` path is not the final blocker here; probe retries
and still reaches the same clean-boot chip-ID timeout.

Result:

- this first polarity variant is a negative result
- the remaining next smallest physical-line experiment is to move the
  active-high `powerdown`-style behavior onto `GPIO1` instead of `GPIO2`

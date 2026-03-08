# `INT3472` GPIO Swap Follow-Up

Updated: 2026-03-09

This note captures the next smallest Linux-side follow-up after the clean-boot
identify-timeout result.

## Why This Is Next

The current clean-boot baseline already proves that Linux has moved past the
earlier big blockers:

- MSI `INT3472` / `TPS68470` board data is present
- `ipu-bridge` now finds `OVTI5675:00`
- serial rail enable moved the sensor path past the earlier `dvdd` timeout
- `ov5675_identify_module()` is reached

The remaining clean-boot failure is still:

- `chip id read attempt 1/5 failed: -110`
- `... 5/5 failed: -110`

The Windows and ACPI evidence currently still favors the `WF` / `LNK0` path and
PMIC regular `GPIO1` / `GPIO2`, not an immediate `UF` / `gpio.4` redesign.

That makes the smallest plausible next test:

- keep the same two PMIC GPIO lines
- swap only their Linux semantic roles:
  - `GPIO1` => `powerdown`
  - `GPIO2` => `reset`

## Patch Candidate

Patch file:

- `reference/patches/ms13q3-int3472-gpio-swap-v1.patch`

Patch shape:

- only changes the `i2c-OVTI5675:00` GPIO lookup table in
  `tps68470_board_data.c`
- does not change regulator consumers
- does not change voltages
- does not change polarity yet
- does not change `ov5675.c`

This is intentionally narrower than a polarity experiment. The goal is to test
role assignment first, then polarity only if the role swap still fails.

Validation result:

- `git apply --check` succeeds against the current local
  `~/.cache/paru/clone/linux-mainline/src/linux-mainline` tree
- `scripts/patch-kernel.sh --profile candidate --status` currently reports:
  - `ms13q3-gpio-swap` => `applicable`

## Expected Signal

Minimum useful success:

- the clean-boot `-110` chip-ID timeout disappears
- or the failure moves later and changes shape

Stronger success:

- `ov5675` binds
- `/dev/v4l-subdev*` appears
- the media graph gains the sensor entity

Negative result:

- the clean-boot result is unchanged:
  - repeated chip-ID read timeouts `-110`

If this first role-swap test is negative, the next branch should be polarity
variants on the same two GPIO lines before revisiting `UF` / `gpio.4`.

## Module-Only Test Flow

This change is module-local. It only needs the `INT3472` module rebuild and a
clean-boot check.

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
  --label gpio-swap-v1 \
  --note "fresh boot after INT3472 GPIO role swap"
```

## Interpretation Rule

Use the clean-boot checkpoint as the primary truth source.

If the clean-boot result still shows repeated chip-ID read timeouts `-110`,
then this role-swap experiment is a negative result and the next minimal follow
up should be polarity experiments on the same `GPIO1` / `GPIO2` pair.

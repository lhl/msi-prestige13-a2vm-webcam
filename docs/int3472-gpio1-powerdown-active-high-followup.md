# `INT3472` GPIO1 `powerdown` Active-High Follow-Up

Updated: 2026-03-09

This note captures the next smallest physical-line polarity experiment after the
negative `powerdown-active-high-v1` clean-boot result.

## Why This Is Next

The first polarity follow-up tested the current tested-stack line assignment:

- `GPIO1` => `reset`, `GPIO_ACTIVE_LOW`
- `GPIO2` => `powerdown`, `GPIO_ACTIVE_HIGH`

That clean-boot run was negative:

- `OVTI5675:00` was still found
- chip-ID read attempts `1/5` through `5/5` still failed with `-110`
- `ov5675` remained unbound

Because the current `ov5675` power sequence still drives both logical control
descriptors in lockstep, the most meaningful next one-step change is to move
the active-high `powerdown`-style behavior onto the other physical PMIC line.

## Current Best Candidate

Patch file:

- `reference/patches/ms13q3-int3472-gpio1-powerdown-active-high-v1.patch`

Patch shape:

- `GPIO1` => `powerdown`, `GPIO_ACTIVE_HIGH`
- `GPIO2` => `reset`, `GPIO_ACTIVE_LOW`

Electrically, this is the "other PMIC line active-high" variant.

## Why This Variant Is Still Reasonable

This patch combines a label swap with a polarity change, but that is less
significant than it sounds:

- the earlier pure role-swap run was already shown to be low-signal
- the current `ov5675` power-on path drives both logical descriptors together
- so the real probe-time variable is which physical PMIC line gets the
  active-high waveform

That means this patch should be read primarily as a physical-line test, not as
strong evidence that Linux has definitely identified which line is `reset` vs
`powerdown`.

## Validation Result

The candidate is ready for module-only testing:

- `git apply --check` succeeds after applying
  `ms13q3-int3472-tps68470-v1.patch` to a temporary clean kernel tree
- `scripts/patch-kernel.sh --profile candidate --status` reports:
  - `ms13q3-board-data` => `applied`
  - `ipu-bridge-ovti5675` => `applied`
  - `ov5675-serial-power-on` => `applied`
  - `ms13q3-gpio1-powerdown-active-high` => `applicable`

That status check also confirms the updated patch-stack workflow can normalize
both older superseded local states:

- `ms13q3-int3472-gpio-swap-v1.patch`
- `ms13q3-int3472-powerdown-active-high-v1.patch`

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

If this variant is also negative, the next branch should likely be:

- a dual-line polarity experiment
- or a deeper `WF`-side PMIC wake-up / sequencing follow-up

## Patch-Stack Note

The current `candidate` profile in `scripts/patch-kernel.sh` now treats this as
the next follow-up and is expected to normalize two older superseded
experiments if they are still present in the local kernel tree:

- `ms13q3-int3472-gpio-swap-v1.patch`
- `ms13q3-int3472-powerdown-active-high-v1.patch`

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
  --label gpio1-powerdown-active-high-v1 \
  --note "fresh boot after INT3472 GPIO1 powerdown active-high follow-up"
```

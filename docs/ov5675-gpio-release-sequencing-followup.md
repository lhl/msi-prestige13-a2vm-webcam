# `ov5675` GPIO Release Sequencing Follow-Up

Updated: 2026-03-09

This note captures the next module-only debug branch after both one-line
`INT3472` polarity variants proved negative on clean boot.

## Why This Is Next

The latest clean-boot result for the other physical-line polarity variant:

- run:
  - `runs/2026-03-09/20260309T035410-snapshot-gpio1-powerdown-active-high-v1/`
- focused summary:
  - `runs/2026-03-09/20260309T035410-snapshot-gpio1-powerdown-active-high-v1/focused-summary.txt`

Observed result:

- `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
- `intel-ipu7 0000:00:05.0: Connected 1 cameras`
- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
- `... 5/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

That means both one-line physical-line polarity variants are now negative:

- `GPIO2` active-high branch: negative
- `GPIO1` active-high branch: negative

So the next likely gap is no longer which single PMIC line should get the
active-high waveform. The next likely gap is the actual GPIO release timing in
`ov5675_power_on()`.

## Why The Current Linux Sequence Still Looks Simplified

Current Linux `ov5675_power_on()` behavior:

- assert both logical control lines
- enable supplies serially
- wait 2 ms
- release both lines in lockstep
- wait for the settle gap
- attempt chip-ID reads

Recovered Windows `SensorPowerOn` evidence is richer:

- `IoActive_IO`
- a helper branch into `VoltageWF::PowerOn` or `VoltageUF::PowerOn`
- two intermediate calls on the GPIO-control object
- `IoActive_GPIO` afterward

That does not yet prove the exact Linux sequence should be one specific order,
but it does justify testing staged GPIO release as the next module-only
follow-up.

## Patch Candidate

Patch file:

- `reference/patches/ov5675-gpio-release-sequencing-debug-v1.patch`

Patch goals:

- keep the current debug build module-local in `drivers/media/i2c/ov5675.c`
- add a tunable GPIO release strategy after the 2 ms regulator-stability gap
- add a tunable inter-step delay for staged release
- log the chosen strategy on first power-on

New module parameters:

- `gpio_release_sequence`
  - `0` = current behavior, release both lines together
  - `1` = release `powerdown` first, then `reset`
  - `2` = release `reset` first, then `powerdown`
- `gpio_release_delay_us`
  - delay between staged release steps

## Why This Is Better Than Another Board-Data Guess

The last three board-data-space experiments now tell a consistent story:

- label-only role swap was low-signal
- `GPIO2` active-high was negative
- `GPIO1` active-high was also negative

That makes more one-line board-data polarity flips lower value than testing the
actual sequencing in the sensor driver.

This branch is also cheaper:

- one `ov5675.ko` rebuild
- then several clean-boot runs via module parameters
- no additional `INT3472` patch churn unless sequencing also fails

## Expected Signal

Minimum useful success:

- the clean-boot `-110` timeout pattern changes
- or a chip-ID attempt succeeds

Stronger success:

- `ov5675` binds
- `/dev/v4l-subdev*` appears
- the media graph gains the sensor entity

Negative result:

- repeated clean-boot chip-ID read timeouts `-110` remain unchanged across
  staged release variants

If this branch is also negative, the next step should probably be deeper
Windows-side `WF` sequencing analysis rather than more blind GPIO polarity
changes.

## Candidate Stack Note

The repo `candidate` patch profile should now be read as:

- tested support-moving patches
- `ov5675` `powerdown` follow-up
- `ov5675` identify-debug branch
- current GPIO release sequencing debug follow-up

It should also normalize the earlier negative `INT3472` candidate patches out
of a dirty local kernel tree before applying this branch.

## Module-Only Test Flow

User-run commands:

```bash
cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam
scripts/patch-kernel.sh --profile candidate --status
scripts/patch-kernel.sh --profile candidate

cd ~/.cache/paru/clone/linux-mainline/src/linux-mainline
make M=drivers/media/i2c modules

zstd -T0 -f \
  drivers/media/i2c/ov5675.ko \
  -o /tmp/ov5675.ko.zst

sudo install -Dm644 /tmp/ov5675.ko.zst \
  /usr/lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko.zst

sudo depmod -a "$(uname -r)"
```

Then set one clean-boot variant, reboot, and capture it with `01`.

Example first staged-release run:

```bash
printf '%s\n' 'options ov5675 identify_retry_count=5 identify_retry_delay_us=2000 extra_post_power_on_delay_us=0 gpio_release_sequence=1 gpio_release_delay_us=2000' | sudo tee /etc/modprobe.d/ov5675-debug.conf
reboot
```

After reboot:

```bash
cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam
scripts/01-clean-boot-check.sh \
  --label gpio-release-seq1-delay2ms \
  --note "clean boot with ov5675 staged GPIO release"
```

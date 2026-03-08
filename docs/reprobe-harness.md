# Safe Reprobe Harness

Updated: 2026-03-08

This repo now includes a scripted harness for repeatable webcam/IPU probe attempts without raw PMIC register writes or reboot-heavy iteration.

## Script

- `scripts/webcam-run.sh`
- numbered wrappers:
  - `scripts/01-clean-boot-check.sh`
  - `scripts/02-ov5675-reload-check.sh`

## Safety boundary

What this harness does:

- captures the current Linux webcam/IPU/INT3472 state
- records exact step order, timestamps, and command outputs
- optionally unloads and reloads the relevant camera-related kernel modules

What this harness does not do:

- no `i2cset`
- no raw `i2ctransfer` writes
- no `i2cdetect -y` bus scan across addresses
- no direct PMIC register pokes from userland

That keeps it in the low-risk category for repeatable testing while we still do not know the correct MSI-specific `TPS68470` regulator and GPIO sequence.

## Actions

### `snapshot`

Capture-only mode. Safe to run as an unprivileged user.

Example:

```bash
scripts/webcam-run.sh snapshot --label baseline --note "booted kernel 6.18.9-arch1-2"
```

### `reprobe-modules`

Safe reprobe mode. Requires root unless `--dry-run` is used.

The current module sequence is:

1. unload `ov5675`
2. unload `intel_ipu7_isys`
3. unload `intel_ipu7`
4. unload `intel_skl_int3472_tps68470`
5. unload `intel_skl_int3472_discrete`
6. unload `clk_tps68470`
7. unload `tps68470_regulator`
8. unload `intel_skl_int3472_common`
9. reload `intel_skl_int3472_tps68470`
10. reload `intel_skl_int3472_discrete`
11. reload `ov5675`
12. reload `intel_ipu7`
13. reload `intel_ipu7_isys`

Example:

```bash
sudo scripts/webcam-run.sh reprobe-modules \
  --label first-reprobe \
  --note "baseline reprobe after boot"
```

Dry-run example:

```bash
scripts/webcam-run.sh reprobe-modules --dry-run --label review-steps
```

## Run output

By default the harness writes to:

- `runs/YYYY-MM-DD/YYYYMMDDTHHMMSS-<action>-<label>/`

Each run directory contains:

- `action.log` — exact step order and exit statuses
- `summary.env` — final run status and metadata
- `pre/` — pre-action capture
- `post/` — post-action capture

Each capture currently includes:

- git revision and git status
- DMI product/version
- relevant `lsmod` and `modinfo` output
- `/dev/media*`, `/dev/video*`, and `/dev/i2c-*` listing
- `i2cdetect -l`
- `v4l2-ctl --list-devices`
- `media-ctl -p -d /dev/media0`
- `v4l2-ctl --all` for every current `/dev/video*`
- filtered kernel log for webcam/IPU/INT3472 lines
- filtered kernel log delta since the run start
- relevant ACPI/I2C/sysfs snapshots for `INT3472:06`, `OVTI5675:00`, bus `i2c-1`, and the `int3472-tps68470` / `ov5675` drivers

## Analysis workflow

Recommended pattern:

1. run `snapshot` once after boot
2. run `reprobe-modules` for each meaningful experiment
3. compare the `pre/` and `post/` subdirectories
4. commit meaningful run directories together with any resulting notes or conclusions

If a reprobe fails, the run still preserves the exact point of failure in `action.log` plus the post-failure state capture.

## Focused numbered checkpoints

For the current MSI webcam bring-up loop, the numbered wrappers are useful:

1. `scripts/01-clean-boot-check.sh`
   - primary truth source after a reboot
   - adds a focused summary for the current boot
2. `sudo scripts/02-ov5675-reload-check.sh`
   - useful after replacing only `ov5675.ko.zst`
   - adds a focused summary since the reload start time

Those wrappers still create ordinary run directories under `runs/`, so they fit
the same archival workflow as the base harness.

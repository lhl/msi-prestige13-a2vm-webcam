# Numbered Test Routines

Updated: 2026-03-08

These scripts sit on top of `scripts/webcam-run.sh` and provide stable,
numbered checkpoints for the current MSI webcam bring-up workflow.

They are intentionally thin wrappers:

- they still create normal `runs/...` directories
- they add a small `focused-summary.txt` with the highest-value lines for the
  current phase
- they do not replace the full capture harness

## `scripts/01-clean-boot-check.sh`

Use this immediately after a fresh boot into the current test kernel.

What it captures:

- the standard snapshot run
- current high-value boot log lines for:
  - `TPS68470 REVID`
  - `Found supported sensor`
  - `Connected 1 cameras`
  - `Failed to enable`
  - `failed to power on`
  - `failed to find sensor`
  - `probe with driver ov5675 failed`
- binding state for:
  - `i2c-INT3472:06`
  - `i2c-OVTI5675:00`
- current `/dev/v4l-subdev*` nodes

Example:

```bash
scripts/01-clean-boot-check.sh
```

## `scripts/02-ov5675-reload-check.sh`

Use this after replacing `ov5675.ko.zst` during module-only iteration.

What it does:

- unloads and reloads only `ov5675`
- captures a standard snapshot run
- writes a focused summary using journal lines since the reload start

Additional lines tracked here:

- `setup of GPIO reset failed`
- `failed to get reset-gpios`

Example:

```bash
sudo scripts/02-ov5675-reload-check.sh
```

## `scripts/03-ov5675-identify-debug-check.sh`

Use this after installing an `ov5675` build that includes the identify-debug
patch candidate.

What it does:

- unloads and reloads only `ov5675`
- passes explicit identify-debug module parameters:
  - `identify_retry_count`
  - `identify_retry_delay_us`
  - `extra_post_power_on_delay_us`
- captures a standard snapshot run
- writes a focused summary using identify-specific journal lines since reload
  start

Additional lines tracked here:

- `applying extra post-power-on delay`
- `chip id read attempt`
- `chip id attempt`
- `sensor identified on attempt`

Example:

```bash
sudo scripts/03-ov5675-identify-debug-check.sh \
  --identify-retries 5 \
  --identify-retry-delay-us 2000 \
  --extra-delay-us 5000
```

## Current interpretation rule

For this project, `01-clean-boot-check.sh` is the primary truth source.

If a clean boot already wedged the PMIC / I2C path, later reload-only checks
may show secondary fallout such as GPIO acquisition failures. Those reload
results are still useful, but they should not override the clean-boot result.

Current example from this repo:

- clean boot showed:
  - `Failed to enable dvdd: -ETIMEDOUT`
- later reload-only check showed:
  - `setup of GPIO reset failed: -110`
  - `failed to get reset-gpios: -110`

That later GPIO failure is still useful, but it is interpreted as fallout from
the earlier timeout rather than as the primary blocker.

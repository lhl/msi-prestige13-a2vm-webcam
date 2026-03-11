# Numbered Test Routines

Updated: 2026-03-11

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
  - `applying extra post-power-on delay`
  - `chip id read attempt`
  - `chip id attempt`
  - `sensor identified on attempt`
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

For clean-boot identify-debug tests, `01-clean-boot-check.sh` is the primary
checkpoint because it captures the first-load `ov5675` boot log instead of a
later reload-only path.

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
- `setup of GPIO reset failed`
- `failed to get reset-gpios`

Example:

```bash
sudo scripts/03-ov5675-identify-debug-check.sh \
  --identify-retries 5 \
  --identify-retry-delay-us 2000 \
  --extra-delay-us 5000
```

Interpretation note:

- this is still a reload-only narrowing tool
- if the boot-time `ov5675` probe has already wedged the sensor path, a later
  reload may fail earlier at `setup of GPIO reset failed: -110` or
  `failed to get reset-gpios: -110` and never reach chip-ID reads
- when that happens, the next trustworthy test is a clean boot with the debug
  module parameters applied on first load

## `scripts/04-userspace-capture-check.sh`

Use this on the positive `exp18` branch after a clean boot when the media graph
already contains `ov5675 10-0036`.

What it does:

- captures a standard snapshot run
- records the current media graph and one selected `/dev/video*` node
- attempts a raw `v4l2-ctl` streaming capture on that node
- writes a focused summary with:
  - whether the stream command completed, timed out, or failed
  - the raw-output file size
  - the selected media-graph lines
  - the relevant kernel journal lines since the capture attempt started

Default target:

- `/dev/video0`

Example:

```bash
scripts/04-userspace-capture-check.sh --video-device /dev/video0
```

Interpretation note:

- this is the first post-bind userspace checkpoint, not a replacement for the
  clean-boot truth source
- use it only after the kernel already reaches the `exp18` state where:
  - the media graph contains `ov5675 10-0036`
  - `/dev/v4l-subdev0` exists
- if it fails, the failure now narrows the remaining gap to the capture path,
  pipeline configuration, permissions, or userspace behavior rather than first
  sensor wake-up

## Current interpretation rule

For this project, `01-clean-boot-check.sh` is the primary truth source for
boot-time bring-up failures.

Once the sensor already binds into the media graph on `exp18`, the first
capture-phase truth source becomes `04-userspace-capture-check.sh`.

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

## Experiment wrappers

The PMIC-side follow-ups and the first post-bind capture validation experiment
now have matching update/reboot/verify wrappers documented in
`docs/pmic-followup-experiments.md`.

Interpretation rule stays the same:

- the PMIC-side `*-verify.sh` wrappers still use
  `scripts/01-clean-boot-check.sh` as the first capture step
- their extra journal grep and PMIC dump are appended as secondary evidence,
  not as a replacement for the boot-time result
- `exp19` is the first exception:
  - it reuses the positive `exp18` patch
  - its verify wrapper uses `scripts/04-userspace-capture-check.sh`
  - its goal is capture/userspace validation, not another PMIC state question

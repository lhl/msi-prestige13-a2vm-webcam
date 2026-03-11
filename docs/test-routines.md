# Numbered Test Routines

Updated: 2026-03-12

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

## `scripts/05-userspace-format-sweep.sh`

Use this after `scripts/04-userspace-capture-check.sh` shows a
`VIDIOC_STREAMON` severed-link failure and you want one repeatable no-reboot
check for whether explicit capture-node format alignment changes the result.

What it does:

- captures a standard snapshot run
- records the current media graph once for the whole sweep
- sweeps selected `/dev/video*` nodes
- for each selected node:
  - records before/after `v4l2-ctl --all`
  - records `--list-formats-ext`
  - attempts one explicit `--set-fmt-video` plus raw stream capture
- writes one focused summary with:
  - the requested format for the whole sweep
  - per-node raw-output sizes
  - per-node `VIDIOC_S_FMT` / `VIDIOC_STREAMON` result lines
  - the relevant kernel journal lines since the sweep started

Default targets:

- `/dev/video0` through `/dev/video7`
- width `4096`
- height `3072`
- pixel format `BA10`

Example:

```bash
scripts/05-userspace-format-sweep.sh
```

Interpretation note:

- this is the first repeatable no-reboot follow-up after `exp19`
- if all tested nodes accept `VIDIOC_S_FMT` to `4096x3072 BA10` but still fail
  `VIDIOC_STREAMON`, the simple default `/dev/video0` format mismatch is ruled
  out as the main explanation
- when that happens, the next remaining userspace question is explicit
  media-pad programming versus a deeper `isys` capture-path gap

## `scripts/06-media-pipeline-setup.sh`

Use this after `scripts/05-userspace-format-sweep.sh` proves that node-side
format alignment alone is insufficient, and you want to test whether explicit
`media-ctl` route, link, and format setup removes the `VIDIOC_STREAMON`
severed-link failure.

For causal pre/post evidence, run it immediately after a fresh boot before any
manual `media-ctl` or `v4l2-ctl` commands.

What it does:

- captures a standard snapshot run
- records the pre-setup media graph
- attempts five pipeline setup steps in order:
  1. route on CSI2 subdev (may return `ENOTSUP` on IPU7 -- that is OK)
  2. CSI2 sink pad format to match sensor output
  3. CSI2 source pad format to match sensor output
  4. link enable from CSI2 source pad to capture node
  5. video node format to match sensor output
- records each setup command result (exit status and output)
- records the post-setup media graph
- attempts a raw `v4l2-ctl` streaming capture
- writes a focused summary with all step results

Default targets:

- `/dev/video0`
- sensor format `SGRBG10_1X10/2592x1944`
- pixel format `BA10`

Example:

```bash
scripts/06-media-pipeline-setup.sh
```

Interpretation note:

- this is the first no-reboot follow-up that actually achieved successful raw
  Bayer capture
- the latest clean-boot rerun proved the true defaults are:
  - `Intel IPU7 CSI2 0` at `SGRBG10_1X10/4096x3072`
  - `CSI2:1 -> Intel IPU7 ISYS Capture 0` disabled
- the route step (`media-ctl -R`) returns `ENOTSUP` on IPU7 CSI2 entities;
  this is expected and does not prevent streaming
- the critical step is link enable (step 4); without it, `STREAMON` fails with
  `Link has been severed`
- 5x `csi2-0 error: Received packet is too long` warnings may appear during
  capture; frames still arrive
- current geometry clue: `bytesused` is `10,077,696` but `Size Image` is
  `10,082,880`, a `5,184`-byte delta equal to one scanline at the current
  `Bytes per Line`

## `scripts/07-normal-usage-check.sh`

Use this after `scripts/06-media-pipeline-setup.sh` proves the raw manual path
works and you want a repeatable answer about whether normal userspace clients
can consume frames from the same configured state.

What it does:

- captures a standard snapshot run
- records higher-level tool presence for:
  - `ffmpeg`
  - `gst-launch-1.0`
  - `mpv`
  - `cheese`
  - `libcamera-*` / `cam`
- applies the known-good `06` media-pipeline setup
- verifies the raw base path again with one `v4l2-ctl` sanity capture
- re-applies the working node/link/format state before each client probe
- runs headless higher-level probes for installed CLI tools:
  - `ffmpeg`
  - `gst-launch-1.0`
  - `mpv`
- records GUI/manual-only follow-up notes for tools not suitable for headless
  automation
- writes one focused summary with the overall normal-usage verdict

Default targets:

- `/dev/video0`
- sensor format `SGRBG10_1X10/2592x1944`
- pixel format `BA10`

Example:

```bash
scripts/07-normal-usage-check.sh
```

Interpretation note:

- this is the current higher-level client compatibility truth source
- the first recorded run:
  - `runs/2026-03-12/20260312T021942-snapshot-07-normal-usage-check/`
  - still showed raw `v4l2-ctl` success after manual setup
  - but it proved the normal-usage gap remains:
    - `ffmpeg`: `ioctl(VIDIOC_STREAMON): Broken pipe`
    - `mpv`: same `Broken pipe` path via FFmpeg's V4L2 demuxer
    - `gst-launch-1.0`: buffer-pool activation failed, then
      `reason not-negotiated (-4)`
    - `libcamera-*` / `cam`: missing on this machine
    - `cheese`: present, but not auto-run because it needs an interactive GUI
- use this script when you change client-facing behavior, not when you are only
  narrowing raw pipeline state

## `scripts/08-userspace-bridge-check.sh`

Use this after `scripts/07-normal-usage-check.sh` proves that normal
auto-negotiated clients still fail, and you want to distinguish between:

- direct standard-pixel client failure
- framework-level raw Bayer consumption
- framework-level Bayer-to-RGB bridging

What it does:

- captures a standard snapshot run
- records the current V4L2 and FFmpeg format inventory for the selected node
- re-applies the known-good `06` setup before each probe cluster
- verifies the raw `BA10` base path again with `v4l2-ctl`
- tests an advertised app-friendly node format directly (`YUYV` by default)
- tests the current auto-negotiated higher-level paths again:
  - `ffmpeg` default V4L2 input
  - GStreamer `v4l2src ! fakesink`
- tests explicit format/caps bridge paths:
  - `ffmpeg` explicit `yuyv422`
  - GStreamer explicit `video/x-raw,format=YUY2`
  - GStreamer explicit `video/x-bayer,format=grbg10le`
  - GStreamer `video/x-bayer ! bayer2rgb ! videoconvert`
  - GStreamer Bayer-to-JPEG export when `jpegenc` is available
- writes one focused summary that says whether the remaining gap is:
  - raw delivery
  - direct standard-pixel streaming
  - or only auto-negotiation / integration

Default targets:

- `/dev/video0`
- working raw format `BA10`
- tested standard-pixel format `YUYV`
- GStreamer Bayer caps format `grbg10le`

Example:

```bash
scripts/08-userspace-bridge-check.sh
```

Interpretation note:

- this is the current explicit userspace-bridge truth source
- the first recorded run:
  - `runs/2026-03-12/20260312T032317-snapshot-08-userspace-bridge-check/`
  - kept the same raw `BA10` success from `06`
  - proved the advertised direct `YUYV` path still fails at `STREAMON`
  - proved `ffmpeg` marks the 10-bit Bayer formats unsupported on this V4L2
    path even though it lists `uyvy422`, `yuyv422`, `rgb565le`, and `bgr24`
  - proved GStreamer can succeed when explicit Bayer caps are forced:
    - `video/x-bayer,format=grbg10le,width=2592,height=1944,framerate=30/1`
    - `bayer2rgb` + `videoconvert` also succeeds
    - a normal `2592x1944` JPEG artifact can be emitted from the same path
- the resulting boundary is now sharper:
  - raw sensor delivery works
  - a framework-level Bayer bridge exists
  - normal plug-and-play client integration still does not

## `scripts/09-libcamera-loopback-check.sh`

Use this after `scripts/08-userspace-bridge-check.sh` proves the explicit
GStreamer Bayer bridge works and you want one repeatable checkpoint for the
two next app-facing integration routes:

- `libcamera`
- `v4l2loopback`

What it does:

- captures a standard snapshot run
- re-validates the known-good raw `BA10` path from script `06`
- records tool and module presence for:
  - `cam`
  - `libcamera-hello`
  - `libcamera-still`
  - `libcamera-vid`
  - `modinfo`
  - `lsmod`
  - GStreamer bridge prerequisites
- probes the `libcamera` path if tools are present:
  - discovery commands
  - one minimal still-capture path
- probes the `v4l2loopback` path if a loopback device exists:
  - loopback node inspection
  - explicit GStreamer Bayer-to-loopback producer
  - consumer probes against the loopback node
- writes one focused summary that separates:
  - raw base-path status
  - `libcamera` readiness
  - `v4l2loopback` readiness

Default targets:

- raw source node `/dev/video0`
- recommended loopback node `/dev/video42`
- bridge output format `YUY2`

Example:

```bash
scripts/09-libcamera-loopback-check.sh
```

Interpretation note:

- this is the current next-step integration truth source
- the first recorded run:
  - `runs/2026-03-12/20260312T033726-snapshot-09-libcamera-loopback-check/`
  - kept the same raw `BA10` success from `06`
  - proved the current machine is still prerequisite-negative for both next
    integration paths:
    - `cam`, `libcamera-hello`, `libcamera-still`, and `libcamera-vid` are
      missing
    - `modinfo v4l2loopback` returns `Module v4l2loopback not found`
    - no loopback `/dev/video*` node exists
  - records exact rerun prerequisites:
    - install `libcamera` tools, then rerun
    - create a loopback node, for example:
      - `sudo modprobe v4l2loopback video_nr=42 card_label="MSI Webcam Bridge" exclusive_caps=1`
      - then rerun `scripts/09-libcamera-loopback-check.sh --loopback-device /dev/video42`
- the current best positive run:
  - `runs/2026-03-12/20260312T040735-snapshot-09-libcamera-loopback-check/`
  - kept the same raw `BA10` base-path success
  - proved the `v4l2loopback` route is now consumer-facing when `/dev/video42`
    exists
  - `ffmpeg` consumed `/dev/video42` successfully as `yuyv422`
  - GStreamer `v4l2src device=/dev/video42 ! fakesink` also succeeded
- use this script when you change the environment around `libcamera` or
  `v4l2loopback`, not when you are only narrowing the raw `isys` path

## Current interpretation rule

For this project, `01-clean-boot-check.sh` is the primary truth source for
boot-time bring-up failures.

Once the sensor already binds into the media graph on `exp18`, the first
capture-phase truth source becomes `04-userspace-capture-check.sh`.

If `04-userspace-capture-check.sh` then fails at `VIDIOC_STREAMON` while the
media graph still looks healthy, the next no-reboot discriminator becomes
`05-userspace-format-sweep.sh`.

Once `06-media-pipeline-setup.sh` proves the raw manual path works, the next
truth source for "can normal clients use it automatically?" becomes
`07-normal-usage-check.sh`.

Once `07-normal-usage-check.sh` proves auto-negotiated clients still fail, the
next truth source for "is there at least an explicit higher-level bridge?"
becomes `08-userspace-bridge-check.sh`.

Once `08-userspace-bridge-check.sh` proves the explicit Bayer bridge works, the
next truth source for "which app-facing integration path is actually ready?"
becomes `09-libcamera-loopback-check.sh`.

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
- the later no-reboot format follow-up is intentionally outside the
  update/reboot experiment wrappers:
  - use `scripts/05-userspace-format-sweep.sh`
  - it is meant to run on the already-booted positive branch without another
    kernel change

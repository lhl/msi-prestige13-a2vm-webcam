# Webcam Usage Guide

MSI Prestige 13 AI+ Evo A2VMG — Linux webcam on the cleaned upstream 6-patch
series (current local runtime validation: `7.0.0-rc2-1-mainline-dirty`).

## Prerequisites

- Kernel with the cleaned upstream 6-patch series booted
- `libcamera` 0.7.0+, `libcamera-ipa`, `libcamera-tools` (for `cam`)
- `pipewire-libcamera` (PipeWire camera integration)
- `media-ctl`, `v4l2-ctl` (from `v4l-utils`)
- Optional: `gstreamer` + `gst-plugins-bad` (for `bayer2rgb` preview script)
- Optional: `v4l2loopback-dkms` (for apps that need a standard V4L2 device)

## Quick Start (libcamera + PipeWire)

This is the recommended path. libcamera handles media pipeline setup,
debayering (GPU-accelerated via EGL), and auto-exposure automatically.
PipeWire exposes the camera to browsers and apps.

### Verify the camera is detected

```bash
cam -l
# Expected: "1: Internal front camera (\_SB_.LNK0)"
```

### Verify PipeWire sees it

```bash
wpctl status | grep -A5 "Video"
# Expected: "ov5675 [libcamera]" device and "Built-in Front Camera" source
```

If PipeWire does not list it, restart PipeWire after installing
`pipewire-libcamera`:

```bash
systemctl --user restart pipewire
```

### Test capture

```bash
cam -c1 --capture=5
```

Once PipeWire sees the camera, browsers and apps that use the PipeWire camera
portal will discover it as "Built-in Front Camera" — no bridge or manual
pipeline setup needed.

## Browser Setup

Browser webcam support on Linux goes through PipeWire and the XDG Desktop
Portal:

```
Browser -> xdg-desktop-portal -> PipeWire -> libcamera -> ov5675
```

### Chrome / Chromium

PipeWire camera support must be enabled manually:

1. Open `chrome://flags/#enable-webrtc-pipewire-camera`
2. Set **"PipeWire Camera support"** to **Enabled**
3. Relaunch Chrome

The camera appears as "Built-in Front Camera" in site permission prompts and
`chrome://settings/content/camera`.

### Firefox

Firefox has PipeWire camera support via the `media.webrtc.camera.allow-pipewire`
pref in `about:config`.

On this machine, Firefox `148.0` still needed that pref set explicitly.
Without it, Firefox enumerated a long list of raw `ipu7` V4L2 nodes instead of
the single working PipeWire/libcamera camera.

Set it manually:

1. Open `about:config`
2. Search for `media.webrtc.camera.allow-pipewire`
3. Set it to `true`
4. Fully restart Firefox

Expected result:

- Firefox should expose the same PipeWire camera Chrome uses:
  `Built-in Front Camera`
- it should stop listing the non-working raw `ipu7` nodes as webcam choices

## Exposure and Gain Control

libcamera's SoftwareISP provides basic auto-exposure (range 4-2016, gain
1-15.99) using the `uncalibrated.yaml` IPA profile. This means brightness
should adjust automatically when using the camera through libcamera/PipeWire.

For manual control (e.g., via the GStreamer preview script), the sensor controls
are on `/dev/v4l-subdev4`:

| Control | Min | Max | Default | Notes |
|---------|-----|-----|---------|-------|
| exposure | 4 | 2016 | 2016 | Already at max by default |
| analogue_gain | 128 | 2047 | 128 | Main brightness control |
| digital_gain | 1024 | 4095 | 1024 | Additional software gain |
| vertical_blanking | 76 | 30823 | 76 | Affects max exposure range |
| horizontal_flip | 0 | 1 | 0 | |
| vertical_flip | 0 | 1 | 0 | |

```bash
# Manual gain adjustment (for the GStreamer preview script)
v4l2-ctl -d /dev/v4l-subdev4 -c analogue_gain=800
v4l2-ctl -d /dev/v4l-subdev4 -c digital_gain=2048
```

## GStreamer Preview Script (alternative)

The `scripts/webcam-preview.sh` script provides a standalone GStreamer-based
path that does not require libcamera. It does CPU-based debayering and has
no auto-exposure — manual gain control is required. It also uses significant
CPU power (~7W additional), so it is not suitable as a permanent background
bridge.

```bash
# Live preview window
./scripts/webcam-preview.sh --gain 800

# Single JPEG capture
./scripts/webcam-preview.sh --snapshot photo.jpg

# v4l2loopback bridge at full resolution
./scripts/webcam-preview.sh --loopback

# v4l2loopback bridge at 1280x720 (for apps that need standard V4L2)
./scripts/webcam-preview.sh --browser
```

The loopback bridge requires `v4l2loopback`:

```bash
sudo modprobe v4l2loopback video_nr=42 card_label="MSI Webcam Bridge" exclusive_caps=1
```

## Architecture

### libcamera path (recommended)

```
ov5675 sensor (2592x1944 SGRBG10)
    |
    v
Intel IPU7 CSI2 0
    |
    v
Intel IPU7 ISYS Capture 0 (/dev/video0, raw BA10)
    |
    v  [libcamera simple pipeline handler + SoftwareISP]
GPU-accelerated debayering (EGL/Mesa) + auto-exposure
    |
    v
PipeWire ("Built-in Front Camera")
    |
    v
Browser / app (via XDG Desktop Portal)
```

### GStreamer bridge path (fallback)

```
ov5675 sensor (2592x1944 SGRBG10)
    |
    v
Intel IPU7 CSI2 0 -> ISYS Capture 0 (/dev/video0, raw BA10)
    |
    v  [GStreamer userspace bridge]
bayer2rgb (CPU) -> videoconvert -> [optional: videoscale]
    |
    v
autovideosink (preview)  OR  v4l2sink -> /dev/video42 (loopback)
```

## Manual Pipeline Setup

If you need raw Bayer access without libcamera (e.g., for debugging):

```bash
media-ctl -d /dev/media0 -l '"Intel IPU7 CSI2 0":1 -> "Intel IPU7 ISYS Capture 0":0 [1]'
media-ctl -d /dev/media0 -V '"Intel IPU7 CSI2 0":0/0 [fmt:SGRBG10_1X10/2592x1944]'
media-ctl -d /dev/media0 -V '"Intel IPU7 CSI2 0":1/0 [fmt:SGRBG10_1X10/2592x1944]'
v4l2-ctl -d /dev/video0 --set-fmt-video=width=2592,height=1944,pixelformat=BA10
```

## Known Issues

- `csi2-0 error: Received packet is too long` warnings appear in dmesg during
  capture (one-scanline mismatch, does not affect image data)
- libcamera falls back to `uncalibrated.yaml` — no tuned IPA profile for ov5675
  on this platform yet; auto-exposure works but may not be optimal
- `cam -l` warns about missing sensor delays — using unverified defaults
- Direct YUYV/RGB streaming from `/dev/video0` does not work (the advertised
  converted formats fail at STREAMON); use libcamera or the GStreamer bridge
- `cheese` does not work (tested, did not produce video)
- The GStreamer bridge script uses ~7W additional CPU for software debayering;
  libcamera's GPU-accelerated path is much more efficient

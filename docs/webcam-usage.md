# Webcam Usage Guide

MSI Prestige 13 AI+ Evo A2VMG — Linux webcam on kernel `exp18` (7.0.0-rc2 + patch stack).

## Prerequisites

- Kernel branch `exp18` with the three-patch stack booted
- `gst-launch-1.0` (from `gstreamer` + `gst-plugins-bad` for `bayer2rgb`)
- `media-ctl`, `v4l2-ctl` (from `v4l-utils`)
- Optional: `v4l2loopback-dkms` for exposing as a normal webcam device

## Quick Start

### Live preview (direct window)

```bash
./scripts/webcam-preview.sh
```

### Feed to v4l2loopback (for normal apps)

```bash
# One-time: create loopback device
sudo modprobe v4l2loopback video_nr=42 card_label="MSI Webcam Bridge" exclusive_caps=1

# Start the bridge (keep running)
./scripts/webcam-preview.sh --loopback

# Other apps can now use /dev/video42 as a webcam:
#   ffplay -f v4l2 /dev/video42
#   mpv av://v4l2:/dev/video42
```

### Single JPEG capture

```bash
./scripts/webcam-preview.sh --snapshot photo.jpg
```

## Manual Pipeline Setup

If you need to set up the media pipeline without the script:

```bash
# 1. Enable the CSI2 -> Capture link
media-ctl -l '"Intel IPU7 CSI2 0":1 -> "Intel IPU7 ISYS Capture 0":0 [1]'

# 2. Set CSI2 pad formats to sensor native resolution
media-ctl -V '"Intel IPU7 CSI2 0":0/0 [fmt:SGRBG10_1X10/2592x1944]'
media-ctl -V '"Intel IPU7 CSI2 0":1/0 [fmt:SGRBG10_1X10/2592x1944]'

# 3. Set capture node format
v4l2-ctl -d /dev/video0 --set-fmt-video=width=2592,height=1944,pixelformat=BA10
```

After this, `/dev/video0` delivers raw 10-bit Bayer frames at 30 fps.

## Exposure and Gain Control

The image is dark by default because analogue and digital gain start at minimum.
Controls are on `/dev/v4l-subdev4` (the ov5675 sensor):

| Control | Min | Max | Default | Notes |
|---------|-----|-----|---------|-------|
| exposure | 4 | 2016 | 2016 | Already at max by default |
| analogue_gain | 128 | 2047 | 128 | **This is why it's dark — crank it up** |
| digital_gain | 1024 | 4095 | 1024 | Additional software gain |
| vertical_blanking | 76 | 30823 | 76 | Affects max exposure range |
| horizontal_flip | 0 | 1 | 0 | |
| vertical_flip | 0 | 1 | 0 | |

### Fix the dark image

```bash
# Boost analogue gain (try 800–1200 for indoor lighting)
v4l2-ctl -d /dev/v4l-subdev4 -c analogue_gain=800

# Or boost digital gain too
v4l2-ctl -d /dev/v4l-subdev4 -c digital_gain=2048

# Can also be passed to the script:
./scripts/webcam-preview.sh --gain 800 --dgain 2048
```

You can adjust these while the stream is running — changes take effect on the next frame.

### Read current values

```bash
v4l2-ctl -d /dev/v4l-subdev4 -L
```

## Architecture

```
ov5675 sensor (2592x1944 SGRBG10)
    |
    v
Intel IPU7 CSI2 0 (pad 0 sink -> pad 1 source)
    |
    v
Intel IPU7 ISYS Capture 0 (/dev/video0, raw BA10)
    |
    v  [GStreamer userspace bridge]
bayer2rgb -> videoconvert
    |
    v
autovideosink (preview)  OR  v4l2sink -> /dev/video42 (loopback)
```

The IPU7 ISYS only delivers raw Bayer — there is no hardware ISP path exposed
yet in mainline. The GStreamer `bayer2rgb` element handles debayering in software.

## Browser / Chrome Usage

Browser webcam support on Linux goes through PipeWire and the XDG Desktop
Portal, not V4L2 directly. The path is:

```
Browser -> xdg-desktop-portal -> PipeWire -> camera source
```

**Current status: working.** Chrome sees the webcam when the bridge is running
in `--browser` mode.

The default `--loopback` output (2592x1944) is rejected by browsers — they
expect standard resolutions like 640x480, 1280x720, or 1920x1080. The
`--browser` flag outputs 1280x720, which Chrome accepts.

```bash
# Start the bridge at 1280x720 (keep running while using the browser)
./scripts/webcam-preview.sh --browser --gain 800
```

Then open Chrome and go to any WebRTC site or `chrome://settings/content/camera`
to select "MSI Webcam Bridge".

### Future: libcamera

`libcamera` with its SoftwareISP pipeline handler could provide a cleaner
long-term path: it can consume raw Bayer sensors directly, handle debayering,
and provide auto-exposure and auto-white-balance. PipeWire has a native
`libcamera` source module. This is untested — `libcamera` tools are not yet
installed on this machine.

## Known Issues

- `csi2-0 error: Received packet is too long` warnings appear in dmesg during
  capture (one-scanline mismatch, does not affect image data)
- No auto-exposure or auto-white-balance — manual gain adjustment required
- Direct YUYV/RGB streaming from `/dev/video0` does not work (the advertised
  converted formats fail at STREAMON)
- `ffmpeg` and `mpv` cannot open `/dev/video0` directly (Broken pipe at
  STREAMON); use the v4l2loopback bridge instead
- `cheese` does not work (tested, did not produce video)

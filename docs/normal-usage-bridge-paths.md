# Normal-Usage Bridge Paths

Updated: 2026-03-12

This note documents the two concrete approaches for closing the gap from the
current working raw Bayer path to something closer to normal webcam usage.

The current measured boundary from `scripts/08-userspace-bridge-check.sh` is:

- raw Bayer delivery from `/dev/video0` works after explicit `media-ctl` setup
- direct advertised app-friendly formats like `YUYV` still fail
- explicit GStreamer `video/x-bayer` plus `bayer2rgb` works

That means the remaining question is no longer "can userspace get frames at
all?" The next question is "how do we expose those frames in a form normal
camera software can use?"

## Approach 1: `libcamera`

Why this path matters:

- it is the cleaner long-term Linux camera stack if the platform has a usable
  pipeline handler
- it may already know how to negotiate formats and buffer flow that direct
  `ffmpeg` / `v4l2src` clients are currently mishandling
- if it works, it is a stronger answer than a repo-local bridge hack

What to test:

- tool presence:
  - `cam`
  - `libcamera-hello`
  - `libcamera-still`
  - `libcamera-vid`
- camera discovery:
  - `cam -l`
  - `libcamera-hello --list-cameras`
- one minimal still-capture path if tools are present

What success would mean:

- `libcamera` can see the sensor path as a usable camera
- the remaining gap is narrower than "no normal Linux camera stack works"
- the next task becomes app integration or pipeline-handler cleanup, not basic
  userspace bridging

Current local status:

- these tools are not installed on this machine yet

## Approach 2: `v4l2loopback`

Why this path matters:

- it is the most direct way to turn the working explicit GStreamer Bayer bridge
  into a normal `/dev/video*` device that browsers, conferencing apps, and
  ordinary V4L2 clients can open
- it does not require waiting for `libcamera` or an IPU7-specific upstream
  pipeline answer before testing app-facing behavior
- it matches the current positive evidence: the repo already has a working
  `video/x-bayer -> bayer2rgb -> videoconvert` chain

The core idea:

```bash
gst-launch-1.0 \
  v4l2src device=/dev/video0 io-mode=mmap \
    ! video/x-bayer,format=grbg10le,width=2592,height=1944,framerate=30/1 \
    ! bayer2rgb \
    ! videoconvert \
    ! video/x-raw,format=YUY2,width=2592,height=1944,framerate=30/1 \
    ! v4l2sink device=/dev/video42
```

That exports a converted stream into a loopback webcam node.

Prerequisites:

- `v4l2loopback` kernel module installed for the running kernel
- a loopback device created before the probe, for example:

```bash
sudo modprobe v4l2loopback \
  video_nr=42 \
  card_label="MSI Webcam Bridge" \
  exclusive_caps=1
```

What success would mean:

- the explicit Bayer bridge can be repackaged as a normal webcam node
- normal V4L2 clients can be tested against the loopback node instead of the
  raw `isys` node
- the remaining gap becomes bridge packaging / automation rather than raw frame
  delivery

Current local status:

- `v4l2loopback` is now installed for the running kernel and `/dev/video42`
  was created successfully
- `scripts/09-libcamera-loopback-check.sh --loopback-device /dev/video42`
  proved the bridge is consumer-facing:
  - `ffmpeg` consumed `/dev/video42` as `yuyv422`
  - GStreamer `v4l2src device=/dev/video42 ! fakesink` also succeeded
- the remaining work on this route is packaging and automation, not first
  proof of viability

## Repo Entry Point

`scripts/09-libcamera-loopback-check.sh` is the repeatable checkpoint for these
two approaches.

It does three things:

- records the current prerequisite surface
- exercises the `libcamera` path if tools are present
- exercises the `v4l2loopback` bridge path if the module and loopback device
  are present

If prerequisites are missing, it records the exact absence and the next manual
setup needed before a rerun.

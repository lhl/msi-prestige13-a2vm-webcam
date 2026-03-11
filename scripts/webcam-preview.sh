#!/usr/bin/env bash
# webcam-preview.sh — set up the IPU7/OV5675 media pipeline and show a live preview
#
# Usage:
#   ./scripts/webcam-preview.sh              # direct preview window
#   ./scripts/webcam-preview.sh --loopback   # feed v4l2loopback (/dev/video42)
#   ./scripts/webcam-preview.sh --snapshot out.jpg   # single JPEG capture
#
# Sensor controls (run while streaming or before):
#   v4l2-ctl -d /dev/v4l-subdev4 -c exposure=2016
#   v4l2-ctl -d /dev/v4l-subdev4 -c analogue_gain=800
#   v4l2-ctl -d /dev/v4l-subdev4 -c digital_gain=2048
#
# Controls reference (ov5675 on /dev/v4l-subdev4):
#   exposure       4–2016   (default 2016)
#   analogue_gain  128–2047 (default 128)
#   digital_gain   1024–4095 (default 1024)
#   horizontal_flip / vertical_flip (bool)
#   vertical_blanking 76–30823

set -euo pipefail

SENSOR_SUBDEV=/dev/v4l-subdev4
VIDEO_DEV=/dev/video0
LOOPBACK_DEV=/dev/video42
WIDTH=2592
HEIGHT=1944
FPS=30

# --- defaults ----------------------------------------------------------------
MODE=preview
SNAPSHOT_PATH=""
EXPOSURE=""
ANALOGUE_GAIN=""
DIGITAL_GAIN=""

usage() {
    sed -n '2,/^$/s/^# \?//p' "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --loopback)   MODE=loopback; shift ;;
        --snapshot)   MODE=snapshot; SNAPSHOT_PATH="${2:?--snapshot requires a path}"; shift 2 ;;
        --exposure)   EXPOSURE="$2"; shift 2 ;;
        --gain)       ANALOGUE_GAIN="$2"; shift 2 ;;
        --dgain)      DIGITAL_GAIN="$2"; shift 2 ;;
        -h|--help)    usage ;;
        *)            echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- media pipeline setup ----------------------------------------------------
echo "=== Configuring media pipeline ==="

# Enable CSI2:1 -> Capture 0 link
media-ctl -l "\"Intel IPU7 CSI2 0\":1 -> \"Intel IPU7 ISYS Capture 0\":0 [1]" 2>/dev/null || true

# Set pad formats to native sensor resolution
media-ctl -V "\"Intel IPU7 CSI2 0\":0/0 [fmt:SGRBG10_1X10/${WIDTH}x${HEIGHT}]"
media-ctl -V "\"Intel IPU7 CSI2 0\":1/0 [fmt:SGRBG10_1X10/${WIDTH}x${HEIGHT}]"

# Set capture node format
v4l2-ctl -d "$VIDEO_DEV" --set-fmt-video="width=${WIDTH},height=${HEIGHT},pixelformat=BA10"

echo "Pipeline configured: ${WIDTH}x${HEIGHT} SGRBG10 on $VIDEO_DEV"

# --- sensor controls ----------------------------------------------------------
if [[ -n "$EXPOSURE" ]]; then
    v4l2-ctl -d "$SENSOR_SUBDEV" -c "exposure=$EXPOSURE"
    echo "Set exposure=$EXPOSURE"
fi
if [[ -n "$ANALOGUE_GAIN" ]]; then
    v4l2-ctl -d "$SENSOR_SUBDEV" -c "analogue_gain=$ANALOGUE_GAIN"
    echo "Set analogue_gain=$ANALOGUE_GAIN"
fi
if [[ -n "$DIGITAL_GAIN" ]]; then
    v4l2-ctl -d "$SENSOR_SUBDEV" -c "digital_gain=$DIGITAL_GAIN"
    echo "Set digital_gain=$DIGITAL_GAIN"
fi

# Show current sensor controls
echo ""
echo "=== Current sensor controls ==="
v4l2-ctl -d "$SENSOR_SUBDEV" -L 2>/dev/null | grep -E 'exposure|analogue_gain|digital_gain' || true
echo ""

# --- GStreamer source caps ----------------------------------------------------
SRC_CAPS="video/x-bayer,format=grbg10le,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1"

case "$MODE" in
    preview)
        echo "=== Starting live preview (Ctrl+C to stop) ==="
        exec gst-launch-1.0 \
            v4l2src device="$VIDEO_DEV" io-mode=mmap \
            ! "$SRC_CAPS" \
            ! bayer2rgb \
            ! videoconvert \
            ! autovideosink
        ;;

    loopback)
        if [[ ! -e "$LOOPBACK_DEV" ]]; then
            echo "Loopback device $LOOPBACK_DEV not found."
            echo "Create it with:"
            echo "  sudo modprobe v4l2loopback video_nr=42 card_label='MSI Webcam Bridge' exclusive_caps=1"
            exit 1
        fi
        echo "=== Feeding v4l2loopback at $LOOPBACK_DEV (Ctrl+C to stop) ==="
        echo "Other apps can now open $LOOPBACK_DEV as a normal webcam."
        exec gst-launch-1.0 \
            v4l2src device="$VIDEO_DEV" io-mode=mmap \
            ! "$SRC_CAPS" \
            ! bayer2rgb \
            ! videoconvert \
            ! "video/x-raw,format=YUY2,width=${WIDTH},height=${HEIGHT},framerate=${FPS}/1" \
            ! v4l2sink device="$LOOPBACK_DEV" sync=false
        ;;

    snapshot)
        echo "=== Capturing single JPEG to $SNAPSHOT_PATH ==="
        gst-launch-1.0 \
            v4l2src device="$VIDEO_DEV" io-mode=mmap num-buffers=5 \
            ! "$SRC_CAPS" \
            ! bayer2rgb \
            ! videoconvert \
            ! jpegenc \
            ! filesink location="$SNAPSHOT_PATH"
        echo "Saved: $SNAPSHOT_PATH"
        ;;
esac

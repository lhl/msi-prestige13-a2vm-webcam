#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="08-userspace-bridge-check"
NOTE="numbered userspace bridge and negotiated-format check"
MEDIA_DEVICE="/dev/media0"
VIDEO_DEVICE="/dev/video0"
CSI2_ENTITY="Intel IPU7 CSI2 0"
CAPTURE_ENTITY="Intel IPU7 ISYS Capture 0"
SENSOR_WIDTH=2592
SENSOR_HEIGHT=1944
SENSOR_MBUS_FMT="SGRBG10_1X10"
PIXEL_FORMAT="BA10"
GST_BAYER_FORMAT="grbg10le"
STANDARD_PIXEL_FORMAT="YUYV"
STANDARD_PIXEL_FFMPEG_FORMAT="yuyv422"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20
CLIENT_FRAME_COUNT=2
CLIENT_TIMEOUT_S=20
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/08-userspace-bridge-check.sh [options]

Options:
  --label NAME
      Run label passed through to scripts/webcam-run.sh
  --note TEXT
      Run note passed through to scripts/webcam-run.sh
  --media-device PATH
      Media device. Default: /dev/media0
  --video-device PATH
      Video node to stream from. Default: /dev/video0
  --sensor-width N
      Sensor native width. Default: 2592
  --sensor-height N
      Sensor native height. Default: 1944
  --sensor-mbus-fmt CODE
      Sensor media-bus format code. Default: SGRBG10_1X10
  --pixel-format FOURCC
      Working raw capture-node format. Default: BA10
  --gst-bayer-format NAME
      GStreamer Bayer caps format that matches the working raw node format.
      Default: grbg10le
  --standard-pixel-format FOURCC
      App-friendly V4L2 format to test directly on the capture node.
      Default: YUYV
  --standard-pixel-ffmpeg-format NAME
      FFmpeg input format name for the tested app-friendly format.
      Default: yuyv422
  --stream-count N
      Number of frames for the raw v4l2 sanity capture. Default: 4
  --stream-buffers N
      Number of mmap buffers. Default: 4
  --stream-timeout-s N
      Timeout wrapper for the raw v4l2 sanity capture in seconds. Default: 20
  --client-frame-count N
      Number of buffers/frames for higher-level client probes. Default: 2
  --client-timeout-s N
      Timeout wrapper for each higher-level client probe in seconds. Default: 20
  --dry-run
      Print planned commands without executing them.

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Records the current V4L2 / FFmpeg format inventory
  3. Applies the known-good manual pipeline setup from script 06
  4. Re-validates the raw BA10 baseline with v4l2-ctl
  5. Tests whether advertised app-friendly formats like YUYV actually stream
  6. Tests whether auto-negotiated higher-level clients still fail
  7. Tests whether an explicit GStreamer Bayer bridge works:
     - v4l2src + explicit video/x-bayer caps
     - optional bayer2rgb + videoconvert path
     - optional JPEG export
  8. Writes a focused summary that separates:
     - raw manual success
     - direct standard-pixel/client failure
     - explicit userspace bridge success
EOF
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

capture_command() {
  local output_path="$1"
  shift
  local status=0

  {
    printf 'CMD:'
    printf ' %q' "$@"
    printf '\n'
    set +e
    "$@"
    status=$?
    set -e
    printf '\nEXIT_STATUS: %d\n' "${status}"
  } > "${output_path}" 2>&1

  return 0
}

capture_command_append() {
  local output_path="$1"
  shift
  local status=0

  {
    printf 'CMD:'
    printf ' %q' "$@"
    printf '\n'
    set +e
    "$@"
    status=$?
    set -e
    printf '\nEXIT_STATUS: %d\n' "${status}"
  } >> "${output_path}" 2>&1

  return 0
}

extract_exit_status() {
  local path="$1"

  sed -n 's/^EXIT_STATUS: //p' "${path}" | tail -n 1
}

file_size_bytes() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    printf '0\n'
    return 0
  fi

  if have_cmd stat; then
    stat -c '%s' "${path}"
  else
    wc -c < "${path}"
  fi
}

extract_v4l2_field() {
  local path="$1"
  local label="$2"

  sed -n "s/^[[:space:]]*${label}[[:space:]]*:[[:space:]]*//p" "${path}" | \
    tail -n 1 | tr -d '[:space:]'
}

tool_status_from_log() {
  local log_path="$1"
  local success_pattern="${2:-}"
  local exit_status=""

  exit_status=$(extract_exit_status "${log_path}")
  if [[ ! "${exit_status}" =~ ^[0-9]+$ ]]; then
    printf 'unknown (no exit status found)\n'
    return 0
  fi

  if (( exit_status == 124 )); then
    printf 'timeout\n'
    return 0
  fi

  if (( exit_status != 0 )); then
    printf 'failed (exit=%s)\n' "${exit_status}"
    return 0
  fi

  if [[ -n "${success_pattern}" ]] && ! rg -q "${success_pattern}" "${log_path}"; then
    printf 'inconclusive (exit=0 without expected log pattern)\n'
    return 0
  fi

  printf 'ok\n'
}

plugin_status_from_log() {
  local log_path="$1"
  local exit_status=""

  exit_status=$(extract_exit_status "${log_path}")
  if [[ "${exit_status}" == "0" ]]; then
    printf 'present\n'
  else
    printf 'missing or unavailable\n'
  fi
}

refresh_pipeline() {
  local output_path="$1"
  local node_pixel_format="$2"

  : > "${output_path}"
  capture_command_append "${output_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SINK_FMT_ARG}"
  capture_command_append "${output_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SRC_FMT_ARG}"
  capture_command_append "${output_path}" media-ctl -d "${MEDIA_DEVICE}" -l "${LINK_ARG}"
  capture_command_append "${output_path}" \
    v4l2-ctl -d "${VIDEO_DEVICE}" \
      --set-fmt-video="width=${SENSOR_WIDTH},height=${SENSOR_HEIGHT},pixelformat=${node_pixel_format}"
}

refresh_status_from_log() {
  local log_path="$1"

  if [[ ! -s "${log_path}" ]]; then
    printf 'not run\n'
    return 0
  fi

  if rg -q '^EXIT_STATUS: [1-9][0-9]*$' "${log_path}"; then
    printf 'failed\n'
  else
    printf 'ok\n'
  fi
}

stream_result_from_log() {
  local log_path="$1"
  local data_path="$2"
  local exit_status=""
  local size_bytes=0

  exit_status=$(extract_exit_status "${log_path}")
  size_bytes=$(file_size_bytes "${data_path}")

  if [[ ! "${exit_status}" =~ ^[0-9]+$ ]]; then
    printf 'unknown (no exit status found)\n'
    return 0
  fi

  if (( exit_status == 124 )); then
    printf 'timeout\n'
    return 0
  fi

  if (( exit_status != 0 )); then
    printf 'failed (exit=%s)\n' "${exit_status}"
    return 0
  fi

  if (( size_bytes <= 0 )); then
    printf 'failed (exit=0 but output empty)\n'
    return 0
  fi

  printf 'ok (%s bytes)\n' "${size_bytes}"
}

write_tool_presence() {
  local output_path="$1"
  local tool="$2"

  if have_cmd "${tool}"; then
    local tool_path
    tool_path=$(command -v "${tool}")
    printf '%s: present at %s\n' "${tool}" "${tool_path}" >> "${output_path}"
  else
    printf '%s: missing\n' "${tool}" >> "${output_path}"
  fi
}

while (($# > 0)); do
  case "$1" in
    --label)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      LABEL="$1"
      ;;
    --note)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      NOTE="$1"
      ;;
    --media-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      MEDIA_DEVICE="$1"
      ;;
    --video-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      VIDEO_DEVICE="$1"
      ;;
    --sensor-width)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      SENSOR_WIDTH="$1"
      ;;
    --sensor-height)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      SENSOR_HEIGHT="$1"
      ;;
    --sensor-mbus-fmt)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      SENSOR_MBUS_FMT="$1"
      ;;
    --pixel-format)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      PIXEL_FORMAT="$1"
      ;;
    --gst-bayer-format)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      GST_BAYER_FORMAT="$1"
      ;;
    --standard-pixel-format)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      STANDARD_PIXEL_FORMAT="$1"
      ;;
    --standard-pixel-ffmpeg-format)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      STANDARD_PIXEL_FFMPEG_FORMAT="$1"
      ;;
    --stream-count)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      STREAM_COUNT="$1"
      ;;
    --stream-buffers)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      STREAM_BUFFERS="$1"
      ;;
    --stream-timeout-s)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      STREAM_TIMEOUT_S="$1"
      ;;
    --client-frame-count)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      CLIENT_FRAME_COUNT="$1"
      ;;
    --client-timeout-s)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      CLIENT_TIMEOUT_S="$1"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done

have_cmd journalctl || die "missing required command: journalctl"
have_cmd media-ctl || die "missing required command: media-ctl"
have_cmd rg || die "missing required command: rg"
have_cmd timeout || die "missing required command: timeout"
have_cmd v4l2-ctl || die "missing required command: v4l2-ctl"

FFMPEG_AVAILABLE=0
GSTREAMER_AVAILABLE=0
GST_INSPECT_AVAILABLE=0
FILE_AVAILABLE=0

have_cmd ffmpeg && FFMPEG_AVAILABLE=1
have_cmd gst-launch-1.0 && GSTREAMER_AVAILABLE=1
have_cmd gst-inspect-1.0 && GST_INSPECT_AVAILABLE=1
have_cmd file && FILE_AVAILABLE=1

cd "${REPO_ROOT}"

ROUTE_ARG="\"${CSI2_ENTITY}\" [0/0 -> 1/0 [1]]"
CSI2_SINK_FMT_ARG="\"${CSI2_ENTITY}\":0/0 [fmt:${SENSOR_MBUS_FMT}/${SENSOR_WIDTH}x${SENSOR_HEIGHT}]"
CSI2_SRC_FMT_ARG="\"${CSI2_ENTITY}\":1/0 [fmt:${SENSOR_MBUS_FMT}/${SENSOR_WIDTH}x${SENSOR_HEIGHT}]"
LINK_ARG="\"${CSI2_ENTITY}\":1 -> \"${CAPTURE_ENTITY}\":0 [1]"

if (( DRY_RUN )); then
  printf 'DRY_RUN: scripts/webcam-run.sh snapshot --label %q --note %q\n' "${LABEL}" "${NOTE}"
  printf 'DRY_RUN: media-ctl -p -d %q  (pre-setup)\n' "${MEDIA_DEVICE}"
  printf 'DRY_RUN: v4l2-ctl --all -d %q  (pre-setup)\n' "${VIDEO_DEVICE}"
  printf 'DRY_RUN: v4l2-ctl --list-formats-ext -d %q\n' "${VIDEO_DEVICE}"
  printf 'DRY_RUN: media-ctl -d %q -R %s\n' "${MEDIA_DEVICE}" "${ROUTE_ARG}"
  printf 'DRY_RUN: refresh working BA10 setup via media-ctl + v4l2-ctl\n'
  printf 'DRY_RUN: timeout %qs v4l2-ctl -d %q --stream-mmap=%q --stream-count=%q --stream-poll --stream-to <run>/bridge-check/%s-ba10.raw --verbose\n' \
    "${STREAM_TIMEOUT_S}" "${VIDEO_DEVICE}" "${STREAM_BUFFERS}" "${STREAM_COUNT}" "$(basename -- "${VIDEO_DEVICE}")"
  printf 'DRY_RUN: refresh %q setup and test standard-pixel direct path\n' "${STANDARD_PIXEL_FORMAT}"
  if (( FFMPEG_AVAILABLE )); then
    printf 'DRY_RUN: ffmpeg -hide_banner -f v4l2 -list_formats all -i %q\n' "${VIDEO_DEVICE}"
    printf 'DRY_RUN: timeout %qs ffmpeg -hide_banner -nostdin -loglevel info -f v4l2 -framerate 30 -video_size %qx%q -i %q -frames:v %q -f null -\n' \
      "${CLIENT_TIMEOUT_S}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}"
    printf 'DRY_RUN: timeout %qs ffmpeg -hide_banner -nostdin -loglevel info -f v4l2 -input_format %q -framerate 30 -video_size %qx%q -i %q -frames:v %q -f null -\n' \
      "${CLIENT_TIMEOUT_S}" "${STANDARD_PIXEL_FFMPEG_FORMAT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}"
  fi
  if (( GSTREAMER_AVAILABLE )); then
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -q v4l2src device=%q num-buffers=%q ! fakesink sync=false\n' \
      "${CLIENT_TIMEOUT_S}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}"
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -q v4l2src device=%q io-mode=mmap num-buffers=%q ! video/x-raw,format=YUY2,width=%q,height=%q,framerate=30/1 ! fakesink sync=false\n' \
      "${CLIENT_TIMEOUT_S}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -v v4l2src device=%q io-mode=mmap num-buffers=%q ! video/x-bayer,format=%q,width=%q,height=%q,framerate=30/1 ! fakesink sync=false\n' \
      "${CLIENT_TIMEOUT_S}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}" "${GST_BAYER_FORMAT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -v v4l2src device=%q io-mode=mmap num-buffers=%q ! video/x-bayer,format=%q,width=%q,height=%q,framerate=30/1 ! bayer2rgb ! videoconvert ! video/x-raw,format=BGRx ! fakesink sync=false\n' \
      "${CLIENT_TIMEOUT_S}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}" "${GST_BAYER_FORMAT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -q v4l2src device=%q io-mode=mmap num-buffers=1 ! video/x-bayer,format=%q,width=%q,height=%q,framerate=30/1 ! bayer2rgb ! videoconvert ! jpegenc ! multifilesink location=<run>/bridge-check/%s-gst-bayer-frame-%%02d.jpg\n' \
      "${CLIENT_TIMEOUT_S}" "${VIDEO_DEVICE}" "${GST_BAYER_FORMAT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "$(basename -- "${VIDEO_DEVICE}")"
  fi
  exit 0
fi

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory"

check_dir="${run_dir}/bridge-check"
mkdir -p "${check_dir}"

check_start_local=$(date +"%Y-%m-%d %H:%M:%S")
video_base=$(basename -- "${VIDEO_DEVICE}")

pre_media_path="${check_dir}/media-ctl-pre.txt"
pre_node_path="${check_dir}/${video_base}-before.txt"
formats_path="${check_dir}/${video_base}-formats.txt"
ffmpeg_formats_path="${check_dir}/ffmpeg-list-formats.txt"
bayer_plugin_path="${check_dir}/gst-plugin-bayer2rgb.txt"
jpeg_plugin_path="${check_dir}/gst-plugin-jpegenc.txt"
route_path="${check_dir}/step1-route.txt"
raw_refresh_path="${check_dir}/setup-ba10-refresh.txt"
raw_node_path="${check_dir}/${video_base}-ba10.txt"
raw_stream_log_path="${check_dir}/${video_base}-ba10-stream.txt"
raw_path="${check_dir}/${video_base}-ba10.raw"
ffmpeg_default_path="${check_dir}/ffmpeg-default-ba10.txt"
yuyv_refresh_path="${check_dir}/setup-yuyv-refresh.txt"
yuyv_node_path="${check_dir}/${video_base}-yuyv.txt"
yuyv_stream_log_path="${check_dir}/${video_base}-yuyv-stream.txt"
yuyv_path="${check_dir}/${video_base}-yuyv.raw"
ffmpeg_yuyv_path="${check_dir}/ffmpeg-yuyv.txt"
gst_auto_refresh_path="${check_dir}/setup-gstreamer-auto-refresh.txt"
gst_auto_path="${check_dir}/gst-auto.txt"
gst_yuyv_refresh_path="${check_dir}/setup-gstreamer-yuyv-refresh.txt"
gst_yuyv_path="${check_dir}/gst-yuyv.txt"
gst_bayer_refresh_path="${check_dir}/setup-gstreamer-bayer-refresh.txt"
gst_bayer_path="${check_dir}/gst-bayer.txt"
gst_bayer_rgb_refresh_path="${check_dir}/setup-gstreamer-bayer-rgb-refresh.txt"
gst_bayer_rgb_path="${check_dir}/gst-bayer-rgb.txt"
gst_bayer_jpeg_refresh_path="${check_dir}/setup-gstreamer-bayer-jpeg-refresh.txt"
gst_bayer_jpeg_path="${check_dir}/gst-bayer-jpeg.txt"
gst_bayer_jpeg_artifact="${check_dir}/${video_base}-gst-bayer-frame-00.jpg"
gst_bayer_jpeg_info_path="${check_dir}/${video_base}-gst-bayer-frame-00.txt"
journal_path="${check_dir}/journal-since.txt"
tool_presence_path="${check_dir}/tool-presence.txt"
summary_path="${run_dir}/focused-summary.txt"

{
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'csi2_entity=%s\n' "${CSI2_ENTITY}"
  printf 'capture_entity=%s\n' "${CAPTURE_ENTITY}"
  printf 'sensor_width=%s\n' "${SENSOR_WIDTH}"
  printf 'sensor_height=%s\n' "${SENSOR_HEIGHT}"
  printf 'sensor_mbus_fmt=%s\n' "${SENSOR_MBUS_FMT}"
  printf 'pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'gst_bayer_format=%s\n' "${GST_BAYER_FORMAT}"
  printf 'standard_pixel_format=%s\n' "${STANDARD_PIXEL_FORMAT}"
  printf 'standard_pixel_ffmpeg_format=%s\n' "${STANDARD_PIXEL_FFMPEG_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'client_frame_count=%s\n' "${CLIENT_FRAME_COUNT}"
  printf 'client_timeout_s=%s\n' "${CLIENT_TIMEOUT_S}"
} > "${check_dir}/metadata.env"

{
  write_tool_presence "${tool_presence_path}" "ffmpeg"
  write_tool_presence "${tool_presence_path}" "gst-launch-1.0"
  write_tool_presence "${tool_presence_path}" "gst-inspect-1.0"
  write_tool_presence "${tool_presence_path}" "file"
} >/dev/null

capture_command "${pre_media_path}" media-ctl -p -d "${MEDIA_DEVICE}"
capture_command "${pre_node_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"
capture_command "${formats_path}" v4l2-ctl --list-formats-ext -d "${VIDEO_DEVICE}"

if (( FFMPEG_AVAILABLE )); then
  capture_command "${ffmpeg_formats_path}" ffmpeg -hide_banner -f v4l2 -list_formats all -i "${VIDEO_DEVICE}"
else
  printf 'ffmpeg not installed\nEXIT_STATUS: 127\n' > "${ffmpeg_formats_path}"
fi

if (( GST_INSPECT_AVAILABLE )); then
  capture_command "${bayer_plugin_path}" gst-inspect-1.0 bayer2rgb
  capture_command "${jpeg_plugin_path}" gst-inspect-1.0 jpegenc
else
  printf 'gst-inspect-1.0 not installed\nEXIT_STATUS: 127\n' > "${bayer_plugin_path}"
  printf 'gst-inspect-1.0 not installed\nEXIT_STATUS: 127\n' > "${jpeg_plugin_path}"
fi

capture_command "${route_path}" media-ctl -d "${MEDIA_DEVICE}" -R "${ROUTE_ARG}"
route_status=$(extract_exit_status "${route_path}")

refresh_pipeline "${raw_refresh_path}" "${PIXEL_FORMAT}"
capture_command "${raw_node_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"
capture_command \
  "${raw_stream_log_path}" \
  timeout "${STREAM_TIMEOUT_S}s" \
  v4l2-ctl \
    -d "${VIDEO_DEVICE}" \
    --stream-mmap="${STREAM_BUFFERS}" \
    --stream-count="${STREAM_COUNT}" \
    --stream-poll \
    --stream-to="${raw_path}" \
    --verbose

if (( FFMPEG_AVAILABLE )); then
  capture_command \
    "${ffmpeg_default_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    ffmpeg \
      -hide_banner \
      -nostdin \
      -loglevel info \
      -f v4l2 \
      -framerate 30 \
      -video_size "${SENSOR_WIDTH}x${SENSOR_HEIGHT}" \
      -i "${VIDEO_DEVICE}" \
      -frames:v "${CLIENT_FRAME_COUNT}" \
      -f null \
      -
else
  printf 'ffmpeg not installed\nEXIT_STATUS: 127\n' > "${ffmpeg_default_path}"
fi

refresh_pipeline "${yuyv_refresh_path}" "${STANDARD_PIXEL_FORMAT}"
capture_command "${yuyv_node_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"
capture_command \
  "${yuyv_stream_log_path}" \
  timeout "${STREAM_TIMEOUT_S}s" \
  v4l2-ctl \
    -d "${VIDEO_DEVICE}" \
    --stream-mmap="${STREAM_BUFFERS}" \
    --stream-count="${CLIENT_FRAME_COUNT}" \
    --stream-poll \
    --stream-to="${yuyv_path}" \
    --verbose

if (( FFMPEG_AVAILABLE )); then
  capture_command \
    "${ffmpeg_yuyv_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    ffmpeg \
      -hide_banner \
      -nostdin \
      -loglevel info \
      -f v4l2 \
      -input_format "${STANDARD_PIXEL_FFMPEG_FORMAT}" \
      -framerate 30 \
      -video_size "${SENSOR_WIDTH}x${SENSOR_HEIGHT}" \
      -i "${VIDEO_DEVICE}" \
      -frames:v "${CLIENT_FRAME_COUNT}" \
      -f null \
      -
else
  printf 'ffmpeg not installed\nEXIT_STATUS: 127\n' > "${ffmpeg_yuyv_path}"
fi

if (( GSTREAMER_AVAILABLE )); then
  refresh_pipeline "${gst_auto_refresh_path}" "${PIXEL_FORMAT}"
  capture_command \
    "${gst_auto_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    gst-launch-1.0 \
      -q \
      v4l2src \
      device="${VIDEO_DEVICE}" \
      num-buffers="${CLIENT_FRAME_COUNT}" \
      ! \
      fakesink \
      sync=false

  refresh_pipeline "${gst_yuyv_refresh_path}" "${STANDARD_PIXEL_FORMAT}"
  capture_command \
    "${gst_yuyv_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    gst-launch-1.0 \
      -q \
      v4l2src \
      device="${VIDEO_DEVICE}" \
      io-mode=mmap \
      num-buffers="${CLIENT_FRAME_COUNT}" \
      ! \
      video/x-raw,format=YUY2,width="${SENSOR_WIDTH}",height="${SENSOR_HEIGHT}",framerate=30/1 \
      ! \
      fakesink \
      sync=false

  refresh_pipeline "${gst_bayer_refresh_path}" "${PIXEL_FORMAT}"
  capture_command \
    "${gst_bayer_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    gst-launch-1.0 \
      -v \
      v4l2src \
      device="${VIDEO_DEVICE}" \
      io-mode=mmap \
      num-buffers="${CLIENT_FRAME_COUNT}" \
      ! \
      video/x-bayer,format="${GST_BAYER_FORMAT}",width="${SENSOR_WIDTH}",height="${SENSOR_HEIGHT}",framerate=30/1 \
      ! \
      fakesink \
      sync=false

  if [[ "$(plugin_status_from_log "${bayer_plugin_path}")" == "present" ]]; then
    refresh_pipeline "${gst_bayer_rgb_refresh_path}" "${PIXEL_FORMAT}"
    capture_command \
      "${gst_bayer_rgb_path}" \
      timeout "${CLIENT_TIMEOUT_S}s" \
      gst-launch-1.0 \
        -v \
        v4l2src \
        device="${VIDEO_DEVICE}" \
        io-mode=mmap \
        num-buffers="${CLIENT_FRAME_COUNT}" \
        ! \
        video/x-bayer,format="${GST_BAYER_FORMAT}",width="${SENSOR_WIDTH}",height="${SENSOR_HEIGHT}",framerate=30/1 \
        ! \
        bayer2rgb \
        ! \
        videoconvert \
        ! \
        video/x-raw,format=BGRx \
        ! \
        fakesink \
        sync=false
  else
    printf 'bayer2rgb plugin unavailable\nEXIT_STATUS: 127\n' > "${gst_bayer_rgb_path}"
  fi

  if [[ "$(plugin_status_from_log "${bayer_plugin_path}")" == "present" && "$(plugin_status_from_log "${jpeg_plugin_path}")" == "present" ]]; then
    refresh_pipeline "${gst_bayer_jpeg_refresh_path}" "${PIXEL_FORMAT}"
    capture_command \
      "${gst_bayer_jpeg_path}" \
      timeout "${CLIENT_TIMEOUT_S}s" \
      gst-launch-1.0 \
        -q \
        v4l2src \
        device="${VIDEO_DEVICE}" \
        io-mode=mmap \
        num-buffers=1 \
        ! \
        video/x-bayer,format="${GST_BAYER_FORMAT}",width="${SENSOR_WIDTH}",height="${SENSOR_HEIGHT}",framerate=30/1 \
        ! \
        bayer2rgb \
        ! \
        videoconvert \
        ! \
        jpegenc \
        ! \
        multifilesink \
        location="${gst_bayer_jpeg_artifact%00.jpg}%02d.jpg"
  else
    printf 'required GStreamer plugins unavailable\nEXIT_STATUS: 127\n' > "${gst_bayer_jpeg_path}"
  fi
else
  printf 'gst-launch-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_auto_path}"
  printf 'gst-launch-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_yuyv_path}"
  printf 'gst-launch-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_bayer_path}"
  printf 'gst-launch-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_bayer_rgb_path}"
  printf 'gst-launch-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_bayer_jpeg_path}"
fi

if [[ -f "${gst_bayer_jpeg_artifact}" ]] && (( FILE_AVAILABLE )); then
  capture_command "${gst_bayer_jpeg_info_path}" file "${gst_bayer_jpeg_artifact}"
elif [[ -f "${gst_bayer_jpeg_artifact}" ]]; then
  printf 'file command unavailable\nEXIT_STATUS: 127\n' > "${gst_bayer_jpeg_info_path}"
else
  printf 'JPEG artifact not created\nEXIT_STATUS: 1\n' > "${gst_bayer_jpeg_info_path}"
fi

journalctl -k --since "${check_start_local}" --no-pager | \
  rg 'ov5675|intel-ipu7|ipu7|isys|subdev|video[0-9]+|stream|frame|timeout|error|failed|packet|link|broken pipe' \
  > "${journal_path}" || true

route_effective_note="route setup failed"
if [[ "${route_status}" == "0" ]]; then
  route_effective_note="configured successfully"
elif rg -q 'Operation not supported' "${route_path}"; then
  route_effective_note="ENOTSUP on IPU7 CSI2 (expected; route step not required)"
fi

raw_refresh_status=$(refresh_status_from_log "${raw_refresh_path}")
yuyv_refresh_status=$(refresh_status_from_log "${yuyv_refresh_path}")
gst_auto_refresh_status=$(refresh_status_from_log "${gst_auto_refresh_path}")
gst_yuyv_refresh_status=$(refresh_status_from_log "${gst_yuyv_refresh_path}")
gst_bayer_refresh_status=$(refresh_status_from_log "${gst_bayer_refresh_path}")
gst_bayer_rgb_refresh_status=$(refresh_status_from_log "${gst_bayer_rgb_refresh_path}")
gst_bayer_jpeg_refresh_status=$(refresh_status_from_log "${gst_bayer_jpeg_refresh_path}")

raw_result=$(stream_result_from_log "${raw_stream_log_path}" "${raw_path}")
yuyv_result=$(stream_result_from_log "${yuyv_stream_log_path}" "${yuyv_path}")
ffmpeg_default_result=$(tool_status_from_log "${ffmpeg_default_path}")
ffmpeg_yuyv_result=$(tool_status_from_log "${ffmpeg_yuyv_path}")
gst_auto_result=$(tool_status_from_log "${gst_auto_path}")
gst_yuyv_result=$(tool_status_from_log "${gst_yuyv_path}")
gst_bayer_result=$(tool_status_from_log "${gst_bayer_path}" 'Got EOS from element')
gst_bayer_rgb_result=$(tool_status_from_log "${gst_bayer_rgb_path}" 'Got EOS from element')
gst_bayer_jpeg_result=$(tool_status_from_log "${gst_bayer_jpeg_path}")

jpeg_size=$(file_size_bytes "${gst_bayer_jpeg_artifact}")
jpeg_info_tail=$(tail -n 5 "${gst_bayer_jpeg_info_path}" 2>/dev/null || true)

bytes_per_line=$(extract_v4l2_field "${raw_node_path}" 'Bytes per Line')
size_image=$(extract_v4l2_field "${raw_node_path}" 'Size Image')
first_bytesused=$(sed -n 's/.*bytesused:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${raw_stream_log_path}" | head -n 1)
geometry_summary="(unable to derive from capture-node or stream logs)"
if [[ "${first_bytesused}" =~ ^[0-9]+$ && "${size_image}" =~ ^[0-9]+$ ]]; then
  geometry_delta=$(( size_image - first_bytesused ))
  geometry_summary="bytesused=${first_bytesused}; size_image=${size_image}; delta=${geometry_delta} bytes"
  if [[ "${bytes_per_line}" =~ ^[0-9]+$ && "${bytes_per_line}" -gt 0 ]]; then
    if (( geometry_delta >= 0 && geometry_delta % bytes_per_line == 0 )); then
      geometry_summary="${geometry_summary}; bytes_per_line=${bytes_per_line}; extra_scanlines=$(( geometry_delta / bytes_per_line ))"
    else
      geometry_summary="${geometry_summary}; bytes_per_line=${bytes_per_line}"
    fi
  fi
fi

ffmpeg_format_note="ffmpeg format inventory not available"
if (( FFMPEG_AVAILABLE )); then
  ffmpeg_supported=()
  rg -q 'uyvy422' "${ffmpeg_formats_path}" && ffmpeg_supported+=("uyvy422")
  rg -q 'yuyv422' "${ffmpeg_formats_path}" && ffmpeg_supported+=("yuyv422")
  rg -q 'rgb565le' "${ffmpeg_formats_path}" && ffmpeg_supported+=("rgb565le")
  rg -q 'bgr24' "${ffmpeg_formats_path}" && ffmpeg_supported+=("bgr24")

  ffmpeg_bayer_note="10-bit Bayer support unclear"
  if rg -q 'Unsupported : 10-bit Bayer' "${ffmpeg_formats_path}"; then
    ffmpeg_bayer_note="ffmpeg marks the advertised 10-bit Bayer formats unsupported on this V4L2 path"
  fi

  if ((${#ffmpeg_supported[@]} > 0)); then
    ffmpeg_format_note="${ffmpeg_bayer_note}; supported standard formats include ${ffmpeg_supported[*]}"
  else
    ffmpeg_format_note="${ffmpeg_bayer_note}; no supported standard formats were matched in the inventory log"
  fi
fi

bayer_plugin_status=$(plugin_status_from_log "${bayer_plugin_path}")
jpeg_plugin_status=$(plugin_status_from_log "${jpeg_plugin_path}")

overall_result="gap remains: raw capture may work, but no userspace bridge succeeded yet"
if [[ "${raw_result}" == ok* ]]; then
  if [[ "${gst_bayer_result}" == "ok" || "${gst_bayer_rgb_result}" == "ok" || "${gst_bayer_jpeg_result}" == ok* ]]; then
    overall_result="partial userspace bridge exists: explicit GStreamer Bayer caps work, but auto-negotiated and direct standard-pixel client paths still fail"
  else
    overall_result="gap remains: raw BA10 works, but neither auto-negotiated clients nor an explicit bridge succeeded"
  fi
fi

interpretation_note="no clear bridge path yet"
if [[ "${gst_bayer_rgb_result}" == "ok" && "${gst_bayer_jpeg_result}" == ok* ]]; then
  interpretation_note="GStreamer can consume raw Bayer, convert it to ordinary RGB pixels, and emit a normal JPEG artifact; the remaining gap is automatic negotiation / standardized client integration, not basic frame delivery"
elif [[ "${gst_bayer_result}" == "ok" ]]; then
  interpretation_note="GStreamer can consume the stream only when explicit Bayer caps are forced; the remaining gap is conversion/integration, not raw delivery"
fi

if [[ "${yuyv_result}" != ok* ]]; then
  interpretation_note="${interpretation_note}; the advertised ${STANDARD_PIXEL_FORMAT} capture-node path is not currently streamable"
fi

if [[ "${gst_auto_result}" != "ok" ]]; then
  interpretation_note="${interpretation_note}; auto-negotiated v4l2src still fails"
fi

subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)
raw_stream_tail=$(tail -n 20 "${raw_stream_log_path}" 2>/dev/null || true)
yuyv_stream_tail=$(tail -n 20 "${yuyv_stream_log_path}" 2>/dev/null || true)
ffmpeg_default_tail=$(tail -n 20 "${ffmpeg_default_path}" 2>/dev/null || true)
ffmpeg_yuyv_tail=$(tail -n 20 "${ffmpeg_yuyv_path}" 2>/dev/null || true)
gst_auto_tail=$(tail -n 20 "${gst_auto_path}" 2>/dev/null || true)
gst_yuyv_tail=$(tail -n 20 "${gst_yuyv_path}" 2>/dev/null || true)
gst_bayer_tail=$(tail -n 20 "${gst_bayer_path}" 2>/dev/null || true)
gst_bayer_rgb_tail=$(tail -n 20 "${gst_bayer_rgb_path}" 2>/dev/null || true)
gst_bayer_jpeg_tail=$(tail -n 20 "${gst_bayer_jpeg_path}" 2>/dev/null || true)

{
  printf 'Source: scripts/08-userspace-bridge-check.sh\n'
  printf 'Purpose: separate raw-manual success, direct standard-pixel failure, and explicit userspace bridge success\n'
  printf '\n'
  printf 'Check start time:\n%s\n' "${check_start_local}"
  printf '\n'
  printf 'Configuration:\n'
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'sensor_format=%s/%sx%s\n' "${SENSOR_MBUS_FMT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
  printf 'working_pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'gst_bayer_format=%s\n' "${GST_BAYER_FORMAT}"
  printf 'tested_standard_pixel_format=%s\n' "${STANDARD_PIXEL_FORMAT}"
  printf 'tested_standard_pixel_ffmpeg_format=%s\n' "${STANDARD_PIXEL_FFMPEG_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'client_frame_count=%s\n' "${CLIENT_FRAME_COUNT}"
  printf 'client_timeout_s=%s\n' "${CLIENT_TIMEOUT_S}"
  printf '\n'
  printf 'Overall result:\n%s\n' "${overall_result}"
  printf '\n'
  printf 'Interpretation:\n%s\n' "${interpretation_note}"
  printf '\n'
  printf 'Known-good setup status:\n'
  printf 'optional_route=%s\n' "${route_effective_note}"
  printf 'raw_refresh=%s\n' "${raw_refresh_status}"
  printf 'yuyv_refresh=%s\n' "${yuyv_refresh_status}"
  printf 'gst_auto_refresh=%s\n' "${gst_auto_refresh_status}"
  printf 'gst_yuyv_refresh=%s\n' "${gst_yuyv_refresh_status}"
  printf 'gst_bayer_refresh=%s\n' "${gst_bayer_refresh_status}"
  printf 'gst_bayer_rgb_refresh=%s\n' "${gst_bayer_rgb_refresh_status}"
  printf 'gst_bayer_jpeg_refresh=%s\n' "${gst_bayer_jpeg_refresh_status}"
  printf '\n'
  printf 'Raw BA10 baseline:\n%s\n' "${raw_result}"
  printf '\n'
  printf 'Geometry cross-check:\n%s\n' "${geometry_summary}"
  printf '\n'
  printf 'Format inventory notes:\n'
  printf 'ffmpeg: %s\n' "${ffmpeg_format_note}"
  printf '\n'
  printf 'GStreamer plugin availability:\n'
  printf 'bayer2rgb: %s\n' "${bayer_plugin_status}"
  printf 'jpegenc: %s\n' "${jpeg_plugin_status}"
  printf '\n'
  printf 'Probe results:\n'
  printf 'ffmpeg default BA10 path: %s\n' "${ffmpeg_default_result}"
  printf 'direct %s v4l2 path: %s\n' "${STANDARD_PIXEL_FORMAT}" "${yuyv_result}"
  printf 'ffmpeg explicit %s path: %s\n' "${STANDARD_PIXEL_FORMAT}" "${ffmpeg_yuyv_result}"
  printf 'gstreamer auto path: %s\n' "${gst_auto_result}"
  printf 'gstreamer explicit %s path: %s\n' "${STANDARD_PIXEL_FORMAT}" "${gst_yuyv_result}"
  printf 'gstreamer explicit Bayer path: %s\n' "${gst_bayer_result}"
  printf 'gstreamer Bayer->RGB path: %s\n' "${gst_bayer_rgb_result}"
  printf 'gstreamer Bayer->RGB->JPEG path: %s\n' "${gst_bayer_jpeg_result}"
  printf '\n'
  printf 'JPEG artifact:\n'
  if [[ -f "${gst_bayer_jpeg_artifact}" ]]; then
    printf 'path=%s\n' "${gst_bayer_jpeg_artifact}"
    printf 'size_bytes=%s\n' "${jpeg_size}"
    if [[ -n "${jpeg_info_tail}" ]]; then
      printf '%s\n' "${jpeg_info_tail}"
    fi
  else
    printf '(not created)\n'
  fi
  printf '\n'
  printf 'Higher-level tool presence:\n'
  cat "${tool_presence_path}"
  printf '\n'
  printf 'Current v4l-subdev nodes:\n'
  if [[ -n "${subdev_nodes}" ]]; then
    printf '%s\n' "${subdev_nodes}"
  else
    printf '(none)\n'
  fi
  printf '\n'
  printf 'Raw BA10 stream tail:\n'
  if [[ -n "${raw_stream_tail}" ]]; then
    printf '%s\n' "${raw_stream_tail}"
  else
    printf '(empty)\n'
  fi
  printf '\n'
  printf 'Direct %s stream tail:\n' "${STANDARD_PIXEL_FORMAT}"
  if [[ -n "${yuyv_stream_tail}" ]]; then
    printf '%s\n' "${yuyv_stream_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'ffmpeg default BA10 tail:\n'
  if [[ -n "${ffmpeg_default_tail}" ]]; then
    printf '%s\n' "${ffmpeg_default_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'ffmpeg explicit %s tail:\n' "${STANDARD_PIXEL_FORMAT}"
  if [[ -n "${ffmpeg_yuyv_tail}" ]]; then
    printf '%s\n' "${ffmpeg_yuyv_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'gstreamer auto tail:\n'
  if [[ -n "${gst_auto_tail}" ]]; then
    printf '%s\n' "${gst_auto_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'gstreamer explicit %s tail:\n' "${STANDARD_PIXEL_FORMAT}"
  if [[ -n "${gst_yuyv_tail}" ]]; then
    printf '%s\n' "${gst_yuyv_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'gstreamer explicit Bayer tail:\n'
  if [[ -n "${gst_bayer_tail}" ]]; then
    printf '%s\n' "${gst_bayer_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'gstreamer Bayer->RGB tail:\n'
  if [[ -n "${gst_bayer_rgb_tail}" ]]; then
    printf '%s\n' "${gst_bayer_rgb_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'gstreamer Bayer->RGB->JPEG tail:\n'
  if [[ -n "${gst_bayer_jpeg_tail}" ]]; then
    printf '%s\n' "${gst_bayer_jpeg_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'Kernel journal lines since check start:\n'
  if [[ -s "${journal_path}" ]]; then
    cat "${journal_path}"
  else
    printf '(none matched)\n'
  fi
  printf '\n'
  printf 'Artifacts:\n'
  printf 'check_dir=%s\n' "${check_dir}"
  printf 'formats=%s\n' "${formats_path}"
  printf 'ffmpeg_formats=%s\n' "${ffmpeg_formats_path}"
  printf 'raw_stream_log=%s\n' "${raw_stream_log_path}"
  printf 'yuyv_stream_log=%s\n' "${yuyv_stream_log_path}"
  printf 'gst_bayer_log=%s\n' "${gst_bayer_path}"
  printf 'gst_bayer_rgb_log=%s\n' "${gst_bayer_rgb_path}"
  printf 'gst_bayer_jpeg_log=%s\n' "${gst_bayer_jpeg_path}"
} > "${summary_path}"

printf 'Userspace bridge check directory: %s\n' "${check_dir}"
printf 'Focused summary: %s\n' "${summary_path}"

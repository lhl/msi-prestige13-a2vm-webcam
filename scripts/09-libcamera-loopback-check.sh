#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="09-libcamera-loopback-check"
NOTE="numbered libcamera and v4l2loopback bridge check"
MEDIA_DEVICE="/dev/media0"
VIDEO_DEVICE="/dev/video0"
CSI2_ENTITY="Intel IPU7 CSI2 0"
CAPTURE_ENTITY="Intel IPU7 ISYS Capture 0"
SENSOR_WIDTH=2592
SENSOR_HEIGHT=1944
SENSOR_MBUS_FMT="SGRBG10_1X10"
PIXEL_FORMAT="BA10"
GST_BAYER_FORMAT="grbg10le"
BRIDGE_OUTPUT_FORMAT="YUY2"
BRIDGE_OUTPUT_FFMPEG_FORMAT="yuyv422"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20
CLIENT_FRAME_COUNT=2
CLIENT_TIMEOUT_S=20
LIBCAMERA_CAPTURE_MS=1000
LOOPBACK_BRIDGE_TIMEOUT_S=8
LOOPBACK_WAIT_S=2
LOOPBACK_DEVICE=""
LOOPBACK_DEVICE_FALLBACK="/dev/video42"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/09-libcamera-loopback-check.sh [options]

Options:
  --label NAME
      Run label passed through to scripts/webcam-run.sh
  --note TEXT
      Run note passed through to scripts/webcam-run.sh
  --media-device PATH
      Media device. Default: /dev/media0
  --video-device PATH
      Raw capture node to stream from. Default: /dev/video0
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
  --bridge-output-format NAME
      GStreamer raw output format to feed into v4l2loopback.
      Default: YUY2
  --bridge-output-ffmpeg-format NAME
      FFmpeg input format name for the loopback bridge output.
      Default: yuyv422
  --loopback-device PATH
      Existing v4l2loopback target device. Default: auto-detect first
      loopback node; if none is found, the script recommends /dev/video42.
  --stream-count N
      Number of frames for the raw base-path sanity capture. Default: 4
  --stream-buffers N
      Number of mmap buffers. Default: 4
  --stream-timeout-s N
      Timeout wrapper for raw v4l2 sanity capture in seconds. Default: 20
  --client-frame-count N
      Number of frames/buffers for higher-level probes. Default: 2
  --client-timeout-s N
      Timeout wrapper for higher-level probes in seconds. Default: 20
  --libcamera-capture-ms N
      Duration for libcamera capture probes in milliseconds. Default: 1000
  --loopback-bridge-timeout-s N
      Runtime limit for the background GStreamer -> v4l2loopback producer.
      Default: 8
  --loopback-wait-s N
      Seconds to wait after starting the loopback producer before consumer
      probes begin. Default: 2
  --dry-run
      Print planned commands without executing them.

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Re-validates the known-good raw BA10 path from script 06
  3. Checks the libcamera path:
     - tool presence
     - camera discovery commands
     - still capture if libcamera-still is present
  4. Checks the v4l2loopback path:
     - module presence / load state
     - loopback device discovery
     - explicit GStreamer Bayer bridge into the loopback node if available
     - normal client probes against the loopback node
  5. Writes a focused summary that separates:
     - raw base-path status
     - libcamera readiness
     - v4l2loopback bridge readiness
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

  if [[ ! -f "${path}" ]]; then
    printf '\n'
    return 0
  fi

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

  if [[ ! -f "${log_path}" ]]; then
    printf 'not run\n'
    return 0
  fi

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

producer_status_from_log() {
  local log_path="$1"
  local exit_status=""

  if [[ ! -f "${log_path}" ]]; then
    printf 'not run\n'
    return 0
  fi

  exit_status=$(extract_exit_status "${log_path}")
  if [[ ! "${exit_status}" =~ ^[0-9]+$ ]]; then
    printf 'unknown (no exit status found)\n'
    return 0
  fi

  if (( exit_status == 124 )); then
    printf 'ok (producer runtime window elapsed)\n'
    return 0
  fi

  if (( exit_status != 0 )); then
    printf 'failed (exit=%s)\n' "${exit_status}"
    return 0
  fi

  printf 'ok\n'
}

stream_result_from_log() {
  local log_path="$1"
  local data_path="$2"
  local exit_status=""
  local size_bytes=0

  if [[ ! -f "${log_path}" ]]; then
    printf 'not run\n'
    return 0
  fi

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

detect_loopback_device() {
  local dev=""
  local driver_info=""

  shopt -s nullglob
  for dev in /dev/video*; do
    driver_info=$(v4l2-ctl -D -d "${dev}" 2>/dev/null || true)
    if printf '%s\n' "${driver_info}" | rg -iq 'loopback'; then
      printf '%s\n' "${dev}"
      return 0
    fi
  done
  shopt -u nullglob

  return 1
}

start_background_capture_command() {
  local output_path="$1"
  shift

  {
    printf 'CMD:'
    printf ' %q' "$@"
    printf '\n'
  } > "${output_path}"

  (
    local status=0
    set +e
    "$@"
    status=$?
    set -e
    printf '\nEXIT_STATUS: %d\n' "${status}"
  ) >> "${output_path}" 2>&1 &

  BACKGROUND_CAPTURE_PID="$!"
}

wait_for_exit_status_in_log() {
  local log_path="$1"
  local attempts="${2:-20}"

  while (( attempts > 0 )); do
    if [[ -f "${log_path}" ]] && rg -q '^EXIT_STATUS: ' "${log_path}"; then
      return 0
    fi
    sleep 0.1
    attempts=$(( attempts - 1 ))
  done

  return 1
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
    --bridge-output-format)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      BRIDGE_OUTPUT_FORMAT="$1"
      ;;
    --bridge-output-ffmpeg-format)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      BRIDGE_OUTPUT_FFMPEG_FORMAT="$1"
      ;;
    --loopback-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      LOOPBACK_DEVICE="$1"
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
    --libcamera-capture-ms)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      LIBCAMERA_CAPTURE_MS="$1"
      ;;
    --loopback-bridge-timeout-s)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      LOOPBACK_BRIDGE_TIMEOUT_S="$1"
      ;;
    --loopback-wait-s)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      LOOPBACK_WAIT_S="$1"
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
CAM_AVAILABLE=0
LIBCAMERA_HELLO_AVAILABLE=0
LIBCAMERA_STILL_AVAILABLE=0
LIBCAMERA_VID_AVAILABLE=0
MODINFO_AVAILABLE=0
MODPROBE_AVAILABLE=0
LSMOD_AVAILABLE=0

have_cmd ffmpeg && FFMPEG_AVAILABLE=1
have_cmd gst-launch-1.0 && GSTREAMER_AVAILABLE=1
have_cmd gst-inspect-1.0 && GST_INSPECT_AVAILABLE=1
have_cmd file && FILE_AVAILABLE=1
have_cmd cam && CAM_AVAILABLE=1
have_cmd libcamera-hello && LIBCAMERA_HELLO_AVAILABLE=1
have_cmd libcamera-still && LIBCAMERA_STILL_AVAILABLE=1
have_cmd libcamera-vid && LIBCAMERA_VID_AVAILABLE=1
have_cmd modinfo && MODINFO_AVAILABLE=1
have_cmd modprobe && MODPROBE_AVAILABLE=1
have_cmd lsmod && LSMOD_AVAILABLE=1

cd "${REPO_ROOT}"

ROUTE_ARG="\"${CSI2_ENTITY}\" [0/0 -> 1/0 [1]]"
CSI2_SINK_FMT_ARG="\"${CSI2_ENTITY}\":0/0 [fmt:${SENSOR_MBUS_FMT}/${SENSOR_WIDTH}x${SENSOR_HEIGHT}]"
CSI2_SRC_FMT_ARG="\"${CSI2_ENTITY}\":1/0 [fmt:${SENSOR_MBUS_FMT}/${SENSOR_WIDTH}x${SENSOR_HEIGHT}]"
LINK_ARG="\"${CSI2_ENTITY}\":1 -> \"${CAPTURE_ENTITY}\":0 [1]"

loopback_device_effective="${LOOPBACK_DEVICE}"
if [[ -z "${loopback_device_effective}" ]]; then
  loopback_device_effective=$(detect_loopback_device || true)
fi
if [[ -z "${loopback_device_effective}" ]]; then
  loopback_device_effective="${LOOPBACK_DEVICE_FALLBACK}"
fi

if (( DRY_RUN )); then
  printf 'DRY_RUN: scripts/webcam-run.sh snapshot --label %q --note %q\n' "${LABEL}" "${NOTE}"
  printf 'DRY_RUN: media-ctl -d %q -R %s\n' "${MEDIA_DEVICE}" "${ROUTE_ARG}"
  printf 'DRY_RUN: refresh working BA10 setup via media-ctl + v4l2-ctl\n'
  printf 'DRY_RUN: timeout %qs v4l2-ctl -d %q --stream-mmap=%q --stream-count=%q --stream-poll --stream-to <run>/libcamera-loopback-check/%s-ba10.raw --verbose\n' \
    "${STREAM_TIMEOUT_S}" "${VIDEO_DEVICE}" "${STREAM_BUFFERS}" "${STREAM_COUNT}" "$(basename -- "${VIDEO_DEVICE}")"
  if (( CAM_AVAILABLE )); then
    printf 'DRY_RUN: cam -l\n'
  fi
  if (( LIBCAMERA_HELLO_AVAILABLE )); then
    printf 'DRY_RUN: libcamera-hello --list-cameras\n'
  fi
  if (( LIBCAMERA_STILL_AVAILABLE )); then
    printf 'DRY_RUN: libcamera-still --list-cameras\n'
    printf 'DRY_RUN: timeout %qs libcamera-still -n -t %q -o <run>/libcamera-loopback-check/libcamera-still.jpg\n' \
      "${CLIENT_TIMEOUT_S}" "${LIBCAMERA_CAPTURE_MS}"
  fi
  if (( LIBCAMERA_VID_AVAILABLE )); then
    printf 'DRY_RUN: libcamera-vid --list-cameras\n'
  fi
  printf 'DRY_RUN: loopback device target %q\n' "${loopback_device_effective}"
  printf 'DRY_RUN: modinfo v4l2loopback (if available)\n'
  printf 'DRY_RUN: lsmod | rg ^v4l2loopback (if available)\n'
  if (( GSTREAMER_AVAILABLE )); then
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -q v4l2src device=%q io-mode=mmap ! video/x-bayer,format=%q,width=%q,height=%q,framerate=30/1 ! bayer2rgb ! videoconvert ! video/x-raw,format=%q,width=%q,height=%q,framerate=30/1 ! v4l2sink device=%q sync=false\n' \
      "${LOOPBACK_BRIDGE_TIMEOUT_S}" "${VIDEO_DEVICE}" "${GST_BAYER_FORMAT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${BRIDGE_OUTPUT_FORMAT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${loopback_device_effective}"
  fi
  exit 0
fi

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory"

check_dir="${run_dir}/libcamera-loopback-check"
mkdir -p "${check_dir}"

check_start_local=$(date +"%Y-%m-%d %H:%M:%S")
video_base=$(basename -- "${VIDEO_DEVICE}")
loopback_base=$(basename -- "${loopback_device_effective}")

tool_presence_path="${check_dir}/tool-presence.txt"
manual_followup_path="${check_dir}/manual-followups.txt"
route_path="${check_dir}/step1-route.txt"
raw_refresh_path="${check_dir}/setup-ba10-refresh.txt"
raw_node_path="${check_dir}/${video_base}-ba10.txt"
raw_stream_log_path="${check_dir}/${video_base}-ba10-stream.txt"
raw_path="${check_dir}/${video_base}-ba10.raw"
libcamera_cam_list_path="${check_dir}/cam-list.txt"
libcamera_hello_list_path="${check_dir}/libcamera-hello-list-cameras.txt"
libcamera_still_list_path="${check_dir}/libcamera-still-list-cameras.txt"
libcamera_vid_list_path="${check_dir}/libcamera-vid-list-cameras.txt"
libcamera_still_capture_path="${check_dir}/libcamera-still-capture.txt"
libcamera_still_artifact="${check_dir}/libcamera-still.jpg"
libcamera_still_artifact_info_path="${check_dir}/libcamera-still.txt"
loopback_modinfo_path="${check_dir}/v4l2loopback-modinfo.txt"
loopback_lsmod_path="${check_dir}/v4l2loopback-lsmod.txt"
loopback_selected_path="${check_dir}/loopback-selected.txt"
loopback_before_path="${check_dir}/${loopback_base}-before.txt"
loopback_formats_path="${check_dir}/${loopback_base}-formats.txt"
loopback_bridge_refresh_path="${check_dir}/setup-loopback-bridge-refresh.txt"
loopback_bridge_log_path="${check_dir}/loopback-bridge-producer.txt"
loopback_stream_log_path="${check_dir}/${loopback_base}-stream.txt"
loopback_stream_path="${check_dir}/${loopback_base}.raw"
loopback_ffmpeg_path="${check_dir}/loopback-ffmpeg.txt"
loopback_gst_path="${check_dir}/loopback-gstreamer.txt"
gst_plugin_bayer_path="${check_dir}/gst-plugin-bayer2rgb.txt"
gst_plugin_sink_path="${check_dir}/gst-plugin-v4l2sink.txt"
journal_path="${check_dir}/journal-since.txt"
summary_path="${run_dir}/focused-summary.txt"

{
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'loopback_device_effective=%s\n' "${loopback_device_effective}"
  printf 'sensor_width=%s\n' "${SENSOR_WIDTH}"
  printf 'sensor_height=%s\n' "${SENSOR_HEIGHT}"
  printf 'sensor_mbus_fmt=%s\n' "${SENSOR_MBUS_FMT}"
  printf 'pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'gst_bayer_format=%s\n' "${GST_BAYER_FORMAT}"
  printf 'bridge_output_format=%s\n' "${BRIDGE_OUTPUT_FORMAT}"
  printf 'bridge_output_ffmpeg_format=%s\n' "${BRIDGE_OUTPUT_FFMPEG_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'client_frame_count=%s\n' "${CLIENT_FRAME_COUNT}"
  printf 'client_timeout_s=%s\n' "${CLIENT_TIMEOUT_S}"
  printf 'libcamera_capture_ms=%s\n' "${LIBCAMERA_CAPTURE_MS}"
  printf 'loopback_bridge_timeout_s=%s\n' "${LOOPBACK_BRIDGE_TIMEOUT_S}"
  printf 'loopback_wait_s=%s\n' "${LOOPBACK_WAIT_S}"
} > "${check_dir}/metadata.env"

{
  write_tool_presence "${tool_presence_path}" "cam"
  write_tool_presence "${tool_presence_path}" "libcamera-hello"
  write_tool_presence "${tool_presence_path}" "libcamera-still"
  write_tool_presence "${tool_presence_path}" "libcamera-vid"
  write_tool_presence "${tool_presence_path}" "gst-launch-1.0"
  write_tool_presence "${tool_presence_path}" "gst-inspect-1.0"
  write_tool_presence "${tool_presence_path}" "ffmpeg"
  write_tool_presence "${tool_presence_path}" "v4l2-ctl"
  write_tool_presence "${tool_presence_path}" "modprobe"
  write_tool_presence "${tool_presence_path}" "modinfo"
  write_tool_presence "${tool_presence_path}" "lsmod"
} >/dev/null

{
  printf 'libcamera next step:\n'
  if (( CAM_AVAILABLE || LIBCAMERA_HELLO_AVAILABLE || LIBCAMERA_STILL_AVAILABLE || LIBCAMERA_VID_AVAILABLE )); then
    printf 'libcamera-family tools are present; rerun this script after any tool/package changes if discovery or capture still fails\n'
  else
    printf 'install libcamera tools (`cam`, `libcamera-hello`, `libcamera-still`, `libcamera-vid`) and rerun this script\n'
  fi
  printf '\n'
  printf 'v4l2loopback next step:\n'
  printf 'if v4l2loopback is installed for the running kernel, create a loopback node before rerunning:\n'
  printf 'sudo modprobe v4l2loopback video_nr=42 card_label=\"MSI Webcam Bridge\" exclusive_caps=1\n'
  printf 'then rerun:\n'
  printf 'scripts/09-libcamera-loopback-check.sh --loopback-device /dev/video42\n'
} > "${manual_followup_path}"

capture_command "${route_path}" media-ctl -d "${MEDIA_DEVICE}" -R "${ROUTE_ARG}"
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

if (( CAM_AVAILABLE )); then
  capture_command "${libcamera_cam_list_path}" cam -l
else
  printf 'cam not installed\nEXIT_STATUS: 127\n' > "${libcamera_cam_list_path}"
fi

if (( LIBCAMERA_HELLO_AVAILABLE )); then
  capture_command "${libcamera_hello_list_path}" libcamera-hello --list-cameras
else
  printf 'libcamera-hello not installed\nEXIT_STATUS: 127\n' > "${libcamera_hello_list_path}"
fi

if (( LIBCAMERA_STILL_AVAILABLE )); then
  capture_command "${libcamera_still_list_path}" libcamera-still --list-cameras
  capture_command \
    "${libcamera_still_capture_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    libcamera-still \
      -n \
      -t "${LIBCAMERA_CAPTURE_MS}" \
      -o "${libcamera_still_artifact}"
else
  printf 'libcamera-still not installed\nEXIT_STATUS: 127\n' > "${libcamera_still_list_path}"
  printf 'libcamera-still not installed\nEXIT_STATUS: 127\n' > "${libcamera_still_capture_path}"
fi

if (( LIBCAMERA_VID_AVAILABLE )); then
  capture_command "${libcamera_vid_list_path}" libcamera-vid --list-cameras
else
  printf 'libcamera-vid not installed\nEXIT_STATUS: 127\n' > "${libcamera_vid_list_path}"
fi

if [[ -f "${libcamera_still_artifact}" ]] && (( FILE_AVAILABLE )); then
  capture_command "${libcamera_still_artifact_info_path}" file "${libcamera_still_artifact}"
elif [[ -f "${libcamera_still_artifact}" ]]; then
  printf 'file command unavailable\nEXIT_STATUS: 127\n' > "${libcamera_still_artifact_info_path}"
else
  printf 'libcamera still artifact not created\nEXIT_STATUS: 1\n' > "${libcamera_still_artifact_info_path}"
fi

if (( MODINFO_AVAILABLE )); then
  capture_command "${loopback_modinfo_path}" modinfo v4l2loopback
else
  printf 'modinfo not installed\nEXIT_STATUS: 127\n' > "${loopback_modinfo_path}"
fi

if (( LSMOD_AVAILABLE )); then
  capture_command "${loopback_lsmod_path}" bash -lc "lsmod | grep -E '^v4l2loopback'"
else
  printf 'lsmod not installed\nEXIT_STATUS: 127\n' > "${loopback_lsmod_path}"
fi

{
  printf 'requested_loopback_device=%s\n' "${LOOPBACK_DEVICE:-"(auto)"}"
  printf 'effective_loopback_device=%s\n' "${loopback_device_effective}"
  if [[ -e "${loopback_device_effective}" ]]; then
    printf 'effective_loopback_device_exists=yes\n'
  else
    printf 'effective_loopback_device_exists=no\n'
  fi
} > "${loopback_selected_path}"

if (( GST_INSPECT_AVAILABLE )); then
  capture_command "${gst_plugin_bayer_path}" gst-inspect-1.0 bayer2rgb
  capture_command "${gst_plugin_sink_path}" gst-inspect-1.0 v4l2sink
else
  printf 'gst-inspect-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_plugin_bayer_path}"
  printf 'gst-inspect-1.0 not installed\nEXIT_STATUS: 127\n' > "${gst_plugin_sink_path}"
fi

loopback_producer_started=0
loopback_producer_pid=""
if [[ -e "${loopback_device_effective}" ]]; then
  capture_command "${loopback_before_path}" v4l2-ctl --all -d "${loopback_device_effective}"
  capture_command "${loopback_formats_path}" v4l2-ctl --list-formats-ext -d "${loopback_device_effective}"

  if (( GSTREAMER_AVAILABLE )) && rg -q '^EXIT_STATUS: 0$' "${gst_plugin_bayer_path}" && rg -q '^EXIT_STATUS: 0$' "${gst_plugin_sink_path}"; then
    refresh_pipeline "${loopback_bridge_refresh_path}" "${PIXEL_FORMAT}"
    start_background_capture_command \
      "${loopback_bridge_log_path}" \
      timeout "${LOOPBACK_BRIDGE_TIMEOUT_S}s" \
      gst-launch-1.0 \
        -q \
        v4l2src \
        device="${VIDEO_DEVICE}" \
        io-mode=mmap \
        ! \
        video/x-bayer,format="${GST_BAYER_FORMAT}",width="${SENSOR_WIDTH}",height="${SENSOR_HEIGHT}",framerate=30/1 \
        ! \
        bayer2rgb \
        ! \
        videoconvert \
        ! \
        video/x-raw,format="${BRIDGE_OUTPUT_FORMAT}",width="${SENSOR_WIDTH}",height="${SENSOR_HEIGHT}",framerate=30/1 \
        ! \
        v4l2sink \
        device="${loopback_device_effective}" \
        sync=false
    loopback_producer_pid="${BACKGROUND_CAPTURE_PID:-}"
    loopback_producer_started=1

    sleep "${LOOPBACK_WAIT_S}"

    capture_command \
      "${loopback_stream_log_path}" \
      timeout "${CLIENT_TIMEOUT_S}s" \
      v4l2-ctl \
        -d "${loopback_device_effective}" \
        --stream-mmap="${STREAM_BUFFERS}" \
        --stream-count="${CLIENT_FRAME_COUNT}" \
        --stream-poll \
        --stream-to="${loopback_stream_path}" \
        --verbose

    if (( FFMPEG_AVAILABLE )); then
      capture_command \
        "${loopback_ffmpeg_path}" \
        timeout "${CLIENT_TIMEOUT_S}s" \
        ffmpeg \
          -hide_banner \
          -nostdin \
          -loglevel info \
          -f v4l2 \
          -input_format "${BRIDGE_OUTPUT_FFMPEG_FORMAT}" \
          -framerate 30 \
          -video_size "${SENSOR_WIDTH}x${SENSOR_HEIGHT}" \
          -i "${loopback_device_effective}" \
          -frames:v "${CLIENT_FRAME_COUNT}" \
          -f null \
          -
    else
      printf 'ffmpeg not installed\nEXIT_STATUS: 127\n' > "${loopback_ffmpeg_path}"
    fi

    if (( GSTREAMER_AVAILABLE )); then
      capture_command \
        "${loopback_gst_path}" \
        timeout "${CLIENT_TIMEOUT_S}s" \
        gst-launch-1.0 \
          -q \
          v4l2src \
          device="${loopback_device_effective}" \
          num-buffers="${CLIENT_FRAME_COUNT}" \
          ! \
          fakesink \
          sync=false
    else
      printf 'gst-launch-1.0 not installed\nEXIT_STATUS: 127\n' > "${loopback_gst_path}"
    fi

    if [[ -n "${loopback_producer_pid}" ]]; then
      set +e
      wait "${loopback_producer_pid}"
      set -e
      wait_for_exit_status_in_log "${loopback_bridge_log_path}" || true
    fi
  else
    printf 'loopback bridge prerequisites missing (gst-launch-1.0, bayer2rgb, or v4l2sink unavailable)\nEXIT_STATUS: 127\n' > "${loopback_bridge_log_path}"
    printf 'loopback bridge producer not started\nEXIT_STATUS: 127\n' > "${loopback_stream_log_path}"
    printf 'loopback bridge producer not started\nEXIT_STATUS: 127\n' > "${loopback_ffmpeg_path}"
    printf 'loopback bridge producer not started\nEXIT_STATUS: 127\n' > "${loopback_gst_path}"
  fi
else
  printf 'loopback device %s does not exist\nEXIT_STATUS: 1\n' "${loopback_device_effective}" > "${loopback_before_path}"
  printf 'loopback device %s does not exist\nEXIT_STATUS: 1\n' "${loopback_device_effective}" > "${loopback_formats_path}"
  printf 'loopback device %s does not exist\nEXIT_STATUS: 1\n' "${loopback_device_effective}" > "${loopback_bridge_log_path}"
  printf 'loopback device %s does not exist\nEXIT_STATUS: 1\n' "${loopback_device_effective}" > "${loopback_stream_log_path}"
  printf 'loopback device %s does not exist\nEXIT_STATUS: 1\n' "${loopback_device_effective}" > "${loopback_ffmpeg_path}"
  printf 'loopback device %s does not exist\nEXIT_STATUS: 1\n' "${loopback_device_effective}" > "${loopback_gst_path}"
fi

journalctl -k --since "${check_start_local}" --no-pager | \
  rg 'ov5675|intel-ipu7|ipu7|isys|subdev|video[0-9]+|stream|frame|timeout|error|failed|packet|link|loopback|libcamera' \
  > "${journal_path}" || true

raw_result=$(stream_result_from_log "${raw_stream_log_path}" "${raw_path}")
libcamera_cam_result=$(tool_status_from_log "${libcamera_cam_list_path}")
libcamera_hello_result=$(tool_status_from_log "${libcamera_hello_list_path}")
libcamera_still_list_result=$(tool_status_from_log "${libcamera_still_list_path}")
libcamera_vid_result=$(tool_status_from_log "${libcamera_vid_list_path}")
libcamera_still_capture_result=$(tool_status_from_log "${libcamera_still_capture_path}")
loopback_modinfo_result=$(tool_status_from_log "${loopback_modinfo_path}")
loopback_lsmod_result=$(tool_status_from_log "${loopback_lsmod_path}")
loopback_bridge_refresh_result=$(refresh_status_from_log "${loopback_bridge_refresh_path}")
loopback_stream_result=$(stream_result_from_log "${loopback_stream_log_path}" "${loopback_stream_path}")
loopback_ffmpeg_result=$(tool_status_from_log "${loopback_ffmpeg_path}")
loopback_gst_result=$(tool_status_from_log "${loopback_gst_path}")
loopback_bridge_result=$(producer_status_from_log "${loopback_bridge_log_path}")
if [[ "${loopback_bridge_result}" == "unknown (no exit status found)" ]] && \
  [[ "${loopback_stream_result}" == ok* || "${loopback_ffmpeg_result}" == "ok" || "${loopback_gst_result}" == "ok" ]]; then
  loopback_bridge_result="ok (consumer success confirms producer)"
fi

libcamera_still_size=$(file_size_bytes "${libcamera_still_artifact}")
loopback_still_info=$(tail -n 5 "${libcamera_still_artifact_info_path}" 2>/dev/null || true)

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

libcamera_status="not ready locally"
if (( CAM_AVAILABLE || LIBCAMERA_HELLO_AVAILABLE || LIBCAMERA_STILL_AVAILABLE || LIBCAMERA_VID_AVAILABLE )); then
  libcamera_status="tools present"
  if [[ "${libcamera_still_capture_result}" == "ok" && "${libcamera_still_size}" -gt 0 ]]; then
    libcamera_status="still capture succeeded"
  elif [[ "${libcamera_cam_result}" == "ok" || "${libcamera_hello_result}" == "ok" || "${libcamera_still_list_result}" == "ok" || "${libcamera_vid_result}" == "ok" ]]; then
    libcamera_status="camera discovery partially working"
  else
    libcamera_status="tools present but discovery/capture failed"
  fi
fi

loopback_status="not ready locally"
if [[ -e "${loopback_device_effective}" ]]; then
  loopback_status="device present"
  if [[ "${loopback_stream_result}" == ok* || "${loopback_ffmpeg_result}" == "ok" || "${loopback_gst_result}" == "ok" ]]; then
    loopback_status="bridge consumer succeeded"
  elif [[ "${loopback_bridge_result}" == ok* ]]; then
    loopback_status="producer ran, but consumer probe failed"
  else
    loopback_status="device present but bridge failed"
  fi
elif [[ "${loopback_modinfo_result}" == "ok" || "${loopback_lsmod_result}" == "ok" ]]; then
  loopback_status="module surface present, but no loopback device configured"
fi

overall_result="next-step prerequisites still missing"
if [[ "${libcamera_status}" == "still capture succeeded" || "${libcamera_status}" == "camera discovery partially working" ]]; then
  overall_result="libcamera path has moved from pure prerequisite state into runnable evidence"
fi
if [[ "${loopback_status}" == "bridge consumer succeeded" ]]; then
  overall_result="v4l2loopback bridge path is runnable and consumer-facing"
elif [[ "${overall_result}" == "next-step prerequisites still missing" && "${loopback_status}" != "not ready locally" ]]; then
  overall_result="v4l2loopback path is partially prepared but not yet consumer-ready"
fi

route_effective_note="route setup failed"
if rg -q 'Operation not supported' "${route_path}"; then
  route_effective_note="ENOTSUP on IPU7 CSI2 (expected; route step not required)"
elif [[ "$(extract_exit_status "${route_path}")" == "0" ]]; then
  route_effective_note="configured successfully"
fi

raw_stream_tail=$(tail -n 20 "${raw_stream_log_path}" 2>/dev/null || true)
libcamera_cam_tail=$(tail -n 20 "${libcamera_cam_list_path}" 2>/dev/null || true)
libcamera_hello_tail=$(tail -n 20 "${libcamera_hello_list_path}" 2>/dev/null || true)
libcamera_still_tail=$(tail -n 20 "${libcamera_still_capture_path}" 2>/dev/null || true)
loopback_bridge_tail=$(tail -n 20 "${loopback_bridge_log_path}" 2>/dev/null || true)
loopback_ffmpeg_tail=$(tail -n 20 "${loopback_ffmpeg_path}" 2>/dev/null || true)
loopback_gst_tail=$(tail -n 20 "${loopback_gst_path}" 2>/dev/null || true)
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)

{
  printf 'Source: scripts/09-libcamera-loopback-check.sh\n'
  printf 'Purpose: document and probe both next normal-usage paths: libcamera and v4l2loopback\n'
  printf '\n'
  printf 'Check start time:\n%s\n' "${check_start_local}"
  printf '\n'
  printf 'Configuration:\n'
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'loopback_device_effective=%s\n' "${loopback_device_effective}"
  printf 'sensor_format=%s/%sx%s\n' "${SENSOR_MBUS_FMT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
  printf 'working_pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'gst_bayer_format=%s\n' "${GST_BAYER_FORMAT}"
  printf 'bridge_output_format=%s\n' "${BRIDGE_OUTPUT_FORMAT}"
  printf 'bridge_output_ffmpeg_format=%s\n' "${BRIDGE_OUTPUT_FFMPEG_FORMAT}"
  printf '\n'
  printf 'Overall result:\n%s\n' "${overall_result}"
  printf '\n'
  printf 'Known-good raw setup status:\n'
  printf 'optional_route=%s\n' "${route_effective_note}"
  printf 'raw_refresh=%s\n' "$(refresh_status_from_log "${raw_refresh_path}")"
  printf 'raw_result=%s\n' "${raw_result}"
  printf 'geometry=%s\n' "${geometry_summary}"
  printf '\n'
  printf 'Libcamera path:\n'
  printf 'status=%s\n' "${libcamera_status}"
  printf 'cam_list=%s\n' "${libcamera_cam_result}"
  printf 'libcamera_hello_list=%s\n' "${libcamera_hello_result}"
  printf 'libcamera_still_list=%s\n' "${libcamera_still_list_result}"
  printf 'libcamera_vid_list=%s\n' "${libcamera_vid_result}"
  printf 'libcamera_still_capture=%s\n' "${libcamera_still_capture_result}"
  if [[ -f "${libcamera_still_artifact}" ]]; then
    printf 'libcamera_still_artifact=%s (%s bytes)\n' "${libcamera_still_artifact}" "${libcamera_still_size}"
    if [[ -n "${loopback_still_info}" ]]; then
      printf '%s\n' "${loopback_still_info}"
    fi
  fi
  printf '\n'
  printf 'v4l2loopback path:\n'
  printf 'status=%s\n' "${loopback_status}"
  printf 'modinfo=%s\n' "${loopback_modinfo_result}"
  printf 'lsmod=%s\n' "${loopback_lsmod_result}"
  printf 'loopback_device_exists=%s\n' "$(if [[ -e "${loopback_device_effective}" ]]; then printf 'yes'; else printf 'no'; fi)"
  printf 'bridge_refresh=%s\n' "${loopback_bridge_refresh_result}"
  printf 'bridge_producer=%s\n' "${loopback_bridge_result}"
  printf 'loopback_v4l2=%s\n' "${loopback_stream_result}"
  printf 'loopback_ffmpeg=%s\n' "${loopback_ffmpeg_result}"
  printf 'loopback_gstreamer=%s\n' "${loopback_gst_result}"
  printf '\n'
  printf 'Manual follow-ups:\n'
  cat "${manual_followup_path}"
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
  printf 'cam -l tail:\n'
  if [[ -n "${libcamera_cam_tail}" ]]; then
    printf '%s\n' "${libcamera_cam_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'libcamera-hello --list-cameras tail:\n'
  if [[ -n "${libcamera_hello_tail}" ]]; then
    printf '%s\n' "${libcamera_hello_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'libcamera-still capture tail:\n'
  if [[ -n "${libcamera_still_tail}" ]]; then
    printf '%s\n' "${libcamera_still_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'v4l2loopback producer tail:\n'
  if [[ -n "${loopback_bridge_tail}" ]]; then
    printf '%s\n' "${loopback_bridge_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'v4l2loopback ffmpeg tail:\n'
  if [[ -n "${loopback_ffmpeg_tail}" ]]; then
    printf '%s\n' "${loopback_ffmpeg_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'v4l2loopback gstreamer tail:\n'
  if [[ -n "${loopback_gst_tail}" ]]; then
    printf '%s\n' "${loopback_gst_tail}"
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
  printf 'raw_stream_log=%s\n' "${raw_stream_log_path}"
  printf 'libcamera_still_capture_log=%s\n' "${libcamera_still_capture_path}"
  printf 'loopback_bridge_log=%s\n' "${loopback_bridge_log_path}"
  printf 'loopback_ffmpeg_log=%s\n' "${loopback_ffmpeg_path}"
  printf 'loopback_gstreamer_log=%s\n' "${loopback_gst_path}"
} > "${summary_path}"

printf 'Libcamera/loopback check directory: %s\n' "${check_dir}"
printf 'Focused summary: %s\n' "${summary_path}"

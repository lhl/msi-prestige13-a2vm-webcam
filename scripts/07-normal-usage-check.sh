#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="07-normal-usage-check"
NOTE="numbered normal-usage readiness check"
MEDIA_DEVICE="/dev/media0"
VIDEO_DEVICE="/dev/video0"
CSI2_ENTITY="Intel IPU7 CSI2 0"
CAPTURE_ENTITY="Intel IPU7 ISYS Capture 0"
SENSOR_WIDTH=2592
SENSOR_HEIGHT=1944
SENSOR_MBUS_FMT="SGRBG10_1X10"
PIXEL_FORMAT="BA10"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20
CLIENT_FRAME_COUNT=4
CLIENT_TIMEOUT_S=20
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/07-normal-usage-check.sh [options]

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
      V4L2 pixel format for the capture node. Default: BA10
  --stream-count N
      Number of frames for the raw v4l2 sanity capture. Default: 4
  --stream-buffers N
      Number of mmap buffers. Default: 4
  --stream-timeout-s N
      Timeout wrapper for the raw v4l2 sanity capture in seconds. Default: 20
  --client-frame-count N
      Number of frames for each higher-level client probe. Default: 4
  --client-timeout-s N
      Timeout wrapper for each higher-level client probe in seconds. Default: 20
  --dry-run
      Print planned commands without executing them.

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Records tool availability for higher-level camera clients
  3. Applies the known-good userspace media-pipeline setup from script 06
  4. Verifies the raw base path with one v4l2-ctl sanity capture
  5. Runs headless higher-level probes for installed CLI tools:
     - ffmpeg
     - gst-launch-1.0
     - mpv
  6. Records GUI/manual-only tool presence (for example cheese)
  7. Writes a focused summary that says whether any non-v4l2-ctl client
     consumed frames after the known-good pipeline setup
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
have_cmd od || die "missing required command: od"
have_cmd rg || die "missing required command: rg"
have_cmd timeout || die "missing required command: timeout"
have_cmd v4l2-ctl || die "missing required command: v4l2-ctl"

cd "${REPO_ROOT}"

ROUTE_ARG="\"${CSI2_ENTITY}\" [0/0 -> 1/0 [1]]"
CSI2_SINK_FMT_ARG="\"${CSI2_ENTITY}\":0/0 [fmt:${SENSOR_MBUS_FMT}/${SENSOR_WIDTH}x${SENSOR_HEIGHT}]"
CSI2_SRC_FMT_ARG="\"${CSI2_ENTITY}\":1/0 [fmt:${SENSOR_MBUS_FMT}/${SENSOR_WIDTH}x${SENSOR_HEIGHT}]"
LINK_ARG="\"${CSI2_ENTITY}\":1 -> \"${CAPTURE_ENTITY}\":0 [1]"

FFMPEG_AVAILABLE=0
GSTREAMER_AVAILABLE=0
MPV_AVAILABLE=0
CHEESE_AVAILABLE=0
LIBCAMERA_HELLO_AVAILABLE=0
LIBCAMERA_STILL_AVAILABLE=0
LIBCAMERA_VID_AVAILABLE=0
CAM_AVAILABLE=0

have_cmd ffmpeg && FFMPEG_AVAILABLE=1
have_cmd gst-launch-1.0 && GSTREAMER_AVAILABLE=1
have_cmd mpv && MPV_AVAILABLE=1
have_cmd cheese && CHEESE_AVAILABLE=1
have_cmd libcamera-hello && LIBCAMERA_HELLO_AVAILABLE=1
have_cmd libcamera-still && LIBCAMERA_STILL_AVAILABLE=1
have_cmd libcamera-vid && LIBCAMERA_VID_AVAILABLE=1
have_cmd cam && CAM_AVAILABLE=1

if (( DRY_RUN )); then
  printf 'DRY_RUN: scripts/webcam-run.sh snapshot --label %q --note %q\n' "${LABEL}" "${NOTE}"
  printf 'DRY_RUN: media-ctl -p -d %q  (pre-setup)\n' "${MEDIA_DEVICE}"
  printf 'DRY_RUN: media-ctl -d %q -R %s\n' "${MEDIA_DEVICE}" "${ROUTE_ARG}"
  printf 'DRY_RUN: media-ctl -d %q -V %s\n' "${MEDIA_DEVICE}" "${CSI2_SINK_FMT_ARG}"
  printf 'DRY_RUN: media-ctl -d %q -V %s\n' "${MEDIA_DEVICE}" "${CSI2_SRC_FMT_ARG}"
  printf 'DRY_RUN: media-ctl -d %q -l %s\n' "${MEDIA_DEVICE}" "${LINK_ARG}"
  printf 'DRY_RUN: v4l2-ctl -d %q --set-fmt-video=width=%q,height=%q,pixelformat=%q\n' \
    "${VIDEO_DEVICE}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${PIXEL_FORMAT}"
  printf 'DRY_RUN: media-ctl -p -d %q  (post-setup)\n' "${MEDIA_DEVICE}"
  printf 'DRY_RUN: timeout %qs v4l2-ctl -d %q --stream-mmap=%q --stream-count=%q --stream-poll --stream-to <run>/normal-usage-check/%s-v4l2-stream.raw --verbose\n' \
    "${STREAM_TIMEOUT_S}" "${VIDEO_DEVICE}" "${STREAM_BUFFERS}" "${STREAM_COUNT}" "$(basename -- "${VIDEO_DEVICE}")"
  if (( FFMPEG_AVAILABLE )); then
    printf 'DRY_RUN: timeout %qs ffmpeg -hide_banner -nostdin -loglevel info -f v4l2 -framerate 30 -video_size %qx%q -i %q -frames:v %q -f null -\n' \
      "${CLIENT_TIMEOUT_S}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}"
  fi
  if (( GSTREAMER_AVAILABLE )); then
    printf 'DRY_RUN: timeout %qs gst-launch-1.0 -q v4l2src device=%q num-buffers=%q ! fakesink sync=false\n' \
      "${CLIENT_TIMEOUT_S}" "${VIDEO_DEVICE}" "${CLIENT_FRAME_COUNT}"
  fi
  if (( MPV_AVAILABLE )); then
    printf 'DRY_RUN: timeout %qs mpv --no-config --vo=null --ao=null --frames=%q --untimed --no-cache --profile=sw-fast --msg-level=all=info av://v4l2:%q\n' \
      "${CLIENT_TIMEOUT_S}" "${CLIENT_FRAME_COUNT}" "${VIDEO_DEVICE}"
  fi
  exit 0
fi

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory"

check_dir="${run_dir}/normal-usage-check"
mkdir -p "${check_dir}"

check_start_local=$(date +"%Y-%m-%d %H:%M:%S")
video_base=$(basename -- "${VIDEO_DEVICE}")

pre_media_path="${check_dir}/media-ctl-pre.txt"
post_media_path="${check_dir}/media-ctl-post.txt"
route_path="${check_dir}/step1-route.txt"
sink_fmt_path="${check_dir}/step2-csi2-sink-fmt.txt"
src_fmt_path="${check_dir}/step3-csi2-src-fmt.txt"
link_path="${check_dir}/step4-link-enable.txt"
node_fmt_path="${check_dir}/step5-node-fmt.txt"
node_before_path="${check_dir}/${video_base}-before.txt"
node_after_path="${check_dir}/${video_base}-after.txt"
raw_stream_log_path="${check_dir}/${video_base}-v4l2-stream.txt"
raw_path="${check_dir}/${video_base}-v4l2-stream.raw"
raw_head_path="${check_dir}/${video_base}-v4l2-stream-head.txt"
journal_path="${check_dir}/journal-since.txt"
tool_presence_path="${check_dir}/tool-presence.txt"
ffmpeg_refresh_path="${check_dir}/ffmpeg-setup-refresh.txt"
ffmpeg_log_path="${check_dir}/ffmpeg-probe.txt"
gstreamer_refresh_path="${check_dir}/gstreamer-setup-refresh.txt"
gstreamer_log_path="${check_dir}/gstreamer-probe.txt"
mpv_refresh_path="${check_dir}/mpv-setup-refresh.txt"
mpv_log_path="${check_dir}/mpv-probe.txt"
manual_followup_path="${check_dir}/manual-followups.txt"
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
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'client_frame_count=%s\n' "${CLIENT_FRAME_COUNT}"
  printf 'client_timeout_s=%s\n' "${CLIENT_TIMEOUT_S}"
} > "${check_dir}/metadata.env"

{
  write_tool_presence "${tool_presence_path}" "ffmpeg"
  write_tool_presence "${tool_presence_path}" "gst-launch-1.0"
  write_tool_presence "${tool_presence_path}" "mpv"
  write_tool_presence "${tool_presence_path}" "cheese"
  write_tool_presence "${tool_presence_path}" "libcamera-hello"
  write_tool_presence "${tool_presence_path}" "libcamera-still"
  write_tool_presence "${tool_presence_path}" "libcamera-vid"
  write_tool_presence "${tool_presence_path}" "cam"
} >/dev/null

{
  printf 'GUI/manual follow-ups:\n'
  if (( CHEESE_AVAILABLE )); then
    printf 'cheese: present; not auto-run because it requires an interactive desktop session\n'
  else
    printf 'cheese: missing\n'
  fi
  if (( LIBCAMERA_HELLO_AVAILABLE || LIBCAMERA_STILL_AVAILABLE || LIBCAMERA_VID_AVAILABLE || CAM_AVAILABLE )); then
    printf 'libcamera-family tools: present; not auto-run here because they may need pipeline-handler specific follow-up\n'
  else
    printf 'libcamera-family tools: missing on this machine\n'
  fi
} > "${manual_followup_path}"

# -- pre-setup state --
capture_command "${pre_media_path}" media-ctl -p -d "${MEDIA_DEVICE}"
capture_command "${node_before_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"

# -- known-good setup from script 06 --
capture_command "${route_path}" media-ctl -d "${MEDIA_DEVICE}" -R "${ROUTE_ARG}"
route_status=$(extract_exit_status "${route_path}")

capture_command "${sink_fmt_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SINK_FMT_ARG}"
sink_fmt_status=$(extract_exit_status "${sink_fmt_path}")

capture_command "${src_fmt_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SRC_FMT_ARG}"
src_fmt_status=$(extract_exit_status "${src_fmt_path}")

capture_command "${link_path}" media-ctl -d "${MEDIA_DEVICE}" -l "${LINK_ARG}"
link_status=$(extract_exit_status "${link_path}")

capture_command "${node_fmt_path}" \
  v4l2-ctl -d "${VIDEO_DEVICE}" \
    --set-fmt-video="width=${SENSOR_WIDTH},height=${SENSOR_HEIGHT},pixelformat=${PIXEL_FORMAT}"
node_fmt_status=$(extract_exit_status "${node_fmt_path}")

capture_command "${post_media_path}" media-ctl -p -d "${MEDIA_DEVICE}"
capture_command "${node_after_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"

# -- raw v4l2 sanity capture --
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
raw_stream_status=$(extract_exit_status "${raw_stream_log_path}")
raw_size=$(file_size_bytes "${raw_path}")

if [[ -s "${raw_path}" ]]; then
  od -An -tx1 -N 64 "${raw_path}" > "${raw_head_path}" 2>&1 || true
else
  printf '(raw capture file missing or empty)\n' > "${raw_head_path}"
fi

# -- higher-level client probes --
ffmpeg_result="not installed"
gstreamer_result="not installed"
mpv_result="not installed"

if (( FFMPEG_AVAILABLE )); then
  : > "${ffmpeg_refresh_path}"
  capture_command_append "${ffmpeg_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SINK_FMT_ARG}"
  capture_command_append "${ffmpeg_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SRC_FMT_ARG}"
  capture_command_append "${ffmpeg_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -l "${LINK_ARG}"
  capture_command_append "${ffmpeg_refresh_path}" \
    v4l2-ctl -d "${VIDEO_DEVICE}" \
      --set-fmt-video="width=${SENSOR_WIDTH},height=${SENSOR_HEIGHT},pixelformat=${PIXEL_FORMAT}"
  capture_command \
    "${ffmpeg_log_path}" \
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
  ffmpeg_result=$(tool_status_from_log "${ffmpeg_log_path}" 'frame=')
fi

if (( GSTREAMER_AVAILABLE )); then
  : > "${gstreamer_refresh_path}"
  capture_command_append "${gstreamer_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SINK_FMT_ARG}"
  capture_command_append "${gstreamer_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SRC_FMT_ARG}"
  capture_command_append "${gstreamer_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -l "${LINK_ARG}"
  capture_command_append "${gstreamer_refresh_path}" \
    v4l2-ctl -d "${VIDEO_DEVICE}" \
      --set-fmt-video="width=${SENSOR_WIDTH},height=${SENSOR_HEIGHT},pixelformat=${PIXEL_FORMAT}"
  capture_command \
    "${gstreamer_log_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    gst-launch-1.0 \
      -q \
      v4l2src \
      device="${VIDEO_DEVICE}" \
      num-buffers="${CLIENT_FRAME_COUNT}" \
      ! \
      fakesink \
      sync=false
  gstreamer_result=$(tool_status_from_log "${gstreamer_log_path}")
fi

if (( MPV_AVAILABLE )); then
  : > "${mpv_refresh_path}"
  capture_command_append "${mpv_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SINK_FMT_ARG}"
  capture_command_append "${mpv_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SRC_FMT_ARG}"
  capture_command_append "${mpv_refresh_path}" media-ctl -d "${MEDIA_DEVICE}" -l "${LINK_ARG}"
  capture_command_append "${mpv_refresh_path}" \
    v4l2-ctl -d "${VIDEO_DEVICE}" \
      --set-fmt-video="width=${SENSOR_WIDTH},height=${SENSOR_HEIGHT},pixelformat=${PIXEL_FORMAT}"
  capture_command \
    "${mpv_log_path}" \
    timeout "${CLIENT_TIMEOUT_S}s" \
    mpv \
      --no-config \
      --vo=null \
      --ao=null \
      --frames="${CLIENT_FRAME_COUNT}" \
      --untimed \
      --no-cache \
      --profile=sw-fast \
      --msg-level=all=info \
      "av://v4l2:${VIDEO_DEVICE}"
  mpv_result=$(tool_status_from_log "${mpv_log_path}" 'Video:')
fi

journalctl -k --since "${check_start_local}" --no-pager | \
  rg 'ov5675|intel-ipu7|ipu7|isys|subdev|video[0-9]+|stream|frame|timeout|error|failed|packet|link' \
  > "${journal_path}" || true

route_effective_note="route setup failed"
if [[ "${route_status}" == "0" ]]; then
  route_effective_note="configured successfully"
elif rg -q 'Operation not supported' "${route_path}"; then
  route_effective_note="ENOTSUP on IPU7 CSI2 (expected; route step not required)"
fi

setup_required_ok=1
for s in "${sink_fmt_status}" "${src_fmt_status}" "${link_status}" "${node_fmt_status}"; do
  if [[ "${s}" != "0" ]]; then
    setup_required_ok=0
    break
  fi
done

bytes_per_line=$(extract_v4l2_field "${node_after_path}" 'Bytes per Line')
size_image=$(extract_v4l2_field "${node_after_path}" 'Size Image')
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

raw_v4l2_result="raw v4l2 sanity capture failed"
if [[ "${raw_stream_status}" =~ ^[0-9]+$ && "${raw_stream_status}" == "0" && "${raw_size}" -gt 0 ]]; then
  raw_v4l2_result="raw v4l2 sanity capture succeeded (${raw_size} bytes)"
fi

headless_probe_ok_count=0
for result in "${ffmpeg_result}" "${gstreamer_result}" "${mpv_result}"; do
  if [[ "${result}" == "ok" ]]; then
    ((headless_probe_ok_count+=1))
  fi
done

overall_result="gap remains: raw capture may work, but no higher-level client succeeded yet"
if [[ "${raw_v4l2_result}" == raw\ v4l2\ sanity\ capture\ succeeded* ]]; then
  if (( headless_probe_ok_count > 0 )); then
    overall_result="partial normal-usage progress: raw capture works and at least one non-v4l2-ctl client consumed frames after manual pipeline setup"
  else
    overall_result="gap remains: raw capture works after manual pipeline setup, but none of the probed higher-level headless clients succeeded"
  fi
fi

raw_stream_tail=$(tail -n 20 "${raw_stream_log_path}" 2>/dev/null || true)
ffmpeg_tail=$(tail -n 20 "${ffmpeg_log_path}" 2>/dev/null || true)
gstreamer_tail=$(tail -n 20 "${gstreamer_log_path}" 2>/dev/null || true)
mpv_tail=$(tail -n 20 "${mpv_log_path}" 2>/dev/null || true)
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)

{
  printf 'Source: scripts/07-normal-usage-check.sh\n'
  printf 'Purpose: test whether known-good manual pipeline setup is enough for higher-level userspace clients\n'
  printf '\n'
  printf 'Check start time:\n%s\n' "${check_start_local}"
  printf '\n'
  printf 'Configuration:\n'
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'sensor_format=%s/%sx%s\n' "${SENSOR_MBUS_FMT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
  printf 'pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'client_frame_count=%s\n' "${CLIENT_FRAME_COUNT}"
  printf 'client_timeout_s=%s\n' "${CLIENT_TIMEOUT_S}"
  printf '\n'
  printf 'Overall result:\n%s\n' "${overall_result}"
  printf '\n'
  printf 'Known-good setup status:\n'
  printf 'optional_route=%s\n' "${route_effective_note}"
  printf 'required_steps=%s\n' "$(if (( setup_required_ok )); then printf 'ok'; else printf 'failed'; fi)"
  printf '\n'
  printf 'Raw base-path sanity:\n%s\n' "${raw_v4l2_result}"
  printf '\n'
  printf 'Geometry cross-check:\n%s\n' "${geometry_summary}"
  printf '\n'
  printf 'Higher-level tool presence:\n'
  cat "${tool_presence_path}"
  printf '\n'
  printf 'Higher-level probe results:\n'
  printf 'ffmpeg: %s\n' "${ffmpeg_result}"
  printf 'gst-launch-1.0: %s\n' "${gstreamer_result}"
  printf 'mpv: %s\n' "${mpv_result}"
  printf '\n'
  printf 'GUI/manual-only follow-ups:\n'
  cat "${manual_followup_path}"
  printf '\n'
  printf 'Current v4l-subdev nodes:\n'
  if [[ -n "${subdev_nodes}" ]]; then
    printf '%s\n' "${subdev_nodes}"
  else
    printf '(none)\n'
  fi
  printf '\n'
  printf 'Raw v4l2 stream tail:\n'
  if [[ -n "${raw_stream_tail}" ]]; then
    printf '%s\n' "${raw_stream_tail}"
  else
    printf '(empty)\n'
  fi
  printf '\n'
  printf 'ffmpeg tail:\n'
  if [[ -n "${ffmpeg_tail}" ]]; then
    printf '%s\n' "${ffmpeg_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'gst-launch-1.0 tail:\n'
  if [[ -n "${gstreamer_tail}" ]]; then
    printf '%s\n' "${gstreamer_tail}"
  else
    printf '(not run)\n'
  fi
  printf '\n'
  printf 'mpv tail:\n'
  if [[ -n "${mpv_tail}" ]]; then
    printf '%s\n' "${mpv_tail}"
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
  printf 'Raw capture first 64 bytes:\n'
  cat "${raw_head_path}"
  printf '\n'
  printf 'Artifacts:\n'
  printf 'check_dir=%s\n' "${check_dir}"
  printf 'pre_media=%s\n' "${pre_media_path}"
  printf 'post_media=%s\n' "${post_media_path}"
  printf 'raw_stream_log=%s\n' "${raw_stream_log_path}"
  printf 'ffmpeg_log=%s\n' "${ffmpeg_log_path}"
  printf 'gstreamer_log=%s\n' "${gstreamer_log_path}"
  printf 'mpv_log=%s\n' "${mpv_log_path}"
} > "${summary_path}"

printf 'Normal-usage check directory: %s\n' "${check_dir}"
printf 'Focused summary: %s\n' "${summary_path}"

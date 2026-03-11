#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="06-media-pipeline-setup"
NOTE="numbered media pipeline route/link/format setup and capture attempt"
MEDIA_DEVICE="/dev/media0"
VIDEO_DEVICE="/dev/video0"
CSI2_ENTITY="Intel IPU7 CSI2 0"
SENSOR_ENTITY="ov5675 10-0036"
CAPTURE_ENTITY="Intel IPU7 ISYS Capture 0"
SENSOR_WIDTH=2592
SENSOR_HEIGHT=1944
SENSOR_MBUS_FMT="SGRBG10_1X10"
PIXEL_FORMAT="BA10"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/06-media-pipeline-setup.sh [options]

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
      Number of frames to request. Default: 4
  --stream-buffers N
      Number of mmap buffers. Default: 4
  --stream-timeout-s N
      Timeout wrapper for the stream command in seconds. Default: 20
  --dry-run
      Print planned commands without executing them.

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Records the pre-setup media graph
  3. Attempts route, link, and format setup via media-ctl:
     a. Set route on CSI2 subdev: sink pad 0 stream 0 -> source pad 1 stream 0
     b. Set CSI2 sink pad format to match sensor output
     c. Set CSI2 source pad format to match sensor output
     d. Enable link from CSI2 source pad 1 to capture node
     e. Set video node format to match
  4. Records each setup command result (success or failure)
  5. Records the post-setup media graph
  6. Attempts a raw v4l2-ctl streaming capture
  7. Writes a focused summary with all step results

This is a no-reboot follow-up to scripts/05-userspace-format-sweep.sh.
The format sweep proved that node-side format alignment alone is
insufficient. This script tests whether explicit media-ctl route and
link setup removes the VIDIOC_STREAMON "Link has been severed" failure.
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
  printf 'DRY_RUN: timeout %qs v4l2-ctl -d %q --stream-mmap=%q --stream-count=%q --stream-poll --stream-to <run>/pipeline-setup/%s-stream.raw --verbose\n' \
    "${STREAM_TIMEOUT_S}" "${VIDEO_DEVICE}" "${STREAM_BUFFERS}" "${STREAM_COUNT}" "$(basename -- "${VIDEO_DEVICE}")"
  exit 0
fi

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory"

pipeline_dir="${run_dir}/pipeline-setup"
mkdir -p "${pipeline_dir}"

setup_start_local=$(date +"%Y-%m-%d %H:%M:%S")
video_base=$(basename -- "${VIDEO_DEVICE}")

# paths for all artifacts
pre_media_path="${pipeline_dir}/media-ctl-pre.txt"
post_media_path="${pipeline_dir}/media-ctl-post.txt"
route_path="${pipeline_dir}/step1-route.txt"
sink_fmt_path="${pipeline_dir}/step2-csi2-sink-fmt.txt"
src_fmt_path="${pipeline_dir}/step3-csi2-src-fmt.txt"
link_path="${pipeline_dir}/step4-link-enable.txt"
node_fmt_path="${pipeline_dir}/step5-node-fmt.txt"
node_before_path="${pipeline_dir}/${video_base}-before.txt"
node_after_path="${pipeline_dir}/${video_base}-after.txt"
stream_log_path="${pipeline_dir}/${video_base}-stream.txt"
raw_path="${pipeline_dir}/${video_base}-stream.raw"
raw_head_path="${pipeline_dir}/${video_base}-stream-head.txt"
journal_path="${pipeline_dir}/journal-since.txt"
summary_path="${run_dir}/focused-summary.txt"

{
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'csi2_entity=%s\n' "${CSI2_ENTITY}"
  printf 'sensor_entity=%s\n' "${SENSOR_ENTITY}"
  printf 'capture_entity=%s\n' "${CAPTURE_ENTITY}"
  printf 'sensor_width=%s\n' "${SENSOR_WIDTH}"
  printf 'sensor_height=%s\n' "${SENSOR_HEIGHT}"
  printf 'sensor_mbus_fmt=%s\n' "${SENSOR_MBUS_FMT}"
  printf 'pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
} > "${pipeline_dir}/metadata.env"

# -- pre-setup state --
capture_command "${pre_media_path}" media-ctl -p -d "${MEDIA_DEVICE}"
capture_command "${node_before_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"

# -- step 1: route --
capture_command "${route_path}" media-ctl -d "${MEDIA_DEVICE}" -R "${ROUTE_ARG}"
route_status=$(extract_exit_status "${route_path}")

# -- step 2: CSI2 sink pad format --
capture_command "${sink_fmt_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SINK_FMT_ARG}"
sink_fmt_status=$(extract_exit_status "${sink_fmt_path}")

# -- step 3: CSI2 source pad format --
capture_command "${src_fmt_path}" media-ctl -d "${MEDIA_DEVICE}" -V "${CSI2_SRC_FMT_ARG}"
src_fmt_status=$(extract_exit_status "${src_fmt_path}")

# -- step 4: link enable --
capture_command "${link_path}" media-ctl -d "${MEDIA_DEVICE}" -l "${LINK_ARG}"
link_status=$(extract_exit_status "${link_path}")

# -- step 5: video node format --
capture_command "${node_fmt_path}" \
  v4l2-ctl -d "${VIDEO_DEVICE}" \
    --set-fmt-video="width=${SENSOR_WIDTH},height=${SENSOR_HEIGHT},pixelformat=${PIXEL_FORMAT}"
node_fmt_status=$(extract_exit_status "${node_fmt_path}")

# -- post-setup state --
capture_command "${post_media_path}" media-ctl -p -d "${MEDIA_DEVICE}"
capture_command "${node_after_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"

# -- stream attempt --
capture_command \
  "${stream_log_path}" \
  timeout "${STREAM_TIMEOUT_S}s" \
  v4l2-ctl \
    -d "${VIDEO_DEVICE}" \
    --stream-mmap="${STREAM_BUFFERS}" \
    --stream-count="${STREAM_COUNT}" \
    --stream-poll \
    --stream-to="${raw_path}" \
    --verbose
stream_status=$(extract_exit_status "${stream_log_path}")

# -- journal --
journalctl -k --since "${setup_start_local}" --no-pager | \
  rg 'ov5675|intel-ipu7|ipu7|isys|subdev|video[0-9]+|stream|frame|timeout|error|failed|route|link' \
  > "${journal_path}" || true

# -- raw head --
if [[ -s "${raw_path}" ]]; then
  od -An -tx1 -N 64 "${raw_path}" > "${raw_head_path}" 2>&1 || true
else
  printf '(raw capture file missing or empty)\n' > "${raw_head_path}"
fi

# -- derive results --
raw_size=$(file_size_bytes "${raw_path}")

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

# check pre/post media graph excerpts and link state
pre_csi2_excerpt=$(rg -A 12 "entity.*${CSI2_ENTITY}" "${pre_media_path}" || true)
post_csi2_excerpt=$(rg -A 12 "entity.*${CSI2_ENTITY}" "${post_media_path}" || true)
post_link_enabled=$(rg -- "-> \"${CAPTURE_ENTITY}\".*ENABLED" "${post_media_path}" || true)

bytes_per_line=$(extract_v4l2_field "${node_after_path}" 'Bytes per Line')
size_image=$(extract_v4l2_field "${node_after_path}" 'Size Image')
first_bytesused=$(sed -n 's/.*bytesused:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${stream_log_path}" | head -n 1)
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

capture_result="no confirmed userspace frames captured"
if [[ "${stream_status}" =~ ^[0-9]+$ ]]; then
  if (( stream_status == 0 && raw_size > 0 )); then
    capture_result="stream command completed and wrote a non-empty raw file (${raw_size} bytes)"
  elif (( stream_status == 124 )); then
    capture_result="stream command hit the timeout wrapper"
  elif (( raw_size > 0 )); then
    capture_result="stream command returned non-zero but still wrote data (${raw_size} bytes)"
  fi
fi

stream_tail=$(tail -n 20 "${stream_log_path}" 2>/dev/null || true)
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)

# -- focused summary --
{
  printf 'Source: scripts/06-media-pipeline-setup.sh\n'
  printf 'Purpose: test whether explicit media-ctl route/link/format setup removes the STREAMON severed-link failure\n'
  printf '\n'
  printf 'Setup start time:\n%s\n' "${setup_start_local}"
  printf '\n'
  printf 'Pipeline configuration:\n'
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'csi2_entity=%s\n' "${CSI2_ENTITY}"
  printf 'sensor_entity=%s\n' "${SENSOR_ENTITY}"
  printf 'capture_entity=%s\n' "${CAPTURE_ENTITY}"
  printf 'sensor_format=%s/%sx%s\n' "${SENSOR_MBUS_FMT}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}"
  printf 'node_pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf '\n'
  printf 'Setup step results:\n'
  printf 'step1_route:          exit=%s  cmd: media-ctl -R %s\n' "${route_status}" "${ROUTE_ARG}"
  printf 'step2_csi2_sink_fmt:  exit=%s  cmd: media-ctl -V %s\n' "${sink_fmt_status}" "${CSI2_SINK_FMT_ARG}"
  printf 'step3_csi2_src_fmt:   exit=%s  cmd: media-ctl -V %s\n' "${src_fmt_status}" "${CSI2_SRC_FMT_ARG}"
  printf 'step4_link_enable:    exit=%s  cmd: media-ctl -l %s\n' "${link_status}" "${LINK_ARG}"
  printf 'step5_node_fmt:       exit=%s  cmd: v4l2-ctl --set-fmt-video=width=%s,height=%s,pixelformat=%s\n' \
    "${node_fmt_status}" "${SENSOR_WIDTH}" "${SENSOR_HEIGHT}" "${PIXEL_FORMAT}"
  printf '\n'
  printf 'Optional route step status:\n%s\n' "${route_effective_note}"
  printf '\n'
  printf 'Required setup steps succeeded: %s\n' "$(if (( setup_required_ok )); then printf 'yes'; else printf 'NO'; fi)"
  printf '\n'
  printf 'Pre-setup CSI2 excerpt:\n'
  if [[ -n "${pre_csi2_excerpt}" ]]; then
    printf '%s\n' "${pre_csi2_excerpt}"
  else
    printf '(entity %s not found in pre-setup media graph)\n' "${CSI2_ENTITY}"
  fi
  printf '\n'
  printf 'Post-setup CSI2 excerpt:\n'
  if [[ -n "${post_csi2_excerpt}" ]]; then
    printf '%s\n' "${post_csi2_excerpt}"
  else
    printf '(entity %s not found in post-setup media graph)\n' "${CSI2_ENTITY}"
  fi
  printf '\n'
  printf 'Post-setup link state:\n'
  if [[ -n "${post_link_enabled}" ]]; then
    printf '%s\n' "${post_link_enabled}"
  else
    printf '(link to %s not found as ENABLED in post-setup media graph)\n' "${CAPTURE_ENTITY}"
  fi
  printf '\n'
  printf 'High-level capture result:\n%s\n' "${capture_result}"
  printf '\n'
  printf 'Stream exit status:\n%s\n' "${stream_status:-unknown}"
  printf '\n'
  printf 'Raw capture size bytes:\n%s\n' "${raw_size}"
  printf '\n'
  printf 'Capture geometry cross-check:\n%s\n' "${geometry_summary}"
  printf '\n'
  printf 'Stream log tail:\n'
  if [[ -n "${stream_tail}" ]]; then
    printf '%s\n' "${stream_tail}"
  else
    printf '(empty)\n'
  fi
  printf '\n'
  printf 'Current v4l-subdev nodes:\n'
  if [[ -n "${subdev_nodes}" ]]; then
    printf '%s\n' "${subdev_nodes}"
  else
    printf '(none)\n'
  fi
  printf '\n'
  printf 'Kernel journal lines since setup start:\n'
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
  printf 'pipeline_dir=%s\n' "${pipeline_dir}"
  printf 'pre_media=%s\n' "${pre_media_path}"
  printf 'post_media=%s\n' "${post_media_path}"
  printf 'route_log=%s\n' "${route_path}"
  printf 'sink_fmt_log=%s\n' "${sink_fmt_path}"
  printf 'src_fmt_log=%s\n' "${src_fmt_path}"
  printf 'link_log=%s\n' "${link_path}"
  printf 'node_fmt_log=%s\n' "${node_fmt_path}"
  printf 'stream_log=%s\n' "${stream_log_path}"
  printf 'raw_output=%s\n' "${raw_path}"
} > "${summary_path}"

printf 'Pipeline setup directory: %s\n' "${pipeline_dir}"
printf 'Focused summary: %s\n' "${summary_path}"

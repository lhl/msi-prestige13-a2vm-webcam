#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="04-userspace-capture-check"
NOTE="numbered userspace capture checkpoint"
VIDEO_DEVICE="/dev/video0"
MEDIA_DEVICE="/dev/media0"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/04-userspace-capture-check.sh [options]

Options:
  --label NAME
      Run label passed through to scripts/webcam-run.sh
  --note TEXT
      Run note passed through to scripts/webcam-run.sh
  --video-device PATH
      Video node to stream from. Default: /dev/video0
  --media-device PATH
      Media device to inspect. Default: /dev/media0
  --stream-count N
      Number of frames to request. Default: 4
  --stream-buffers N
      Number of mmap buffers for v4l2-ctl. Default: 4
  --stream-timeout-s N
      Timeout wrapper for the stream command in seconds. Default: 20
  --dry-run
      Print the planned snapshot and stream commands without executing them.

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Records the current media graph and selected video-node details
  3. Attempts a raw v4l2-ctl streaming capture on one video node
  4. Writes a focused summary into the created run directory
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
    --video-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      VIDEO_DEVICE="$1"
      ;;
    --media-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      MEDIA_DEVICE="$1"
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

if (( DRY_RUN )); then
  printf 'DRY_RUN: scripts/webcam-run.sh snapshot --label %q --note %q\n' "${LABEL}" "${NOTE}"
  printf 'DRY_RUN: media-ctl -p -d %q\n' "${MEDIA_DEVICE}"
  printf 'DRY_RUN: v4l2-ctl --all -d %q\n' "${VIDEO_DEVICE}"
  printf 'DRY_RUN: v4l2-ctl --list-formats-ext -d %q\n' "${VIDEO_DEVICE}"
  printf 'DRY_RUN: timeout %qs v4l2-ctl -d %q --stream-mmap=%q --stream-count=%q --stream-poll --stream-to <run>/userspace-capture/%s-stream.raw --verbose\n' \
    "${STREAM_TIMEOUT_S}" "${VIDEO_DEVICE}" "${STREAM_BUFFERS}" "${STREAM_COUNT}" "$(basename -- "${VIDEO_DEVICE}")"
  exit 0
fi

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory"

capture_dir="${run_dir}/userspace-capture"
mkdir -p "${capture_dir}"

capture_start_local=$(date +"%Y-%m-%d %H:%M:%S")
video_base=$(basename -- "${VIDEO_DEVICE}")
device_node_path="${capture_dir}/${video_base}-node.txt"
formats_path="${capture_dir}/${video_base}-formats.txt"
video_all_path="${capture_dir}/${video_base}-all.txt"
media_path="${capture_dir}/media-ctl.txt"
stream_log_path="${capture_dir}/${video_base}-stream.txt"
raw_path="${capture_dir}/${video_base}-stream.raw"
raw_head_path="${capture_dir}/${video_base}-stream-head.txt"
journal_path="${capture_dir}/journal-since-capture.txt"
summary_path="${run_dir}/focused-summary.txt"

capture_command "${device_node_path}" ls -l "${VIDEO_DEVICE}"
capture_command "${formats_path}" v4l2-ctl --list-formats-ext -d "${VIDEO_DEVICE}"
capture_command "${video_all_path}" v4l2-ctl --all -d "${VIDEO_DEVICE}"
capture_command "${media_path}" media-ctl -p -d "${MEDIA_DEVICE}"
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

journalctl -k --since "${capture_start_local}" --no-pager | \
  rg 'ov5675|intel-ipu7|ipu7|isys|subdev|video[0-9]+|stream|frame|timeout|error|failed' \
  > "${journal_path}" || true

if [[ -s "${raw_path}" ]]; then
  od -An -tx1 -N 64 "${raw_path}" > "${raw_head_path}" 2>&1 || true
else
  printf '(raw capture file missing or empty)\n' > "${raw_head_path}"
fi

stream_status=$(extract_exit_status "${stream_log_path}")
raw_size=$(file_size_bytes "${raw_path}")
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)
media_excerpt=$(rg 'ov5675|CSI2 0|/dev/video0|/dev/v4l-subdev0|ENABLED,IMMUTABLE' "${media_path}" || true)
video_excerpt=$(rg 'Driver name|Card type|Capabilities|Entity Info|Name             :|Video input|Width/Height|Pixel Format|Size Image' "${video_all_path}" || true)
stream_tail=$(tail -n 20 "${stream_log_path}" 2>/dev/null || true)

capture_result="no confirmed userspace frames captured"
if [[ "${stream_status}" =~ ^[0-9]+$ ]]; then
  if (( stream_status == 0 && raw_size > 0 )); then
    capture_result="stream command completed and wrote a non-empty raw file"
  elif (( stream_status == 124 )); then
    capture_result="stream command hit the timeout wrapper"
  elif (( raw_size > 0 )); then
    capture_result="stream command returned non-zero but still wrote data"
  fi
fi

{
  printf 'Source: scripts/04-userspace-capture-check.sh\n'
  printf 'Purpose: capture the first userspace streaming result on the positive exp18 branch\n'
  printf '\n'
  printf 'Capture start time:\n%s\n' "${capture_start_local}"
  printf '\n'
  printf 'Userspace capture target:\n'
  printf 'video_device=%s\n' "${VIDEO_DEVICE}"
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'raw_output=%s\n' "${raw_path}"
  printf '\n'
  printf 'High-level result:\n%s\n' "${capture_result}"
  printf '\n'
  printf 'Selected media-graph lines:\n'
  if [[ -n "${media_excerpt}" ]]; then
    printf '%s\n' "${media_excerpt}"
  else
    printf '(none matched)\n'
  fi
  printf '\n'
  printf 'Current v4l-subdev nodes:\n'
  if [[ -n "${subdev_nodes}" ]]; then
    printf '%s\n' "${subdev_nodes}"
  else
    printf '(none)\n'
  fi
  printf '\n'
  printf 'Selected V4L2 node lines:\n'
  if [[ -n "${video_excerpt}" ]]; then
    printf '%s\n' "${video_excerpt}"
  else
    printf '(none matched)\n'
  fi
  printf '\n'
  printf 'Stream exit status:\n%s\n' "${stream_status:-unknown}"
  printf '\n'
  printf 'Raw capture size bytes:\n%s\n' "${raw_size}"
  printf '\n'
  printf 'Stream log:\n%s\n' "${stream_log_path}"
  printf '\n'
  printf 'Stream log tail:\n'
  if [[ -n "${stream_tail}" ]]; then
    printf '%s\n' "${stream_tail}"
  else
    printf '(empty)\n'
  fi
  printf '\n'
  printf 'Kernel journal lines since capture start:\n'
  if [[ -s "${journal_path}" ]]; then
    cat "${journal_path}"
  else
    printf '(none matched)\n'
  fi
  printf '\n'
  printf 'Raw capture first 64 bytes:\n'
  cat "${raw_head_path}"
} > "${summary_path}"

printf 'Userspace capture log: %s\n' "${stream_log_path}"
printf 'Userspace capture data: %s\n' "${raw_path}"
printf 'Focused summary: %s\n' "${summary_path}"

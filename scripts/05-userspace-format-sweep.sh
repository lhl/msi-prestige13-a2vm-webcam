#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="05-userspace-format-sweep"
NOTE="numbered userspace format sweep"
MEDIA_DEVICE="/dev/media0"
VIDEO_DEVICES=(
  "/dev/video0"
  "/dev/video1"
  "/dev/video2"
  "/dev/video3"
  "/dev/video4"
  "/dev/video5"
  "/dev/video6"
  "/dev/video7"
)
VIDEO_DEVICE_OVERRIDE=0
WIDTH=4096
HEIGHT=3072
PIXEL_FORMAT="BA10"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  scripts/05-userspace-format-sweep.sh [options]

Options:
  --label NAME
      Run label passed through to scripts/webcam-run.sh
  --note TEXT
      Run note passed through to scripts/webcam-run.sh
  --media-device PATH
      Media device to inspect. Default: /dev/media0
  --video-device PATH
      Video node to include in the sweep. Repeatable.
      Default sweep: /dev/video0 through /dev/video7
  --width N
      Requested capture width for every node. Default: 4096
  --height N
      Requested capture height for every node. Default: 3072
  --pixel-format FOURCC
      Requested V4L2 pixel format for every node. Default: BA10
  --stream-count N
      Number of frames to request per node. Default: 4
  --stream-buffers N
      Number of mmap buffers for each stream attempt. Default: 4
  --stream-timeout-s N
      Timeout wrapper for each stream attempt in seconds. Default: 20
  --dry-run
      Print the planned sweep without executing it.

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Records the current media graph once for the whole sweep
  3. For each selected /dev/video* node:
     - records before/after V4L2 state
     - attempts one explicit --set-fmt-video + stream capture
  4. Writes one focused summary for the whole no-reboot sweep
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
    --media-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      MEDIA_DEVICE="$1"
      ;;
    --video-device)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      if (( ! VIDEO_DEVICE_OVERRIDE )); then
        VIDEO_DEVICES=()
        VIDEO_DEVICE_OVERRIDE=1
      fi
      VIDEO_DEVICES+=("$1")
      ;;
    --width)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      WIDTH="$1"
      ;;
    --height)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      HEIGHT="$1"
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

((${#VIDEO_DEVICES[@]} > 0)) || die "no video devices selected"

have_cmd journalctl || die "missing required command: journalctl"
have_cmd media-ctl || die "missing required command: media-ctl"
have_cmd rg || die "missing required command: rg"
have_cmd timeout || die "missing required command: timeout"
have_cmd v4l2-ctl || die "missing required command: v4l2-ctl"

cd "${REPO_ROOT}"

if (( DRY_RUN )); then
  printf 'DRY_RUN: scripts/webcam-run.sh snapshot --label %q --note %q\n' "${LABEL}" "${NOTE}"
  printf 'DRY_RUN: media-ctl -p -d %q\n' "${MEDIA_DEVICE}"
  for video_device in "${VIDEO_DEVICES[@]}"; do
    video_base=$(basename -- "${video_device}")
    printf 'DRY_RUN: v4l2-ctl --all -d %q\n' "${video_device}"
    printf 'DRY_RUN: timeout %qs v4l2-ctl -d %q --set-fmt-video=width=%q,height=%q,pixelformat=%q --stream-mmap=%q --stream-count=%q --stream-poll --stream-to <run>/userspace-format-sweep/%s-stream.raw --verbose\n' \
      "${STREAM_TIMEOUT_S}" "${video_device}" "${WIDTH}" "${HEIGHT}" "${PIXEL_FORMAT}" "${STREAM_BUFFERS}" "${STREAM_COUNT}" "${video_base}"
    printf 'DRY_RUN: v4l2-ctl --all -d %q\n' "${video_device}"
  done
  exit 0
fi

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory"

sweep_dir="${run_dir}/userspace-format-sweep"
mkdir -p "${sweep_dir}"

sweep_start_local=$(date +"%Y-%m-%d %H:%M:%S")
summary_path="${run_dir}/focused-summary.txt"
media_path="${sweep_dir}/media-ctl.txt"
journal_path="${sweep_dir}/journal-since-sweep.txt"

{
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'width=%s\n' "${WIDTH}"
  printf 'height=%s\n' "${HEIGHT}"
  printf 'pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf 'video_devices='
  printf '%s ' "${VIDEO_DEVICES[@]}"
  printf '\n'
} > "${sweep_dir}/metadata.env"

capture_command "${media_path}" media-ctl -p -d "${MEDIA_DEVICE}"

sfmt_ok_count=0
streamon_link_severed_count=0
non_empty_count=0

for video_device in "${VIDEO_DEVICES[@]}"; do
  video_base=$(basename -- "${video_device}")
  node_path="${sweep_dir}/${video_base}-node.txt"
  before_path="${sweep_dir}/${video_base}-before.txt"
  after_path="${sweep_dir}/${video_base}-after.txt"
  formats_path="${sweep_dir}/${video_base}-formats.txt"
  stream_log_path="${sweep_dir}/${video_base}-stream.txt"
  raw_path="${sweep_dir}/${video_base}-stream.raw"
  size_path="${sweep_dir}/${video_base}-size.txt"

  capture_command "${node_path}" ls -l "${video_device}"
  capture_command "${formats_path}" v4l2-ctl --list-formats-ext -d "${video_device}"
  capture_command "${before_path}" v4l2-ctl --all -d "${video_device}"
  capture_command \
    "${stream_log_path}" \
    timeout "${STREAM_TIMEOUT_S}s" \
    v4l2-ctl \
      -d "${video_device}" \
      --set-fmt-video="width=${WIDTH},height=${HEIGHT},pixelformat=${PIXEL_FORMAT}" \
      --stream-mmap="${STREAM_BUFFERS}" \
      --stream-count="${STREAM_COUNT}" \
      --stream-poll \
      --stream-to="${raw_path}" \
      --verbose
  capture_command "${after_path}" v4l2-ctl --all -d "${video_device}"

  raw_size=$(file_size_bytes "${raw_path}")
  printf '%s\n' "${raw_size}" > "${size_path}"

  if rg -q 'VIDIOC_S_FMT: ok' "${stream_log_path}"; then
    ((sfmt_ok_count+=1))
  fi
  if rg -q 'VIDIOC_STREAMON returned -1 \(Link has been severed\)' "${stream_log_path}"; then
    ((streamon_link_severed_count+=1))
  fi
  if (( raw_size > 0 )); then
    ((non_empty_count+=1))
  fi
done

journalctl -k --since "${sweep_start_local}" --no-pager | \
  rg 'ov5675|intel-ipu7|ipu7|isys|subdev|video[0-9]+|stream|frame|timeout|error|failed' \
  > "${journal_path}" || true

media_excerpt=$(rg 'ov5675|CSI2 0|/dev/v4l-subdev0|ENABLED,IMMUTABLE|fmt:' "${media_path}" || true)
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)

summary_result="no tested capture node wrote data during the format sweep"
if (( non_empty_count > 0 )); then
  if (( non_empty_count == ${#VIDEO_DEVICES[@]} )); then
    summary_result="all tested capture nodes wrote non-empty raw files during the format sweep"
  else
    summary_result="at least one tested capture node wrote a non-empty raw file during the format sweep"
  fi
elif (( sfmt_ok_count == ${#VIDEO_DEVICES[@]} && streamon_link_severed_count == ${#VIDEO_DEVICES[@]} )); then
  summary_result="all tested capture nodes accepted VIDIOC_S_FMT to ${WIDTH}x${HEIGHT} ${PIXEL_FORMAT}, but all still failed VIDIOC_STREAMON with Link has been severed and wrote 0-byte raw outputs"
fi

{
  printf 'Source: scripts/05-userspace-format-sweep.sh\n'
  printf 'Purpose: repeat the no-reboot capture-node format sweep after the first exp19 severed-link result\n'
  printf '\n'
  printf 'Sweep start time:\n%s\n' "${sweep_start_local}"
  printf '\n'
  printf 'Sweep configuration:\n'
  printf 'media_device=%s\n' "${MEDIA_DEVICE}"
  printf 'video_devices='
  printf '%s ' "${VIDEO_DEVICES[@]}"
  printf '\n'
  printf 'width=%s\n' "${WIDTH}"
  printf 'height=%s\n' "${HEIGHT}"
  printf 'pixel_format=%s\n' "${PIXEL_FORMAT}"
  printf 'stream_count=%s\n' "${STREAM_COUNT}"
  printf 'stream_buffers=%s\n' "${STREAM_BUFFERS}"
  printf 'stream_timeout_s=%s\n' "${STREAM_TIMEOUT_S}"
  printf '\n'
  printf 'High-level result:\n%s\n' "${summary_result}"
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
  printf 'Per-node raw output sizes (bytes):\n'
  for video_device in "${VIDEO_DEVICES[@]}"; do
    video_base=$(basename -- "${video_device}")
    printf '%s: ' "${video_base}"
    cat "${sweep_dir}/${video_base}-size.txt"
  done
  printf '\n'
  printf 'Per-node stream result lines:\n'
  for video_device in "${VIDEO_DEVICES[@]}"; do
    video_base=$(basename -- "${video_device}")
    printf '%s:\n' "${video_base}"
    stream_excerpt=$(rg 'VIDIOC_STREAMON returned|VIDIOC_S_FMT: ok|Width/Height|Pixel Format|Size Image' "${sweep_dir}/${video_base}-stream.txt" || true)
    if [[ -n "${stream_excerpt}" ]]; then
      printf '%s\n' "${stream_excerpt}"
    else
      printf '(none matched)\n'
    fi
    printf '\n'
  done
  printf 'Kernel journal lines since sweep start:\n'
  if [[ -s "${journal_path}" ]]; then
    cat "${journal_path}"
  else
    printf '(none matched)\n'
  fi
} > "${summary_path}"

printf 'Userspace format sweep directory: %s\n' "${sweep_dir}"
printf 'Focused summary: %s\n' "${summary_path}"

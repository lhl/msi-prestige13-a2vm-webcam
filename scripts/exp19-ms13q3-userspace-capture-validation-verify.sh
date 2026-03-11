#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp19"
EXPERIMENT_SLUG="ms13q3-userspace-capture-validation"
EXPERIMENT_TITLE="MS-13Q3 userspace capture validation on exp18 branch"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp19-ms13q3-userspace-capture-validation-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='Found supported sensor|Connected 1 cameras|sensor identified on attempt|failed to find sensor|probe with driver ov5675 failed|ov5675|intel-ipu7|v4l-subdev'

VERIFY_LABEL=""
VERIFY_NOTE=""
VIDEO_DEVICE="/dev/video0"
MEDIA_DEVICE="/dev/media0"
STREAM_COUNT=4
STREAM_BUFFERS=4
STREAM_TIMEOUT_S=20

usage() {
  cat <<'EOF'
Usage:
  scripts/exp19-ms13q3-userspace-capture-validation-verify.sh [options]

Options:
  --label NAME
      Override the run label passed to scripts/04-userspace-capture-check.sh
  --note TEXT
      Override the run note passed to scripts/04-userspace-capture-check.sh
  --patch FILE
      Record an overridden experiment patch path in the summary.
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
      Print the planned userspace capture steps without executing them.
EOF
}

append_capture_experiment_summary() {
  local summary_path="$1"
  local journal_path="$2"
  local capture_dir="$3"
  local video_base="$4"

  {
    printf '\n'
    printf 'Experiment workflow:\n'
    printf 'id: %s\n' "${EXPERIMENT_ID}"
    printf 'title: %s\n' "${EXPERIMENT_TITLE}"
    printf 'doc: %s\n' "${EXPERIMENT_DOC:-}"
    printf 'default patch: %s\n' "${REPO_ROOT}/${EXPERIMENT_PATCH_DEFAULT}"
    printf 'recorded patch: %s\n' "${PATCH_PATH}"
    printf '\n'
    printf 'Experiment-specific boot lines (%s):\n' "${EXPERIMENT_VERIFY_JOURNAL_PATTERN}"
    if [[ -s "${journal_path}" ]]; then
      cat "${journal_path}"
    else
      printf '(none matched)\n'
    fi
    printf '\n'
    printf 'Userspace capture artifacts:\n'
    printf 'capture_dir=%s\n' "${capture_dir}"
    printf 'stream_log=%s\n' "${capture_dir}/${video_base}-stream.txt"
    printf 'raw_output=%s\n' "${capture_dir}/${video_base}-stream.raw"
    printf 'capture_journal=%s\n' "${capture_dir}/journal-since-capture.txt"
  } >> "${summary_path}"
}

while (($# > 0)); do
  case "$1" in
    --label)
      shift
      [[ $# -gt 0 ]] || die "--label requires a value"
      VERIFY_LABEL="$1"
      ;;
    --note)
      shift
      [[ $# -gt 0 ]] || die "--note requires a value"
      VERIFY_NOTE="$1"
      ;;
    --patch)
      shift
      [[ $# -gt 0 ]] || die "--patch requires a value"
      PATCH_PATH="$1"
      ;;
    --video-device)
      shift
      [[ $# -gt 0 ]] || die "--video-device requires a value"
      VIDEO_DEVICE="$1"
      ;;
    --media-device)
      shift
      [[ $# -gt 0 ]] || die "--media-device requires a value"
      MEDIA_DEVICE="$1"
      ;;
    --stream-count)
      shift
      [[ $# -gt 0 ]] || die "--stream-count requires a value"
      STREAM_COUNT="$1"
      ;;
    --stream-buffers)
      shift
      [[ $# -gt 0 ]] || die "--stream-buffers requires a value"
      STREAM_BUFFERS="$1"
      ;;
    --stream-timeout-s)
      shift
      [[ $# -gt 0 ]] || die "--stream-timeout-s requires a value"
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
      die "unknown argument: $1"
      ;;
  esac
  shift
done

ensure_wrapper_vars
prepare_temp_root

if [[ -z "${VERIFY_LABEL}" ]]; then
  VERIFY_LABEL="${EXPERIMENT_ID}-userspace-capture"
fi
if [[ -z "${VERIFY_NOTE}" ]]; then
  VERIFY_NOTE="${EXPERIMENT_ID} userspace capture verification"
fi
if [[ -z "${PATCH_PATH}" ]]; then
  PATCH_PATH="${REPO_ROOT}/${EXPERIMENT_PATCH_DEFAULT}"
fi
resolve_patch_path

if (( DRY_RUN )); then
  log "dry-run verify for ${EXPERIMENT_ID}"
  log "CMD: ${REPO_ROOT}/scripts/04-userspace-capture-check.sh --label ${VERIFY_LABEL@Q} --note ${VERIFY_NOTE@Q} --video-device ${VIDEO_DEVICE@Q} --media-device ${MEDIA_DEVICE@Q} --stream-count ${STREAM_COUNT@Q} --stream-buffers ${STREAM_BUFFERS@Q} --stream-timeout-s ${STREAM_TIMEOUT_S@Q}"
  log "CMD: journalctl -b -k --no-pager | rg ${EXPERIMENT_VERIFY_JOURNAL_PATTERN@Q}"
  log "dry-run verify completed without executing commands"
  exit 0
fi

capture_output=$(
  "${REPO_ROOT}/scripts/04-userspace-capture-check.sh" \
    --label "${VERIFY_LABEL}" \
    --note "${VERIFY_NOTE}" \
    --video-device "${VIDEO_DEVICE}" \
    --media-device "${MEDIA_DEVICE}" \
    --stream-count "${STREAM_COUNT}" \
    --stream-buffers "${STREAM_BUFFERS}" \
    --stream-timeout-s "${STREAM_TIMEOUT_S}"
)
printf '%s\n' "${capture_output}"

run_dir=$(printf '%s\n' "${capture_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || die "failed to determine run directory from userspace capture check"

summary_path="${run_dir}/focused-summary.txt"
journal_path="${run_dir}/experiment-journal.txt"
capture_dir="${run_dir}/userspace-capture"
video_base=$(basename -- "${VIDEO_DEVICE}")

journalctl -b -k --no-pager | rg "${EXPERIMENT_VERIFY_JOURNAL_PATTERN}" > "${journal_path}" || true

capture_module_info "${run_dir}"
normalize_run_dir_owner "${run_dir}"
append_capture_experiment_summary "${summary_path}" "${journal_path}" "${capture_dir}" "${video_base}"

printf 'Experiment journal: %s\n' "${journal_path}"
printf 'Updated summary: %s\n' "${summary_path}"

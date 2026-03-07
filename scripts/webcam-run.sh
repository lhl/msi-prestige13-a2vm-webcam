#!/usr/bin/env bash
set -u

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

ACTION="snapshot"
LABEL=""
NOTE=""
RUNS_ROOT="${REPO_ROOT}/runs"
DRY_RUN=0

RUN_START_LOCAL=$(date +"%Y-%m-%dT%H:%M:%S%z")
RUN_START_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
RUN_DATE=$(date +"%Y-%m-%d")
RUN_STAMP=$(date +"%Y%m%dT%H%M%S")

ACTION_LOG=""
RUN_DIR=""
RUN_STATUS="not-started"
RUN_FAILURE_REASON=""

usage() {
  cat <<'EOF'
Usage:
  scripts/webcam-run.sh snapshot [--label NAME] [--note TEXT] [--runs-root DIR]
  scripts/webcam-run.sh reprobe-modules [--label NAME] [--note TEXT] [--runs-root DIR] [--dry-run]

Actions:
  snapshot
      Capture the current webcam/IPU/INT3472 state without making changes.

  reprobe-modules
      Safely unload and reload the Linux camera-related modules, then capture
      before/after state. This does not do raw I2C writes or PMIC register pokes.
      Root is required unless --dry-run is used.

Options:
  --label NAME
      Short label added to the run directory name.

  --note TEXT
      Free-form note stored with the run metadata.

  --runs-root DIR
      Override the output root. Default: ./runs

  --dry-run
      Print and log the reprobe steps without executing them.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

git_safe() {
  git -c safe.directory="${REPO_ROOT}" -C "${REPO_ROOT}" "$@"
}

sanitize_label() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-'
}

ensure_dir() {
  mkdir -p -- "$1"
}

log() {
  local line
  line="[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
  printf '%s\n' "$line"
  if [[ -n "${ACTION_LOG}" ]]; then
    printf '%s\n' "$line" >> "${ACTION_LOG}"
  fi
}

write_text() {
  local path="$1"
  shift
  {
    printf '%s\n' "$@"
  } >"${path}"
}

capture_command() {
  local output_path="$1"
  shift
  local status=0

  {
    printf 'CMD:'
    printf ' %q' "$@"
    printf '\n'
    "$@"
    status=$?
    printf '\nEXIT_STATUS: %d\n' "${status}"
  } >"${output_path}" 2>&1

  return 0
}

capture_shell() {
  local output_path="$1"
  local command_string="$2"
  local status=0

  {
    printf 'CMD: %s\n' "${command_string}"
    bash -lc "${command_string}"
    status=$?
    printf '\nEXIT_STATUS: %d\n' "${status}"
  } >"${output_path}" 2>&1

  return 0
}

module_is_loaded() {
  [[ -d "/sys/module/$1" ]]
}

run_step() {
  local description="$1"
  shift
  local line=""
  line="[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ${description}"
  printf '%s\n' "${line}"

  {
    printf '%s\n' "${line}"
    printf 'CMD:'
    printf ' %q' "$@"
    printf '\n'
  } >> "${ACTION_LOG}"

  if (( DRY_RUN )); then
    printf 'EXIT_STATUS: 0 (dry-run)\n\n' >> "${ACTION_LOG}"
    return 0
  fi

  "$@" >> "${ACTION_LOG}" 2>&1
  local status=$?
  printf 'EXIT_STATUS: %d\n\n' "${status}" >> "${ACTION_LOG}"
  return "${status}"
}

require_root_for_action() {
  if (( DRY_RUN )); then
    return 0
  fi

  if [[ "${EUID}" -ne 0 ]]; then
    die "action '${ACTION}' requires root; run with sudo or use --dry-run"
  fi
}

collect_metadata() {
  local output_path="$1"
  local host_name=""

  host_name=$(hostname 2>/dev/null || uname -n 2>/dev/null || printf unknown)

  {
    printf 'run_start_local=%s\n' "${RUN_START_LOCAL}"
    printf 'run_start_utc=%s\n' "${RUN_START_UTC}"
    printf 'action=%s\n' "${ACTION}"
    printf 'label=%s\n' "${LABEL}"
    printf 'note=%s\n' "${NOTE}"
    printf 'runs_root=%s\n' "${RUNS_ROOT}"
    printf 'run_dir=%s\n' "${RUN_DIR}"
    printf 'dry_run=%s\n' "${DRY_RUN}"
    printf 'euid=%s\n' "${EUID}"
    printf 'user=%s\n' "${USER:-unknown}"
    printf 'sudo_user=%s\n' "${SUDO_USER:-}"
    printf 'hostname=%s\n' "${host_name}"
    printf 'kernel_release=%s\n' "$(uname -r)"
    printf 'kernel_full=%s\n' "$(uname -a)"
    printf 'repo_root=%s\n' "${REPO_ROOT}"
    printf 'git_head=%s\n' "$(git_safe rev-parse --short HEAD 2>/dev/null || printf unknown)"
    printf 'git_branch=%s\n' "$(git_safe rev-parse --abbrev-ref HEAD 2>/dev/null || printf unknown)"
  } >"${output_path}"
}

capture_video_nodes() {
  local output_dir="$1"
  local found=0
  ensure_dir "${output_dir}"

  local dev
  for dev in /dev/video*; do
    if [[ ! -e "${dev}" ]]; then
      continue
    fi
    found=1
    capture_command "${output_dir}/$(basename "${dev}").txt" v4l2-ctl --all -d "${dev}"
  done

  if (( ! found )); then
    write_text "${output_dir}/README.txt" "No /dev/video* nodes were present during this capture."
  fi
}

capture_stage() {
  local stage="$1"
  local stage_dir="${RUN_DIR}/${stage}"
  local sysfs_dir="${stage_dir}/sysfs"

  ensure_dir "${stage_dir}"
  ensure_dir "${sysfs_dir}"

  collect_metadata "${stage_dir}/metadata.env"
  capture_command "${stage_dir}/git-status.txt" git_safe status --short
  capture_command "${stage_dir}/dmi.txt" bash -lc "cat /sys/class/dmi/id/product_name /sys/class/dmi/id/product_version 2>/dev/null"
  capture_command "${stage_dir}/lsmod-camera.txt" bash -lc "lsmod | grep -E 'intel_ipu7|ov5675|int3472|tps68470|ipu_bridge|videodev|v4l2'"
  capture_command "${stage_dir}/modules-int3472.txt" modinfo intel_skl_int3472_tps68470
  capture_command "${stage_dir}/modules-ov5675.txt" modinfo ov5675
  capture_command "${stage_dir}/dev-nodes.txt" bash -lc "ls -l /dev/media* /dev/video* /dev/i2c-* 2>/dev/null"
  capture_command "${stage_dir}/i2c-buses.txt" i2cdetect -l
  capture_command "${stage_dir}/v4l2-list-devices.txt" v4l2-ctl --list-devices
  capture_command "${stage_dir}/media-ctl-media0.txt" media-ctl -p -d /dev/media0
  capture_video_nodes "${stage_dir}/v4l2-all"

  capture_shell "${stage_dir}/journal-relevant.txt" \
    "journalctl -k -b --no-pager | grep -En 'tps68470|INT3472|OVTI5675|ov5675|intel-ipu7|board-data|subdev|ipu7' || true"
  capture_shell "${stage_dir}/journal-since-run-start.txt" \
    "journalctl -k --since '${RUN_START_UTC}' --no-pager | grep -En 'tps68470|INT3472|OVTI5675|ov5675|intel-ipu7|board-data|subdev|ipu7' || true"

  capture_shell "${sysfs_dir}/acpi-int3472.txt" \
    "ls -l /sys/bus/acpi/devices/INT3472:06 2>/dev/null || true; find /sys/bus/acpi/devices/INT3472:06 -maxdepth 2 2>/dev/null | sort || true"
  capture_shell "${sysfs_dir}/acpi-ovti5675.txt" \
    "ls -l /sys/bus/acpi/devices/OVTI5675:00 2>/dev/null || true; find /sys/bus/acpi/devices/OVTI5675:00 -maxdepth 2 2>/dev/null | sort || true"
  capture_shell "${sysfs_dir}/physical-nodes.txt" \
    "readlink -f /sys/bus/acpi/devices/INT3472:06/physical_node 2>/dev/null || true; readlink -f /sys/bus/acpi/devices/OVTI5675:00/physical_node 2>/dev/null || true"
  capture_shell "${sysfs_dir}/i2c-bus1-tree.txt" \
    "find /sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1 -maxdepth 3 2>/dev/null | sort || true"
  capture_shell "${sysfs_dir}/driver-int3472-tps68470.txt" \
    "find /sys/bus/i2c/drivers/int3472-tps68470 -maxdepth 2 2>/dev/null | sort || true"
  capture_shell "${sysfs_dir}/driver-ov5675.txt" \
    "find /sys/bus/i2c/drivers/ov5675 -maxdepth 2 2>/dev/null | sort || true"
  capture_shell "${sysfs_dir}/i2c-devices.txt" \
    "find /sys/bus/i2c/devices -maxdepth 1 2>/dev/null | sort || true"
}

run_reprobe_modules() {
  require_root_for_action

  local unload_modules=(
    ov5675
    intel_ipu7_isys
    intel_ipu7
    intel_skl_int3472_tps68470
    intel_skl_int3472_discrete
    clk_tps68470
    tps68470_regulator
    intel_skl_int3472_common
  )
  local load_modules=(
    intel_skl_int3472_tps68470
    intel_skl_int3472_discrete
    ov5675
    intel_ipu7
    intel_ipu7_isys
  )

  local module
  for module in "${unload_modules[@]}"; do
    if module_is_loaded "${module}"; then
      run_step "unload module ${module}" modprobe -r "${module}" || return 1
    else
      log "skip unload for ${module}; module is not currently loaded"
    fi
  done

  if have_cmd udevadm; then
    run_step "settle udev after unloads" udevadm settle || return 1
  fi

  for module in "${load_modules[@]}"; do
    run_step "load module ${module}" modprobe "${module}" || return 1
  done

  if have_cmd udevadm; then
    run_step "settle udev after loads" udevadm settle || return 1
  fi

  return 0
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  ACTION="$1"
  shift

  case "${ACTION}" in
    snapshot|reprobe-modules)
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      die "unknown action: ${ACTION}"
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label)
        [[ $# -ge 2 ]] || die "--label requires a value"
        LABEL="$2"
        shift 2
        ;;
      --note)
        [[ $# -ge 2 ]] || die "--note requires a value"
        NOTE="$2"
        shift 2
        ;;
      --runs-root)
        [[ $# -ge 2 ]] || die "--runs-root requires a value"
        RUNS_ROOT="$2"
        shift 2
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
  done
}

main() {
  have_cmd media-ctl || die "media-ctl not found"
  have_cmd v4l2-ctl || die "v4l2-ctl not found"
  have_cmd i2cdetect || die "i2cdetect not found"
  have_cmd journalctl || die "journalctl not found"
  have_cmd modprobe || die "modprobe not found"

  local safe_label=""
  if [[ -n "${LABEL}" ]]; then
    safe_label=$(sanitize_label "${LABEL}")
  fi

  RUN_DIR="${RUNS_ROOT}/${RUN_DATE}/${RUN_STAMP}-${ACTION}"
  if [[ -n "${safe_label}" ]]; then
    RUN_DIR="${RUN_DIR}-${safe_label}"
  fi
  ACTION_LOG="${RUN_DIR}/action.log"

  ensure_dir "${RUN_DIR}"

  log "run directory: ${RUN_DIR}"
  capture_stage "pre"

  case "${ACTION}" in
    snapshot)
      RUN_STATUS="success"
      ;;
    reprobe-modules)
      if run_reprobe_modules; then
        RUN_STATUS="success"
      else
        RUN_STATUS="failed"
        RUN_FAILURE_REASON="reprobe-modules step failed; see action.log"
      fi
      ;;
  esac

  capture_stage "post"

  {
    printf 'status=%s\n' "${RUN_STATUS}"
    printf 'failure_reason=%s\n' "${RUN_FAILURE_REASON}"
    printf 'run_start_utc=%s\n' "${RUN_START_UTC}"
    printf 'run_end_utc=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf 'action=%s\n' "${ACTION}"
    printf 'label=%s\n' "${LABEL}"
    printf 'note=%s\n' "${NOTE}"
    printf 'run_dir=%s\n' "${RUN_DIR}"
  } > "${RUN_DIR}/summary.env"

  log "run finished with status=${RUN_STATUS}"
  if [[ "${RUN_STATUS}" != "success" ]]; then
    return 1
  fi

  return 0
}

parse_args "$@"
main

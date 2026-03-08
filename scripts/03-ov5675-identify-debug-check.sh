#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="03-ov5675-identify-debug-check"
NOTE="numbered ov5675 identify-debug reload checkpoint"
IDENTIFY_RETRIES=5
IDENTIFY_RETRY_DELAY_US=2000
EXTRA_DELAY_US=0

usage() {
  cat <<'EOF'
Usage:
  sudo scripts/03-ov5675-identify-debug-check.sh [options]

Options:
  --label NAME
      Run label passed through to scripts/webcam-run.sh
  --note TEXT
      Run note passed through to scripts/webcam-run.sh
  --identify-retries N
      Value for ov5675 identify_retry_count
  --identify-retry-delay-us N
      Value for ov5675 identify_retry_delay_us
  --extra-delay-us N
      Value for ov5675 extra_post_power_on_delay_us

What it does:
  1. Reloads only ov5675 with explicit diagnostic module parameters
  2. Captures a normal snapshot run via scripts/webcam-run.sh
  3. Extracts the identify-specific high-value lines since reload start time
  4. Writes a focused summary into the created run directory

This is useful after installing the ov5675 identify-debug module build.
EOF
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
    --identify-retries)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      IDENTIFY_RETRIES="$1"
      ;;
    --identify-retry-delay-us)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      IDENTIFY_RETRY_DELAY_US="$1"
      ;;
    --extra-delay-us)
      shift
      [[ $# -gt 0 ]] || { usage; exit 1; }
      EXTRA_DELAY_US="$1"
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

[[ "${EUID}" -eq 0 ]] || {
  printf 'error: this script requires root; run with sudo\n' >&2
  exit 1
}

cd "${REPO_ROOT}"

run_start_local=$(date +"%Y-%m-%d %H:%M:%S")

modprobe -r ov5675 || true
modprobe ov5675 \
  identify_retry_count="${IDENTIFY_RETRIES}" \
  identify_retry_delay_us="${IDENTIFY_RETRY_DELAY_US}" \
  extra_post_power_on_delay_us="${EXTRA_DELAY_US}"

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || {
  printf 'error: failed to determine run directory\n' >&2
  exit 1
}

focus_journal=$(journalctl -k --since "${run_start_local}" --no-pager | rg \
  'TPS68470 REVID|Found supported sensor|Connected 1 cameras|applying extra post-power-on delay|chip id read attempt|chip id attempt|sensor identified on attempt|Failed to enable|failed to power on|failed to find sensor|probe with driver ov5675 failed' \
  || true)
int3472_driver=$(readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || printf 'int3472-unbound')
ov5675_driver=$(readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || printf 'ov5675-unbound')
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)

summary_path="${run_dir}/focused-summary.txt"
{
  printf 'Source: scripts/03-ov5675-identify-debug-check.sh\n'
  printf 'Purpose: capture the focused result of an ov5675 identify-debug reload attempt\n'
  printf '\n'
  printf 'Reload start time:\n%s\n' "${run_start_local}"
  printf '\n'
  printf 'Module parameters:\n'
  printf 'identify_retry_count=%s\n' "${IDENTIFY_RETRIES}"
  printf 'identify_retry_delay_us=%s\n' "${IDENTIFY_RETRY_DELAY_US}"
  printf 'extra_post_power_on_delay_us=%s\n' "${EXTRA_DELAY_US}"
  printf '\n'
  printf 'High-value journal lines since reload:\n'
  if [[ -n "${focus_journal}" ]]; then
    printf '%s\n' "${focus_journal}"
  else
    printf '(none matched)\n'
  fi
  printf '\n'
  printf 'INT3472 driver state:\n%s\n' "${int3472_driver}"
  printf '\n'
  printf 'OV5675 driver state:\n%s\n' "${ov5675_driver}"
  printf '\n'
  printf 'v4l-subdev nodes:\n'
  if [[ -n "${subdev_nodes}" ]]; then
    printf '%s\n' "${subdev_nodes}"
  else
    printf '(none)\n'
  fi
} > "${summary_path}"

printf 'Focused summary: %s\n' "${summary_path}"

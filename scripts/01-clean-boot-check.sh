#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

LABEL="01-clean-boot-check"
NOTE="numbered clean-boot checkpoint"

usage() {
  cat <<'EOF'
Usage:
  scripts/01-clean-boot-check.sh [--label NAME] [--note TEXT]

What it does:
  1. Captures a normal snapshot run via scripts/webcam-run.sh
  2. Extracts the high-value OV5675 / TPS68470 lines for this project
  3. Writes a small focused summary into the created run directory
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

cd "${REPO_ROOT}"

snapshot_output=$(scripts/webcam-run.sh snapshot --label "${LABEL}" --note "${NOTE}")
printf '%s\n' "${snapshot_output}"

run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
[[ -n "${run_dir}" ]] || {
  printf 'error: failed to determine run directory\n' >&2
  exit 1
}

focus_journal=$(journalctl -b -k --no-pager | rg \
  'TPS68470 REVID|Found supported sensor|Connected 1 cameras|applying extra post-power-on delay|chip id read attempt|chip id attempt|sensor identified on attempt|Failed to enable|failed to power on|failed to find sensor|probe with driver ov5675 failed' \
  || true)
int3472_driver=$(readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || printf 'int3472-unbound')
ov5675_driver=$(readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || printf 'ov5675-unbound')
subdev_nodes=$(find /dev -maxdepth 1 -name 'v4l-subdev*' | sort || true)

summary_path="${run_dir}/focused-summary.txt"
{
  printf 'Source: scripts/01-clean-boot-check.sh\n'
  printf 'Purpose: capture the clean-boot checkpoint for the webcam bring-up path\n'
  printf '\n'
  printf 'High-value boot log lines:\n'
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

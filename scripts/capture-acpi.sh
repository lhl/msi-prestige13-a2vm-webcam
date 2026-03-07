#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

OUT_ROOT="${REPO_ROOT}/reference/acpi"
STAMP=$(date +"%Y%m%dT%H%M%S")
HOSTNAME_SHORT=$(hostname -s 2>/dev/null || hostname 2>/dev/null || printf "unknown-host")
OUT_DIR="${OUT_ROOT}/${STAMP}-${HOSTNAME_SHORT}"

usage() {
  cat <<'EOF'
Usage:
  sudo scripts/capture-acpi.sh [--out-dir DIR]

This captures a root-only ACPI dump plus derived artifacts for webcam bring-up
work on the MSI Prestige 13 AI+ Evo A2VMG.

Outputs:
  - raw text acpidump
  - extracted binary tables
  - DSDT/SSDT disassembly attempts
  - DMI snapshot
  - grep summary for INT3472 / OVTI5675 / CLDB / GPIO / I2C terms
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

read_first_line() {
  local path="$1"
  if [[ -r "${path}" ]]; then
    head -n 1 "${path}"
  fi
}

capture_live_linux_acpi_state() {
  local out_path="$1"
  local dev_dir
  local dev_name
  local physical_target

  {
    printf '# Live Linux ACPI Camera State\n\n'
    printf 'Captured UTC: %s\n\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf '## Camera-relevant ACPI devices from sysfs\n\n'

    shopt -s nullglob
    for dev_dir in /sys/bus/acpi/devices/OVTI* /sys/bus/acpi/devices/INT3472*; do
      dev_name=$(basename "${dev_dir}")
      printf '### %s\n\n' "${dev_name}"
      printf -- '- hid: `%s`\n' "$(read_first_line "${dev_dir}/hid")"
      printf -- '- uid: `%s`\n' "$(read_first_line "${dev_dir}/uid")"
      printf -- '- path: `%s`\n' "$(read_first_line "${dev_dir}/path")"
      printf -- '- status: `%s`\n' "$(read_first_line "${dev_dir}/status")"
      printf -- '- modalias: `%s`\n' "$(read_first_line "${dev_dir}/modalias")"

      if [[ -L "${dev_dir}/physical_node" ]]; then
        physical_target=$(readlink -f "${dev_dir}/physical_node")
        printf -- '- physical_node: `%s`\n' "${physical_target}"
      fi

      printf '\n'
    done
    shopt -u nullglob

    printf '## Physical INT3472 Linux Devices\n\n'
    shopt -s nullglob
    for dev_dir in /sys/devices/*/*:*/i2c_designware.*/i2c-*/i2c-INT3472:*; do
      printf -- '- path: `%s`\n' "${dev_dir}"
      printf -- '- name: `%s`\n' "$(read_first_line "${dev_dir}/name")"
      printf -- '- modalias: `%s`\n' "$(read_first_line "${dev_dir}/modalias")"
      printf -- '- waiting_for_supplier: `%s`\n' "$(read_first_line "${dev_dir}/waiting_for_supplier")"
      if [[ -L "${dev_dir}/firmware_node" ]]; then
        printf -- '- firmware_node: `%s`\n' "$(readlink -f "${dev_dir}/firmware_node")"
      fi
      printf '\n'
    done
    shopt -u nullglob
  } > "${out_path}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${EUID}" -ne 0 ]]; then
  printf 'error: this script must run as root\n' >&2
  exit 1
fi

require_cmd acpidump
require_cmd acpixtract
require_cmd iasl
require_cmd rg

mkdir -p "${OUT_DIR}/tables" "${OUT_DIR}/dsl"

{
  printf 'capture_started_utc=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf 'host=%s\n' "${HOSTNAME_SHORT}"
  printf 'kernel_release=%s\n' "$(uname -r)"
  printf 'repo_root=%s\n' "${REPO_ROOT}"
  printf 'out_dir=%s\n' "${OUT_DIR}"
} > "${OUT_DIR}/metadata.env"

{
  printf 'CMD: acpidump -o %q\n' "${OUT_DIR}/acpidump.txt"
  acpidump -o "${OUT_DIR}/acpidump.txt"
} > "${OUT_DIR}/capture.log" 2>&1

{
  printf 'CMD: cat /sys/class/dmi/id/*\n'
  for f in \
    /sys/class/dmi/id/product_name \
    /sys/class/dmi/id/product_version \
    /sys/class/dmi/id/product_family \
    /sys/class/dmi/id/board_name \
    /sys/class/dmi/id/board_vendor \
    /sys/class/dmi/id/board_version \
    /sys/class/dmi/id/bios_version \
    /sys/class/dmi/id/bios_date
  do
    if [[ -r "${f}" ]]; then
      printf '== %s ==\n' "${f}"
      cat "${f}"
    fi
  done
} > "${OUT_DIR}/dmi.txt"

(
  cd "${OUT_DIR}/tables"
  acpixtract -a ../acpidump.txt > ../acpixtract.log 2>&1
)

mapfile -t DSDT_TABLES < <(find "${OUT_DIR}/tables" -maxdepth 1 -type f -iname 'dsdt.dat' | sort)
mapfile -t SSDT_TABLES < <(find "${OUT_DIR}/tables" -maxdepth 1 -type f -iname 'ssdt*.dat' | sort)

DISASM_TMP=""
cleanup() {
  if [[ -n "${DISASM_TMP}" && -d "${DISASM_TMP}" ]]; then
    rm -rf "${DISASM_TMP}"
  fi
}
trap cleanup EXIT

if (( ${#DSDT_TABLES[@]} > 0 )); then
  DISASM_TMP=$(mktemp -d)
  cp "${DSDT_TABLES[@]}" "${DISASM_TMP}/"
  if (( ${#SSDT_TABLES[@]} > 0 )); then
    cp "${SSDT_TABLES[@]}" "${DISASM_TMP}/"
  fi

  (
    cd "${DISASM_TMP}"
    iasl -d dsdt.dat > "${OUT_DIR}/dsl/dsdt-disasm.log" 2>&1 || true

    if (( ${#SSDT_TABLES[@]} > 0 )); then
      iasl -d ssdt*.dat > "${OUT_DIR}/dsl/ssdt-disasm.log" 2>&1 || true
    fi
  )

  find "${OUT_DIR}/dsl" -maxdepth 1 -type f -name '*.dsl' -delete
  find "${DISASM_TMP}" -maxdepth 1 -type f -name '*.dsl' -exec cp {} "${OUT_DIR}/dsl/" \;
fi

rg -n \
  'INT3472|OVTI5675|CLDB|TPS68470|I2cSerialBus|GpioIo|GpioInt|_DSD|_CRS|Privacy|Shutter|Camera' \
  "${OUT_DIR}/dsl" \
  > "${OUT_DIR}/camera-related-hits.txt" || true

capture_live_linux_acpi_state "${OUT_DIR}/live-linux-acpi-state.txt"

cat > "${OUT_DIR}/README.md" <<EOF
# ACPI Capture

- Captured UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Host: ${HOSTNAME_SHORT}
- Kernel: $(uname -r)

## Files

- \`acpidump.txt\` — raw text ACPI dump
- \`dmi.txt\` — DMI identity snapshot taken alongside the dump
- \`tables/\` — binary tables extracted by \`acpixtract -a\`
- \`dsl/\` — DSDT/SSDT disassembly outputs via staged \`iasl\` runs
- \`camera-related-hits.txt\` — grep summary for camera-relevant ACPI terms
- \`live-linux-acpi-state.txt\` — sysfs snapshot of camera-relevant ACPI devices and physical INT3472 nodes

## Regeneration

\`\`\`bash
sudo scripts/capture-acpi.sh
\`\`\`
EOF

printf 'captured ACPI artifacts under %s\n' "${OUT_DIR}"

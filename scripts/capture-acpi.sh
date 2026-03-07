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

if (( ${#DSDT_TABLES[@]} > 0 )); then
  (
    cd "${OUT_DIR}/dsl"
    if (( ${#SSDT_TABLES[@]} > 0 )); then
      iasl -e "${SSDT_TABLES[@]}" -d "${DSDT_TABLES[0]}" > dsdt-disasm.log 2>&1 || true
    else
      iasl -d "${DSDT_TABLES[0]}" > dsdt-disasm.log 2>&1 || true
    fi
  )
fi

if (( ${#SSDT_TABLES[@]} > 0 )); then
  (
    cd "${OUT_DIR}/dsl"
    iasl -d "${SSDT_TABLES[@]}" > ssdt-disasm.log 2>&1 || true
  )
fi

rg -n \
  'INT3472|OVTI5675|CLDB|TPS68470|I2cSerialBus|GpioIo|GpioInt|_DSD|_CRS|Privacy|Shutter|Camera' \
  "${OUT_DIR}/dsl" \
  > "${OUT_DIR}/camera-related-hits.txt" || true

cat > "${OUT_DIR}/README.md" <<EOF
# ACPI Capture

- Captured UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
- Host: ${HOSTNAME_SHORT}
- Kernel: $(uname -r)

## Files

- \`acpidump.txt\` — raw text ACPI dump
- \`dmi.txt\` — DMI identity snapshot taken alongside the dump
- \`tables/\` — binary tables extracted by \`acpixtract -a\`
- \`dsl/\` — DSDT/SSDT disassembly attempts via \`iasl\`
- \`camera-related-hits.txt\` — grep summary for camera-relevant ACPI terms

## Regeneration

\`\`\`bash
sudo scripts/capture-acpi.sh
\`\`\`
EOF

printf 'captured ACPI artifacts under %s\n' "${OUT_DIR}"

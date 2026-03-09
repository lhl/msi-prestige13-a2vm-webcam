#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

SYS_PATH="${REPO_ROOT}/reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/extracted/iactrllogic64.sys"
OUT_DIR="${REPO_ROOT}/reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1"

usage() {
  cat <<'EOF'
Usage:
  scripts/extract-iactrllogic64.sh [--sys PATH] [--out-dir DIR]

Generates repeatable static-analysis artifacts for the MSI OV5675 package's
Windows control-logic driver.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

dump_disasm() {
  local start="$1"
  local stop="$2"
  local out="$3"
  objdump -d -M intel --start-address="${start}" --stop-address="${stop}" "${SYS_PATH}" 2>/dev/null > "${out}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sys)
      SYS_PATH="$2"
      shift 2
      ;;
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

require_cmd strings
require_cmd objdump
require_cmd llvm-objdump
require_cmd llvm-readobj
require_cmd rg
require_cmd node

[[ -f "${SYS_PATH}" ]] || {
  printf 'error: missing input file: %s\n' "${SYS_PATH}" >&2
  exit 1
}

mkdir -p "${OUT_DIR}"

cat > "${OUT_DIR}/metadata.env" <<EOF
generated_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
repo_root=${REPO_ROOT}
sys_path=${SYS_PATH}
out_dir=${OUT_DIR}
EOF

strings -a -n 6 "${SYS_PATH}" | rg 'tps68470::|discrete::DiscreteControl::Sensor|CommonFunc::Cmd_SensorInitialize' > "${OUT_DIR}/strings-tps68470.txt"
strings -a -n 6 -t d "${SYS_PATH}" | rg 'tps68470::|discrete::DiscreteControl::Sensor|CommonFunc::Cmd_Sensor' > "${OUT_DIR}/strings-tps68470-with-offsets.txt"

llvm-objdump -p "${SYS_PATH}" > "${OUT_DIR}/pe-header-and-imports.txt"
objdump -h "${SYS_PATH}" 2>/dev/null > "${OUT_DIR}/sections.txt"
llvm-readobj --coff-debug-directory "${SYS_PATH}" > "${OUT_DIR}/debug-directory.txt"
llvm-readobj --coff-load-config "${SYS_PATH}" > "${OUT_DIR}/load-config.txt"

node <<'EOF' > "${OUT_DIR}/method-string-addresses.txt"
const entries = [
  [119232, 'tps68470::TPS68470::SensorInitialize'],
  [119280, 'tps68470::TPS68470::SensorOn'],
  [119312, 'tps68470::TPS68470::SensorOff'],
  [119856, 'tps68470::Tps68470Clock::StartClock'],
  [119904, 'tps68470::Tps68470Clock::StopCLock'],
  [119952, 'tps68470::Tps68470Clock::ConfigHCLKAB'],
  [120000, 'tps68470::Tps68470Clock::EnablePLL'],
  [120048, 'tps68470::Tps68470Clock::Initialize'],
  [120096, 'tps68470::Tps68470Clock::SetHCLKAB'],
  [121360, 'CommonFunc::Cmd_SensorPowerOn'],
  [121392, 'CommonFunc::Cmd_SensorPowerOff'],
  [121808, 'tps68470::CrdG2TiSensor::SensorPowerOn'],
  [121856, 'tps68470::CrdG2TiSensor::SensorPowerOff'],
  [121904, 'tps68470::CrdG2TiSensor::MclkOutput'],
  [121952, 'tps68470::CrdG2TiSensor::SetGpioOutput'],
  [122384, 'tps68470::Tps68470VoltageUF::PowerOn'],
  [122432, 'tps68470::Tps68470VoltageUF::PowerOff'],
  [122624, 'tps68470::Tps68470VoltageWF::SetVACtl'],
  [122672, 'tps68470::Tps68470VoltageWF::SetVDCtl'],
  [122720, 'tps68470::Tps68470VoltageWF::SetVSIOCtl'],
  [122768, 'tps68470::Tps68470VoltageWF::SetVSIOCtl_IO'],
  [122816, 'tps68470::Tps68470VoltageWF::SetVSIOCtl_GPIO'],
  [122864, 'tps68470::Tps68470VoltageWF::SetVCMCtl'],
  [122912, 'tps68470::Tps68470VoltageWF::PowerOn'],
  [122960, 'tps68470::Tps68470VoltageWF::PowerOff'],
  [123008, 'tps68470::Tps68470VoltageWF::IoActive'],
  [123056, 'tps68470::Tps68470VoltageWF::IoActive_IO'],
  [123104, 'tps68470::Tps68470VoltageWF::IoActive_GPIO'],
  [123152, 'tps68470::Tps68470VoltageWF::IoIdle'],
];
const textFileOffset = 0x400;
const textFileEnd = 0x1ee70;
const textVmaStart = 0x140001000;
for (const [offset, name] of entries) {
  const vma = offset >= textFileOffset && offset < textFileEnd
    ? '0x' + (textVmaStart + (offset - textFileOffset)).toString(16)
    : 'n/a';
  console.log(`${vma} ${name}`);
}
EOF

objdump -d -M intel "${SYS_PATH}" 2>/dev/null \
  | rg '14001ddc0|14001ddf0|14001de10|14001e030|14001e060|14001e090|14001e0c0|14001e0f0|14001e120|14001e740|14001e760|14001e7d0|14001e800|14001e830|14001e860|14001ea10|14001ea40|14001eb00|14001eb30|14001eb60|14001eb90|14001ebc0|14001ebf0|14001ec20|14001ec50|14001ec80|14001ecb0|14001ece0|14001ed10' \
  > "${OUT_DIR}/method-string-xrefs.txt"

dump_disasm 0x14000aa40 0x14000abc0 "${OUT_DIR}/disasm-sensorinitialize.txt"
dump_disasm 0x14000abc0 0x14000ae10 "${OUT_DIR}/disasm-sensoroff.txt"
dump_disasm 0x14000ae20 0x14000b0c0 "${OUT_DIR}/disasm-sensoron.txt"
dump_disasm 0x14000b8d0 0x14000ba40 "${OUT_DIR}/disasm-clock-confighclkab.txt"
dump_disasm 0x14000c230 0x14000c670 "${OUT_DIR}/disasm-clock-start.txt"
dump_disasm 0x14000cf44 0x14000d190 "${OUT_DIR}/disasm-clock-or-vcm-sequence.txt"
dump_disasm 0x140013b40 0x140013c40 "${OUT_DIR}/disasm-voltage-uf-setvactl.txt"
dump_disasm 0x140013cf0 0x140013e00 "${OUT_DIR}/disasm-voltage-wf-setvactl.txt"
dump_disasm 0x140014200 0x140014360 "${OUT_DIR}/disasm-voltage-uf-setvdctl.txt"
dump_disasm 0x140014390 0x1400144f0 "${OUT_DIR}/disasm-voltage-wf-setvdctl.txt"
dump_disasm 0x140014500 0x1400145a0 "${OUT_DIR}/disasm-voltage-uf-setvsioctl.txt"
dump_disasm 0x1400146a8 0x1400148c0 "${OUT_DIR}/disasm-voltage-wf-setvsioctl.txt"
dump_disasm 0x140014a7c 0x140014c20 "${OUT_DIR}/disasm-voltage-wf-setvsioctl-io.txt"
dump_disasm 0x1400148e4 0x140014a7c "${OUT_DIR}/disasm-voltage-wf-setvsioctl-gpio.txt"
dump_disasm 0x140013e90 0x140013fb0 "${OUT_DIR}/disasm-voltage-uf-setvcmctl.txt"
dump_disasm 0x140014030 0x140014150 "${OUT_DIR}/disasm-voltage-wf-setvcmctl.txt"
dump_disasm 0x140013214 0x1400133e8 "${OUT_DIR}/disasm-voltage-uf-poweroff.txt"
dump_disasm 0x1400133e8 0x14001357c "${OUT_DIR}/disasm-voltage-wf-poweroff.txt"
dump_disasm 0x14001357c 0x140013868 "${OUT_DIR}/disasm-voltage-uf-poweron.txt"
dump_disasm 0x140013868 0x1400139f0 "${OUT_DIR}/disasm-voltage-wf-poweron.txt"
dump_disasm 0x140012764 0x1400127d8 "${OUT_DIR}/disasm-voltage-wf-constructor.txt"
dump_disasm 0x1400129d8 0x140012c80 "${OUT_DIR}/disasm-voltage-wf-initialize.txt"
dump_disasm 0x140013ab8 0x140013b38 "${OUT_DIR}/disasm-voltage-wf-setconf.txt"
dump_disasm 0x140012c90 0x140012dd4 "${OUT_DIR}/disasm-voltage-wf-ioactive.txt"
dump_disasm 0x140013014 0x140013158 "${OUT_DIR}/disasm-voltage-wf-ioactive-io.txt"
dump_disasm 0x140012de0 0x140013014 "${OUT_DIR}/disasm-voltage-wf-ioactive-gpio.txt"
dump_disasm 0x140013158 0x140013212 "${OUT_DIR}/disasm-voltage-wf-ioidle.txt"
dump_disasm 0x140011ae0 0x140011de6 "${OUT_DIR}/disasm-sensor-g2ti-poweroff.txt"
dump_disasm 0x140011df0 0x140011ff4 "${OUT_DIR}/disasm-sensor-g2ti-poweron.txt"
dump_disasm 0x1400121e0 0x140012320 "${OUT_DIR}/disasm-sensor-g2ti-setgpiooutput.txt"
dump_disasm 0x140010be0 0x140010d39 "${OUT_DIR}/disasm-register-write-wrapper.txt"
dump_disasm 0x1400110f4 0x140011260 "${OUT_DIR}/disasm-transport-helper.txt"

cat > "${OUT_DIR}/README.md" <<EOF
# iactrllogic64 Static Analysis

- Package: \`msi-ov5675-70.26100.19939.1\`
- Source binary: \`${SYS_PATH}\`
- Generated UTC: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Files

- \`strings-tps68470.txt\` — named TPS68470- and sensor-related method strings
- \`strings-tps68470-with-offsets.txt\` — same string set with raw file offsets for address correlation
- \`method-string-addresses.txt\` — string virtual-address mapping inside the PE image
- \`method-string-xrefs.txt\` — disassembly lines that reference those method-name strings
- \`pe-header-and-imports.txt\` — PE metadata and imports
- \`debug-directory.txt\` — PDB path and CodeView GUID
- \`load-config.txt\` — GuardCF table and related load-config metadata
- \`disasm-*.txt\` — targeted disassembly windows for the current investigation, including VoltageWF constructor/init/setconf, WF/UF power paths, and CrdG2TiSensor helpers

## Regeneration

\`\`\`bash
scripts/extract-iactrllogic64.sh
\`\`\`
EOF

printf 'generated analysis artifacts under %s\n' "${OUT_DIR}"

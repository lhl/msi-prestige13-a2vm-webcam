#!/usr/bin/env bash
# Manual TPS68470 power-up and OV5675 chip-ID check on the MSI Prestige 13 A2VMG.
#
# This is intentionally outside the repo's "safe harness" boundary. It performs
# direct PMIC register writes from userland to see whether the sensor becomes
# reachable well enough to answer a chip-ID read.
#
# Safer changes compared with the first draft:
#   - dry-run by default; writes require --execute
#   - programs the full 19.2 MHz TPS68470 clock path instead of only PLLCTL
#   - explicitly sets VIO and VSIO, rather than assuming inherited firmware state
#   - uses read-modify-write for enable and GPIO-control registers
#   - avoids i2cdetect bus scans; validation is direct chip-ID reads only
#   - writes a timestamped log under runs/
#
# Evidence basis:
#   - drivers/clk/clk-tps68470.c
#   - drivers/regulator/tps68470-regulator.c
#   - drivers/gpio/gpio-tps68470.c
#   - drivers/media/i2c/ov5675.c
#   - docs/linux-board-data-candidate.md
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

BUS=1
ADDR=0x4d
I2C_DEV_NAME=i2c-INT3472:06

# OV5675 typical rails encoded with the in-kernel TPS68470 formulas.
VIOVAL_1V8=0x34    # 0.875V + 52 * 17.8mV = 1.8006V
VSIOVAL_1V8=0x34   # same as VIO for daisy-chained sensor I2C
VAVAL_2V8=0x6d     # 0.875V + 109 * 17.8mV = 2.8152V
VDVAL_1V2=0x0c     # 0.9V   + 12  * 25mV   = 1.2V

# 19.2 MHz clock values from drivers/clk/clk-tps68470.c
POSTDIV2_19P2=0x01
BOOSTDIV_19P2=0x03
BUCKDIV_19P2=0x02
PLLSWR_DEFAULT=0x03
XTALDIV_19P2=0xaa
PLLDIV_19P2=0x20
POSTDIV_19P2=0x01
CLKCFG2_2MA=0x05
PLLCTL_RATE_BASE=0xd0
PLLCTL_ENABLE=0xd1
CLKCFG1_PLL_AB=0x0a

GPIO_OUT_CMOS=0x02
GPIO_LINES_MASK=0x06

EXECUTE=0
RUN_LABEL=""
declare -a SENSOR_ADDRS=("0x36" "0x10")

die() {
  echo "FATAL: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  scripts/i2c-sensor-check.sh [--execute] [--label NAME] [--sensor-addr 0xNN]

Modes:
  default     Dry-run only. Prints the intended sequence and exits.
  --execute   Perform the PMIC writes and direct OV5675 chip-ID read attempts.

Notes:
  - This script is a higher-risk experiment than scripts/webcam-run.sh.
  - It resets the TPS68470 on exit after an executed run.
  - A failed chip-ID read is not a proof that the Linux patch candidate is wrong.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --execute)
      EXECUTE=1
      shift
      ;;
    --label)
      [[ $# -ge 2 ]] || die "--label requires a value"
      RUN_LABEL="-$2"
      shift 2
      ;;
    --sensor-addr)
      [[ $# -ge 2 ]] || die "--sensor-addr requires a value"
      SENSOR_ADDRS+=("$2")
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

timestamp=$(date +%Y%m%dT%H%M%S)
run_day=$(date +%Y-%m-%d)
run_dir="${REPO_ROOT}/runs/${run_day}/${timestamp}-manual-i2c-sensor-check${RUN_LABEL}"
mkdir -p "${run_dir}"
log_file="${run_dir}/script.log"

exec > >(tee -a "${log_file}") 2>&1

echo "=== OV5675 sensor check via TPS68470 manual power-up ==="
echo "Date: ${timestamp}"
echo "Repo root: ${REPO_ROOT}"
echo "Run dir: ${run_dir}"
echo "Mode: $([[ ${EXECUTE} -eq 1 ]] && echo execute || echo dry-run)"
echo "Bus: ${BUS}  PMIC addr: ${ADDR}  Device: ${I2C_DEV_NAME}"
echo "Sensor address candidates: ${SENSOR_ADDRS[*]}"
echo

cat > "${run_dir}/metadata.env" <<EOF
TIMESTAMP=${timestamp}
MODE=$([[ ${EXECUTE} -eq 1 ]] && echo execute || echo dry-run)
BUS=${BUS}
PMIC_ADDR=${ADDR}
I2C_DEV_NAME=${I2C_DEV_NAME}
SENSOR_ADDRS=${SENSOR_ADDRS[*]}
EOF

write_or_echo() {
  local reg=$1
  local value=$2
  local note=$3

  printf "  reg %s <- %s  %s\n" "${reg}" "${value}" "${note}"
  if [[ ${EXECUTE} -eq 1 ]]; then
    i2cset -y "${BUS}" "${ADDR}" "${reg}" "${value}"
  fi
}

read_reg() {
  local reg=$1
  if [[ ${EXECUTE} -eq 1 ]]; then
    i2cget -y "${BUS}" "${ADDR}" "${reg}"
  else
    echo "DRYRUN"
  fi
}

write_rmw_mask() {
  local reg=$1
  local clear_mask=$2
  local set_mask=$3
  local note=$4
  local cur cur_dec new_dec new_hex

  if [[ ${EXECUTE} -eq 1 ]]; then
    cur=$(i2cget -y "${BUS}" "${ADDR}" "${reg}")
    cur_dec=$((cur))
    new_dec=$(((cur_dec & ~clear_mask) | set_mask))
    printf -v new_hex '0x%02x' "${new_dec}"
    printf "  reg %s: %s -> %s  %s\n" "${reg}" "${cur}" "${new_hex}" "${note}"
    i2cset -y "${BUS}" "${ADDR}" "${reg}" "${new_hex}"
  else
    printf "  reg %s: <read-modify-write> clear=0x%02x set=0x%02x  %s\n" \
      "${reg}" "${clear_mask}" "${set_mask}" "${note}"
  fi
}

capture_regs() {
  local outfile=$1
  : > "${outfile}"

  {
    echo "# TPS68470 snapshot"
    echo "date=${timestamp}"
    echo "mode=$([[ ${EXECUTE} -eq 1 ]] && echo execute || echo dry-run)"
  } >> "${outfile}"

  for reg in \
    0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0f 0x10 \
    0x16 0x18 0x26 0x27 \
    0x3f 0x40 0x41 0x42 0x43 0x47 0x48 0x50 0xff
  do
    printf "%s=%s\n" "${reg}" "$(read_reg "${reg}")" >> "${outfile}"
  done
}

cleanup() {
  if [[ ${EXECUTE} -ne 1 ]]; then
    return 0
  fi

  echo
  echo "--- Cleanup: resetting TPS68470 ---"
  i2cset -y "${BUS}" "${ADDR}" 0x50 0xff 2>/dev/null || true
  sleep 0.1
  {
    echo "# TPS68470 post-reset snapshot"
    echo "date=$(date +%Y%m%dT%H%M%S)"
    for reg in 0x0d 0x16 0x18 0x3f 0x40 0x41 0x42 0x43 0x47 0x48 0xff; do
      printf "%s=%s\n" "${reg}" "$(i2cget -y "${BUS}" "${ADDR}" "${reg}" 2>/dev/null || echo ERROR)"
    done
  } > "${run_dir}/post-reset-regs.txt"
  echo "Post-reset REVID: $(i2cget -y "${BUS}" "${ADDR}" 0xff 2>/dev/null || echo ERROR)"
  echo "Reset snapshot written to ${run_dir}/post-reset-regs.txt"
}
trap cleanup EXIT

echo "Planned sequence:"
echo "  1. Verify PMIC REVID"
echo "  2. Capture pre-write PMIC state"
echo "  3. Program VIO/VSIO/VA/VD values explicitly"
echo "  4. Program the full 19.2 MHz TPS68470 clock path"
echo "  5. Put GPIO1/GPIO2 in CMOS-output mode and hold them low"
echo "  6. Enable VSIO/VA/VD"
echo "  7. Drive GPIO1/GPIO2 high and try direct OV5675 chip-ID reads"
echo "  8. Capture post-write PMIC state"
echo "  9. Reset the PMIC on exit"
echo

if [[ ${EXECUTE} -ne 1 ]]; then
  echo "Dry-run only. Re-run with --execute to perform the writes."
  exit 0
fi

command -v i2cget &>/dev/null || die "i2cget not found"
command -v i2cset &>/dev/null || die "i2cset not found"
command -v i2ctransfer &>/dev/null || die "i2ctransfer not found"
[[ ${EUID} -eq 0 ]] || die "must run as root with --execute"

if [[ -e "/sys/bus/i2c/devices/${I2C_DEV_NAME}/driver" ]]; then
  die "${I2C_DEV_NAME} appears bound to a driver; aborting to avoid racing kernel-owned PMIC state"
fi

revid=$(i2cget -y "${BUS}" "${ADDR}" 0xff) || die "cannot read REVID"
echo "TPS68470 REVID: ${revid}"
[[ "${revid}" == "0x21" ]] || die "unexpected REVID (expected 0x21)"
echo

capture_regs "${run_dir}/pre-pmic-regs.txt"
echo "Pre-write PMIC snapshot saved to ${run_dir}/pre-pmic-regs.txt"
echo

echo "--- Step 1: Program voltage registers ---"
write_or_echo 0x3f "${VIOVAL_1V8}"  "(VIOVAL 1.8V)"
write_or_echo 0x40 "${VSIOVAL_1V8}" "(VSIOVAL 1.8V)"
write_or_echo 0x41 "${VAVAL_2V8}"   "(VAVAL 2.8V for avdd)"
write_or_echo 0x42 "${VDVAL_1V2}"   "(VDVAL 1.2V for dvdd)"
echo

echo "--- Step 2: Program full 19.2 MHz clock path ---"
write_or_echo 0x0a "${XTALDIV_19P2}" "(XTALDIV)"
write_or_echo 0x08 "${BUCKDIV_19P2}" "(BUCKDIV)"
write_or_echo 0x07 "${BOOSTDIV_19P2}" "(BOOSTDIV)"
write_or_echo 0x0b "${PLLDIV_19P2}" "(PLLDIV)"
write_or_echo 0x0c "${POSTDIV_19P2}" "(POSTDIV)"
write_or_echo 0x06 "${POSTDIV2_19P2}" "(POSTDIV2)"
write_or_echo 0x10 "${CLKCFG2_2MA}" "(CLKCFG2 2mA drive)"
write_or_echo 0x09 "${PLLSWR_DEFAULT}" "(PLLSWR default)"
write_or_echo 0x0d "${PLLCTL_RATE_BASE}" "(PLLCTL base: xtal source + ext caps)"
write_or_echo 0x0f "${CLKCFG1_PLL_AB}" "(enable HCLK_A/HCLK_B PLL outputs)"
write_or_echo 0x0d "${PLLCTL_ENABLE}" "(PLLCTL enable bit set)"
echo "  waiting 5ms for PLL prepare"
sleep 0.005
echo

echo "--- Step 3: Put GPIO1/GPIO2 under PMIC output control and hold low ---"
write_rmw_mask 0x16 0x03 "${GPIO_OUT_CMOS}" "(GPCTL1A mode -> CMOS output)"
write_rmw_mask 0x18 0x03 "${GPIO_OUT_CMOS}" "(GPCTL2A mode -> CMOS output)"
write_rmw_mask 0x27 "${GPIO_LINES_MASK}" 0x00 "(GPDO clear GPIO1/GPIO2)"
echo

echo "--- Step 4: Enable VSIO / VA / VD ---"
write_rmw_mask 0x43 0x00 0x03 "(S_I2C_CTL enable VSIO and sensor-I2C path)"
write_rmw_mask 0x47 0x00 0x01 "(VACTL enable)"
write_rmw_mask 0x48 0x00 0x01 "(VDCTL enable bit)"
echo "  waiting 3ms for rails to settle"
sleep 0.003
echo

echo "--- Step 5: Deassert candidate sensor control lines ---"
write_rmw_mask 0x27 "${GPIO_LINES_MASK}" "${GPIO_LINES_MASK}" "(GPDO set GPIO1/GPIO2 high)"
echo "  waiting 5ms after control-line release"
sleep 0.005
echo

echo "--- Step 6: Try direct OV5675 chip-ID reads ---"
chip_id_match=0
for sensor_addr in "${SENSOR_ADDRS[@]}"; do
  echo "  trying ${sensor_addr} register 0x300a"
  if chip_id=$(i2ctransfer -y "${BUS}" "w2@${sensor_addr}" 0x30 0x0a "r2@${sensor_addr}" 2>&1); then
    echo "    response: ${chip_id}"
    if grep -q "0x56 0x75" <<<"${chip_id}"; then
      echo "    OV5675 chip ID matched at ${sensor_addr}"
      chip_id_match=1
    else
      echo "    device responded but chip ID did not match 0x56 0x75"
    fi
  else
    echo "    no response"
  fi
done
echo

capture_regs "${run_dir}/post-pmic-regs.txt"
echo "Post-write PMIC snapshot saved to ${run_dir}/post-pmic-regs.txt"
echo

if [[ ${chip_id_match} -eq 1 ]]; then
  echo "Result: OV5675 chip-ID read succeeded. This supports the power/clock/GPIO hypothesis but does not prove the kernel path is complete."
else
  echo "Result: no OV5675 chip-ID match. This does not rule out the Linux board-data hypothesis."
  echo "Likely causes still include wrong sensor address, wrong GPIO1/GPIO2 semantics, missing second control-line behavior, or incomplete MSI-specific sequencing."
fi

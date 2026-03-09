#!/bin/bash
# pmic-reg-dump.sh — Dump all relevant TPS68470 PMIC registers via i2cget.
#
# Usage:  sudo bash scripts/pmic-reg-dump.sh [BUS [ADDR]]
#
# Defaults: bus=13, addr=0x48 (matches the MSI Prestige 13 A2VMG layout).
# Requires: i2c-tools (i2cget), root or i2c group membership.
#
# The output is designed to be diffed against Windows-expected values
# recovered from iactrllogic64.sys (see power-sequencing-notes.md).

set -euo pipefail

BUS="${1:-13}"
ADDR="${2:-0x48}"

echo "# TPS68470 register dump"
echo "# date=$(date -u +%Y%m%dT%H%M%SZ)"
echo "# bus=$BUS addr=$ADDR"
echo ""

# Helper: read one register, print reg=val or reg=ERROR
read_reg() {
  local reg="$1"
  local label="$2"
  local val
  if val=$(i2cget -f -y "$BUS" "$ADDR" "$reg" 2>/dev/null); then
    printf "%-6s = %-6s  # %s\n" "$reg" "$val" "$label"
  else
    printf "%-6s = %-6s  # %s\n" "$reg" "ERROR" "$label"
  fi
}

echo "## Identity"
read_reg 0xff "REVID"

echo ""
echo "## Clock registers"
echo "# Windows StartClock writes these in order."
echo "# If all zero + PLLCTL=0x80, clock was never started."
read_reg 0x06 "POSTDIV2"
read_reg 0x07 "BOOSTDIV"
read_reg 0x08 "BUCKDIV"
read_reg 0x09 "PLLSWR"
read_reg 0x0a "XTALDIV"
read_reg 0x0b "PLLDIV"
read_reg 0x0c "POSTDIV"
read_reg 0x0d "PLLCTL           (bit0=PLL_EN, 0x80=disabled/bypass)"
read_reg 0x0e "CLKCFG1          (output enable A/B)"
read_reg 0x0f "CLKSTAT          (PLL lock status, read-only)"
read_reg 0x10 "CLKCFG2          (drive strength)"

echo ""
echo "## Regulator value registers"
echo "# Windows WF::Initialize programs these BEFORE enable."
echo "# Expected WF values: VDVAL~1050mV, VAVAL~2800mV, VSIOVAL~1800mV, VIOVAL~1800mV, VCMVAL~2800mV"
read_reg 0x3c "VCMVAL           (Windows WF object +0x0e => reg 0x3c)"
read_reg 0x3d "VCMVAL_high?     (check adjacency)"
read_reg 0x3f "VIOVAL           (Windows WF object +0x0c => reg 0x3f)"
read_reg 0x40 "VSIOVAL          (Windows WF object +0x10 => reg 0x40)"
read_reg 0x41 "VAVAL            (Windows WF object +0x0a => reg 0x41)"
read_reg 0x42 "VDVAL            (Windows WF object +0x08 => reg 0x42)"

echo ""
echo "## Regulator control/enable registers"
echo "# These are the enable bits that Linux regulator framework should toggle."
read_reg 0x43 "S_I2C_CTL        (bit0=VSIO_EN?, bit1=S_I2C_EN?)"
read_reg 0x44 "VCMCTL           (bit0=VCM_EN)"
read_reg 0x45 "not documented   (check for stray writes)"
read_reg 0x46 "not documented   (check for stray writes)"
read_reg 0x47 "VACTL            (bit0=VA_EN)"
read_reg 0x48 "VDCTL            (bit0=VD_EN)"

echo ""
echo "## AUX regulators"
read_reg 0x50 "AUX1CTL?"
read_reg 0x51 "AUX2CTL?"

echo ""
echo "## GPIO registers"
echo "# Windows IoActive_GPIO reads/writes GPCTL1A and GPCTL2A."
echo "# Mode bits: low 2 bits = mode (0=HiZ, 1=output, ...). Mask 0xfc clears mode."
read_reg 0x16 "GPCTL1A          (GPIO1 control)"
read_reg 0x17 "GPCTL1B          (GPIO1 control B)"
read_reg 0x18 "GPCTL2A          (GPIO2 control)"
read_reg 0x19 "GPCTL2B          (GPIO2 control B)"
read_reg 0x1a "GPCTL3A?"
read_reg 0x1b "GPCTL3B?"

echo ""
echo "## GPIO data output register"
read_reg 0x26 "GPDIVAL          (GPIO data input)"
read_reg 0x27 "GPDO             (GPIO data output, bit4=gpio.4 used by UF path)"

echo ""
echo "## Summary interpretation"
echo "#"
echo "# If PLLCTL=0x80 and CLKCFG1=0x00: clock never enabled (sensor can't respond to I2C)"
echo "# If S_I2C_CTL=0x00: sensor I2C pass-through not enabled"
echo "# If VACTL=0x00 and VDCTL bit0=0: regulators not enabled"
echo "# If value registers are all 0x00 or 0x34: Linux may not have programmed them"
echo "#"
echo "# Compare value registers against the Windows WF tuple:"
echo "#   VD  = 1050 mV  (Linux board-data currently says 1200 mV -- MISMATCH)"
echo "#   VA  = 2800 mV  (Linux board-data says 2815.2 mV -- close)"
echo "#   VIO = 1800 mV  (Linux board-data says 1800.6 mV -- close)"
echo "#   VCM = 2800 mV  (Linux board-data says 2815.2 mV -- close)"
echo "#  VSIO = 1800 mV  (Linux board-data says 1800.6 mV -- close)"

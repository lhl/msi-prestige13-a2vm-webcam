#!/usr/bin/env bash
# Read-only dump of TPS68470 registers on i2c-1 for the MSI Prestige 13 A2VMG.
# Must be run as root. All operations are i2cget (read-only).
#
# Register map from include/linux/mfd/tps68470.h in the kernel tree.
set -euo pipefail

BUS=1

echo "=== TPS68470 register dump (bus=$BUS) ==="
echo "Date: $(date -u +%Y-%m-%dT%H%M%S)"
echo ""

# Check tools
if ! command -v i2cget &>/dev/null; then
  echo "ERROR: i2cget not found (install i2c-tools)" >&2
  exit 1
fi
if ! command -v i2cdetect &>/dev/null; then
  echo "ERROR: i2cdetect not found (install i2c-tools)" >&2
  exit 1
fi
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: must run as root" >&2
  exit 1
fi

# Scan the bus first to find all responding addresses
echo "--- Bus scan (i2cdetect -y $BUS) ---"
i2cdetect -y "$BUS"
echo ""

# Try both possible TPS68470 addresses (0x4C with A0=0, 0x4D with A0=1)
# REVID is at register 0xFF per tps68470.h
ADDR=""
for candidate in 0x4c 0x4d; do
  val=$(i2cget -y "$BUS" "$candidate" 0xff 2>&1) && {
    echo "Found responding device at $candidate, REVID(0xff)=$val"
    if [[ "$val" == "0x21" ]]; then
      ADDR=$candidate
      echo "  -> matches TPS68470 REVID 0x21"
      break
    elif [[ -z "$ADDR" ]]; then
      ADDR=$candidate
      echo "  -> REVID does not match 0x21, trying next"
    fi
  } || echo "No response at $candidate"
done
echo ""

if [[ -z "$ADDR" ]]; then
  echo "FAIL: no TPS68470 found at 0x4c or 0x4d on bus $BUS"
  exit 1
fi

echo "Using addr=$ADDR"
echo ""

# Helper
read_reg() {
  local reg=$1 name=$2
  val=$(i2cget -y $BUS $ADDR "$reg" 2>&1) || val="ERROR"
  printf "%-16s(%s) = %s\n" "$name" "$reg" "$val"
}

# Identity
echo "--- Identity ---"
read_reg 0xff REVID
read_reg 0x50 RESET

echo ""
echo "--- Clock registers ---"
read_reg 0x06 POSTDIV2
read_reg 0x07 BOOSTDIV
read_reg 0x08 BUCKDIV
read_reg 0x09 PLLSWR
read_reg 0x0a XTALDIV
read_reg 0x0b PLLDIV
read_reg 0x0c POSTDIV
read_reg 0x0d PLLCTL
read_reg 0x0e PLLCTL2
read_reg 0x0f CLKCFG1
read_reg 0x10 CLKCFG2

echo ""
echo "--- GPIO control registers (7 regular GPIOs: 0-6) ---"
read_reg 0x14 GPCTL0A
read_reg 0x15 GPCTL0B
read_reg 0x16 GPCTL1A
read_reg 0x17 GPCTL1B
read_reg 0x18 GPCTL2A
read_reg 0x19 GPCTL2B
read_reg 0x1a GPCTL3A
read_reg 0x1b GPCTL3B
read_reg 0x1c GPCTL4A
read_reg 0x1d GPCTL4B
read_reg 0x1e GPCTL5A
read_reg 0x1f GPCTL5B
read_reg 0x20 GPCTL6A
read_reg 0x21 GPCTL6B
read_reg 0x22 SGPO
read_reg 0x26 GPDI
read_reg 0x27 GPDO

echo ""
echo "--- Regulator value registers ---"
read_reg 0x3c VCMVAL
read_reg 0x3d VAUX1VAL
read_reg 0x3e VAUX2VAL
read_reg 0x3f VIOVAL
read_reg 0x40 VSIOVAL
read_reg 0x41 VAVAL
read_reg 0x42 VDVAL

echo ""
echo "--- Regulator control registers ---"
read_reg 0x43 S_I2C_CTL
read_reg 0x44 VCMCTL
read_reg 0x45 VAUX1CTL
read_reg 0x46 VAUX2CTL
read_reg 0x47 VACTL
read_reg 0x48 VDCTL

echo ""
echo "=== Done ==="

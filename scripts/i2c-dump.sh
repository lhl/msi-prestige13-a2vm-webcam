#!/usr/bin/env bash
# Read-only dump of TPS68470 registers on i2c-1 for the MSI Prestige 13 A2VMG.
# Must be run as root. All operations are i2cget (read-only).
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
ADDR=""
for candidate in 0x4c 0x4d; do
  val=$(i2cget -y "$BUS" "$candidate" 0x00 2>&1) && {
    echo "Found responding device at $candidate, REVID=$val"
    # TPS68470 REVID should be 0x21
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

# Read REVID
echo "--- Identity ---"
REVID=$(i2cget -y $BUS $ADDR 0x00 2>&1) || { echo "FAIL: cannot read REVID at $ADDR on bus $BUS"; exit 1; }
echo "REVID           (0x00) = $REVID"

echo ""
echo "--- Clock registers ---"
for reg in 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0f 0x10; do
  val=$(i2cget -y $BUS $ADDR $reg 2>&1) || val="ERROR"
  case $reg in
    0x06) name="POSTDIV2" ;;
    0x07) name="BOOSTDIV" ;;
    0x08) name="BUCKDIV"  ;;
    0x09) name="PLLSWR"   ;;
    0x0a) name="XTALDIV"  ;;
    0x0b) name="PLLDIV"   ;;
    0x0c) name="POSTDIV"  ;;
    0x0d) name="PLLCTL"   ;;
    0x0f) name="PLLCTL2"  ;;
    0x10) name="CLKCFG2"  ;;
    *)    name="unknown"   ;;
  esac
  printf "%-16s(%s) = %s\n" "$name" "$reg" "$val"
done

echo ""
echo "--- Regulator control registers ---"
for reg in 0x20 0x21 0x22 0x23 0x24 0x25 0x26 0x27 0x28 0x29 0x2a 0x2b 0x2c 0x2d 0x2e 0x2f 0x30 0x31 0x32 0x33 0x34 0x43 0x46 0x47; do
  val=$(i2cget -y $BUS $ADDR $reg 2>&1) || val="ERROR"
  case $reg in
    0x20) name="VCOREVAL"  ;;
    0x21) name="VCORECTL"  ;;
    0x22) name="VANAVAL"   ;;
    0x23) name="VANACTL"   ;;
    0x24) name="VCMVAL"    ;;
    0x25) name="VCMCTL"    ;;
    0x26) name="VIOVAL"    ;;
    0x27) name="VIOCTL"    ;;
    0x28) name="VSIOVAL"   ;;
    0x29) name="VSIOCTL"   ;;
    0x2a) name="VAUX1VAL"  ;;
    0x2b) name="VAUX1CTL"  ;;
    0x2c) name="VAUX2VAL"  ;;
    0x2d) name="VAUX2CTL"  ;;
    0x2e) name="VIOVAL_H"  ;;
    0x2f) name="VIOCTL_H"  ;;
    0x30) name="VSIOVAL_H" ;;
    0x31) name="VSIOCTL_H" ;;
    0x32) name="VAUX1VAL_H";;
    0x33) name="VAUX1CTL_H";;
    0x34) name="VAUX2VAL_H";;
    0x43) name="S_I2C_CTL" ;;
    0x46) name="VDCTL"     ;;
    0x47) name="VACTL"     ;;
    *)    name="reg"       ;;
  esac
  printf "%-16s(%s) = %s\n" "$name" "$reg" "$val"
done

echo ""
echo "--- GPIO registers ---"
for reg in 0x14 0x15 0x16 0x17 0x18 0x19 0x1a 0x1b; do
  val=$(i2cget -y $BUS $ADDR $reg 2>&1) || val="ERROR"
  case $reg in
    0x14) name="GPDI"    ;;
    0x15) name="GPDO"    ;;
    0x16) name="GPCTL0A" ;;
    0x17) name="GPCTL0B" ;;
    0x18) name="GPCTL1A" ;;
    0x19) name="GPCTL1B" ;;
    0x1a) name="GPCTL2A" ;;
    0x1b) name="GPCTL2B" ;;
    *)    name="reg"     ;;
  esac
  printf "%-16s(%s) = %s\n" "$name" "$reg" "$val"
done

echo ""
echo "--- Misc / status ---"
for reg in 0x01 0x40 0x41 0x42 0x44 0x45; do
  val=$(i2cget -y $BUS $ADDR $reg 2>&1) || val="ERROR"
  case $reg in
    0x01) name="STBYCTL1"  ;;
    0x40) name="ILEDCTL"   ;;
    0x41) name="FLED_IOUT" ;;
    0x42) name="TLED_IOUT" ;;
    0x44) name="WLED_IOUT" ;;
    0x45) name="WLED_FREQ" ;;
    *)    name="reg"       ;;
  esac
  printf "%-16s(%s) = %s\n" "$name" "$reg" "$val"
done

echo ""
echo "=== Done ==="

#!/usr/bin/env bash
# Manual TPS68470 power-up and OV5675 sensor check on the MSI Prestige 13 A2VMG.
# Must be run as root.
#
# This script:
#   1. Records the initial bus state
#   2. Programs TPS68470 voltage registers for OV5675
#   3. Enables regulators and the I2C sensor passthrough
#   4. Configures GPIO1/GPIO2 as outputs and deasserts reset
#   5. Scans for the OV5675 and reads its chip ID
#   6. Resets the TPS68470 back to defaults
#
# All voltage values derived from:
#   - include/linux/mfd/tps68470.h (register addresses)
#   - drivers/regulator/tps68470-regulator.c (voltage formulas)
#   - OV5675 datasheet typical values
#
# Register map reference:
#   LDO formula:  V = 0.875V + sel * 17.8mV  (VAVAL, VSIOVAL, VIOVAL, etc.)
#   CORE formula: V = 0.9V   + sel * 25mV    (VDVAL)
#
# RISK: writing wrong values could damage hardware. These values match the
# OV5675 datasheet and the existing Surface Go board-data pattern. The TPS68470
# is reset at the end to restore defaults.
set -euo pipefail

BUS=1
ADDR=0x4d

# Voltage DAC values
VAVAL_2V8=0x6d     # 0.875 + 109*0.0178 = 2.8152V (avdd)
VDVAL_1V2=0x0c     # 0.9   +  12*0.025  = 1.2V    (dvdd)
# VIOVAL/VSIOVAL already at 0x34 = 1.8006V (dovdd) from firmware

# OV5675 expected I2C address (7-bit)
OV5675_ADDR=0x36

die() { echo "FATAL: $*" >&2; exit 1; }

echo "=== OV5675 sensor check via TPS68470 manual power-up ==="
echo "Date: $(date -u +%Y-%m-%dT%H%M%S)"
echo "Bus: $BUS  PMIC addr: $ADDR"
echo ""

# Preflight
command -v i2cget &>/dev/null || die "i2cget not found"
command -v i2cset &>/dev/null || die "i2cset not found"
command -v i2cdetect &>/dev/null || die "i2cdetect not found"
command -v i2ctransfer &>/dev/null || die "i2ctransfer not found"
[[ $EUID -eq 0 ]] || die "must run as root"

# Verify TPS68470 is present
revid=$(i2cget -y $BUS $ADDR 0xff) || die "cannot read REVID"
echo "TPS68470 REVID: $revid"
[[ "$revid" == "0x21" ]] || die "unexpected REVID (expected 0x21)"
echo ""

# --- Step 0: Record initial bus state ---
echo "--- Step 0: Initial bus scan ---"
i2cdetect -y $BUS
echo ""

cleanup() {
    echo ""
    echo "--- Cleanup: resetting TPS68470 ---"
    # Software reset: write 0xFF to RESET register (0x50)
    i2cset -y $BUS $ADDR 0x50 0xff 2>/dev/null || true
    sleep 0.1
    local r
    r=$(i2cget -y $BUS $ADDR 0xff 2>/dev/null) || r="ERROR"
    echo "Post-reset REVID: $r"
    echo "TPS68470 has been reset to defaults."
}
trap cleanup EXIT

# --- Step 1: Program voltage values ---
echo "--- Step 1: Program voltage registers ---"

# VAVAL (0x41) = 0x6D for 2.8V (avdd)
echo "  VAVAL  (0x41) <- 0x6d  (2.8V for avdd)"
i2cset -y $BUS $ADDR 0x41 $VAVAL_2V8 || die "failed to write VAVAL"

# VDVAL (0x42) = 0x0C for 1.2V (dvdd)
echo "  VDVAL  (0x42) <- 0x0c  (1.2V for dvdd)"
i2cset -y $BUS $ADDR 0x42 $VDVAL_1V2 || die "failed to write VDVAL"

# VIOVAL and VSIOVAL are already 0x34 (1.8V) from firmware, verify
vio=$(i2cget -y $BUS $ADDR 0x3f)
vsio=$(i2cget -y $BUS $ADDR 0x40)
echo "  VIOVAL (0x3f) = $vio  (should be 0x34 = 1.8V, firmware default)"
echo "  VSIOVAL(0x40) = $vsio (should be 0x34 = 1.8V, firmware default)"
echo ""

# --- Step 2: Enable PLL (required for CORE/VD buck converter) ---
echo "--- Step 2: Enable PLL ---"
# PLLCTL (0x0d): set bit 0 to enable PLL
# Current value is 0x80, so write 0x81
pllctl=$(i2cget -y $BUS $ADDR 0x0d)
echo "  PLLCTL (0x0d) current: $pllctl"
echo "  PLLCTL (0x0d) <- 0x81  (enable PLL, keep existing bits)"
i2cset -y $BUS $ADDR 0x0d 0x81 || die "failed to enable PLL"
sleep 0.05
echo ""

# --- Step 3: Enable regulators ---
echo "--- Step 3: Enable regulators ---"

# Enable S_I2C_CTL (0x43) - VSIO + I2C passthrough (2-bit enable: 0x03)
echo "  S_I2C_CTL (0x43) <- 0x03  (enable VSIO + sensor I2C passthrough)"
i2cset -y $BUS $ADDR 0x43 0x03 || die "failed to enable S_I2C_CTL"
sleep 0.01

# Enable VACTL (0x47) - analog supply (avdd)
echo "  VACTL   (0x47) <- 0x01  (enable VA)"
i2cset -y $BUS $ADDR 0x47 0x01 || die "failed to enable VACTL"
sleep 0.01

# Enable VDCTL (0x48) - digital core supply (dvdd)
# Current value is 0x04 (bit 2 set), so OR in bit 0: 0x05
echo "  VDCTL   (0x48) <- 0x05  (enable VD, preserve bit 2)"
i2cset -y $BUS $ADDR 0x48 0x05 || die "failed to enable VDCTL"
sleep 0.05

echo "  Waiting 10ms for regulators to stabilize..."
sleep 0.01
echo ""

# --- Step 4: Configure GPIOs for sensor reset/powerdown ---
echo "--- Step 4: Configure GPIO1 and GPIO2 as outputs ---"

# GPIO mode: 0x02 = CMOS output (TPS68470_GPIO_MODE_OUT_CMOS)
# GPCTL1A (0x16): GPIO1 — assumed to be reset (drive HIGH to deassert)
echo "  GPCTL1A (0x16) <- 0x02  (GPIO1 = CMOS output)"
i2cset -y $BUS $ADDR 0x16 0x02 || die "failed to configure GPIO1"

# GPCTL2A (0x18): GPIO2 — assumed to be powerdown (drive HIGH to deassert)
echo "  GPCTL2A (0x18) <- 0x02  (GPIO2 = CMOS output)"
i2cset -y $BUS $ADDR 0x18 0x02 || die "failed to configure GPIO2"

# Drive both HIGH via GPDO (0x27): set bits 1 and 2 = 0x06
# (deassert both reset and powerdown for active-low interpretation)
echo "  GPDO    (0x27) <- 0x06  (GPIO1=HIGH, GPIO2=HIGH)"
i2cset -y $BUS $ADDR 0x27 0x06 || die "failed to write GPDO"

echo "  Waiting 20ms for sensor to initialize after reset deassert..."
sleep 0.02
echo ""

# --- Step 5: Check for OV5675 ---
echo "--- Step 5: Scan for new devices on bus $BUS ---"
i2cdetect -y $BUS
echo ""

# Try reading OV5675 chip ID at expected address 0x36
# OV5675 uses 16-bit register addresses: chip ID at 0x300A (high) and 0x300B (low)
# Expected: 0x56 0x75
echo "--- Step 6: Read OV5675 chip ID at address $OV5675_ADDR ---"

# Use i2ctransfer: write 2-byte register address, then read 2 bytes
# w2 = write 2 bytes (register address 0x30 0x0A)
# r2 = read 2 bytes (chip ID high and low)
if chip_id=$(i2ctransfer -y $BUS w2@$OV5675_ADDR 0x30 0x0a r2 2>&1); then
    echo "  Raw response: $chip_id"
    echo "  Expected: 0x56 0x75 (OV5675)"
    if echo "$chip_id" | grep -q "0x56 0x75"; then
        echo ""
        echo "  *** SUCCESS: OV5675 detected and responding! ***"
    else
        echo ""
        echo "  Sensor responded but chip ID does not match OV5675."
        echo "  This could mean a different sensor or wrong I2C address."
    fi
else
    echo "  No response at $OV5675_ADDR"
    echo ""
    echo "  Trying alternate OV5675 address 0x10..."
    if chip_id=$(i2ctransfer -y $BUS w2@0x10 0x30 0x0a r2 2>&1); then
        echo "  Raw response at 0x10: $chip_id"
        if echo "$chip_id" | grep -q "0x56 0x75"; then
            echo ""
            echo "  *** SUCCESS: OV5675 detected at 0x10! ***"
        else
            echo "  Device responded but chip ID does not match."
        fi
    else
        echo "  No response at 0x10 either."
        echo ""
        echo "  Possible reasons:"
        echo "    - GPIO1/GPIO2 roles are swapped (try swapping reset/powerdown)"
        echo "    - Sensor needs powerdown LOW not HIGH"
        echo "    - Additional power sequencing or timing needed"
        echo "    - Sensor is at a different I2C address"
    fi
fi

echo ""
echo "--- Register state before cleanup ---"
for reg in 0x41 0x42 0x43 0x47 0x48 0x0d 0x16 0x18 0x27; do
    val=$(i2cget -y $BUS $ADDR "$reg" 2>/dev/null) || val="ERROR"
    printf "  TPS68470 reg %s = %s\n" "$reg" "$val"
done
echo ""
echo "=== Cleanup will now reset the TPS68470 ==="
# cleanup runs via EXIT trap

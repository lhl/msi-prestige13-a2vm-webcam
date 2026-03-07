# Review: Project State as of 2026-03-08

Written during an in-progress PMIC reverse-engineering session. Read-only review of all project docs, WORKLOG, PLAN, CONTEXT, upstream board-data source, and Windows driver analysis artifacts.

## Overall Assessment

This is impressively thorough and well-organized research. The project has gone from "webcam doesn't work" to a very precise understanding of exactly what's missing in about two days. The documentation discipline is excellent — anyone could pick this up and know exactly where things stand.

## What's Been Established (Strong Evidence)

- The blocker is definitively **missing MSI board-data** in `tps68470_board_data.c` — not a missing sensor driver, not missing IPU7 support, not missing firmware
- The exact ACPI path is known: `OVTI5675:00` at `\_SB_.LNK0`, PMIC at `INT3472:06` at `\_SB_.CLP0`
- This is a `CLP` (PMIC companion) path, not a `DSC` (discrete) path
- The Windows driver is doing real register-level PMIC control, not delegating to firmware
- The Windows register sequences map cleanly to known Linux TPS68470 register names

## Feedback and Thoughts

### 1. The patch may be simpler than the analysis suggests

Looking at the existing board-data entries (Surface Go, Dell 7212), the actual data structures are quite small:
- A few `regulator_consumer_supply` arrays mapping supply names (`dvdd`, `avdd`, `dovdd`) to ACPI device names
- Voltage constraints for each regulator rail
- A GPIO lookup table for `reset` (and optionally `powerdown`)
- A DMI match entry

For the MSI case, `ov5675` needs `avdd`, `dovdd`, `dvdd`, and a `reset` GPIO. The existing patterns in the file already cover exactly these supply types. The most likely first attempt would be:

- **Regulator consumers**: `REGULATOR_SUPPLY("dvdd", "i2c-OVTI5675:00")`, `REGULATOR_SUPPLY("avdd", "i2c-OVTI5675:00")`, `REGULATOR_SUPPLY("dovdd", "i2c-OVTI5675:00")`
- **GPIO**: `GPIO_LOOKUP("tps68470-gpio", N, "reset", GPIO_ACTIVE_LOW)` — where `N` is the pin number to extract from the Windows driver or ACPI
- **DMI match**: `DMI_EXACT_MATCH(DMI_SYS_VENDOR, "Micro-Star International Co., Ltd.")` + product name
- **dev_name**: `"i2c-INT3472:06"`

The **voltage values** and **GPIO pin number** are the two unknowns that actually require the reverse engineering. Everything else is structural boilerplate.

### 2. Fastest path to a testable hypothesis

Rather than fully completing the VoltageWF extraction before testing, consider:

1. **Read the TPS68470 registers live** via `i2cget` on the bus where `INT3472:06` lives. The PMIC is already powered and at REVID `0x21`. You can read the current default/reset values of the voltage control registers (`VACTL` `0x47`, `VDCTL` `0x46`, `VSIOCTL` `0x43`, etc.) to see what the PMIC reset state is.

2. **Try the OV5675 datasheet-typical voltages first**: `avdd` = 2.8V, `dovdd` = 1.8V, `dvdd` = 1.2V. These are standard for OV5675 and map neatly to `TPS68470_ANA`, `TPS68470_VSIO`, and `TPS68470_CORE` respectively. The Surface Go pattern with INT347A (which is also an OmniVision sensor) uses very similar values.

3. **The GPIO pin for reset** might be discoverable from ACPI `_DSD` data in `ssdt17.dsl` if there's a `gpio-line-names` or similar property, or from the `GPCTL` register access patterns in the Windows driver.

### 3. The VoltageWF vs VoltageUF distinction

The Windows driver has both `Tps68470VoltageWF` and `Tps68470VoltageUF` classes. "WF" and "UF" likely stand for "world-facing" (rear) and "user-facing" (front) cameras. Since the Prestige 13 probably only has a front-facing webcam, **VoltageUF may actually be the relevant path**, not VoltageWF. Worth checking which class the active sensor initialization path uses. The ACPI `C0TP` variable or the Windows INF `SensorPosition` setting might clarify this.

### 4. One potential complication to watch for

The `CDEP` routing to `CLP0` instead of `DSC0` means this is on the "PMIC companion" path. The existing upstream board-data entries (Surface Go, Dell 7212) all use the same `CLP`-style TPS68470 path, so the Linux `int3472-tps68470` driver should handle it. But double-check that the `tps68470.c` probe doesn't have any additional Lunar Lake or IPU7-era requirements that weren't present for the Kaby Lake era Surface Go. The Torvalds HEAD diff against v6.19 only touched `discrete.c` and `tps68470.c` — worth checking what exactly changed in `tps68470.c`.

### 5. Gap: exact DMI strings needed for the patch

The `dmi.txt` in the ACPI capture has the info, but the exact `DMI_SYS_VENDOR` string has not been recorded in a ready-to-patch form. For the kernel patch, the exact string from `/sys/class/dmi/id/sys_vendor` is needed — it's likely `Micro-Star International Co., Ltd.` but worth confirming it matches exactly.

### 6. Minor: ACPI DSL files not committed

The git status shows a pile of untracked DSL files under `reference/acpi/.../dsl/` and `reference/acpi/.../tables/`. These are the disassembled ACPI tables that are crucial to the analysis. If the other agent hasn't committed them yet, they should be — they're the primary evidence for the camera topology analysis.

## Live I2C Register Dump (2026-03-08)

We ran a read-only register dump of the TPS68470 on I2C bus 1 during the review session. The script is at `scripts/i2c-dump.sh` (run as root). Full results follow.

### Bus scan

`i2cdetect -y 1` shows **only one device responding on bus 1: address 0x4D.** Nothing at 0x4C or elsewhere. The controller warned `Can't use SMBus Quick Write command, will skip some addresses` — some address ranges were not probed.

### REVID discrepancy (needs investigation)

**REVID at 0x4D reads 0x00**, but the kernel boot log reports `TPS68470 REVID: 0x21` for `i2c-INT3472:06`.

Possible explanations (not confirmed):
- The kernel's regmap layer may use a different I2C transfer type than `i2cget`'s default SMBus byte read
- The `int3472-tps68470` driver probe failure (no board data) may leave the device in an unexpected state
- Register 0x00 may behave differently depending on the SMBus protocol used

**Action for colleague:** Check `journalctl -k -b | grep -i REVID` to confirm the 0x21 reading is from this boot. Also consider whether the kernel's regmap I2C reads differ from raw `i2cget -y 1 0x4d 0x00` — if the driver uses `regmap_read` with a different byte width, that could explain the discrepancy.

Despite the REVID mystery, the non-zero register values form a consistent pattern that looks like real TPS68470 defaults, not noise. Analysis below proceeds on that assumption.

### Register dump results

All CTL (control/enable) registers have bit 0 = 0, meaning **every regulator is disabled**. This is consistent with the driver failing before enabling power.

**Pre-programmed voltage values (VAL registers):**

| Rail | Register | Value | Interpretation |
|------|----------|-------|----------------|
| VCORE | 0x20 | 0x01 | ~0.9V (near minimum) |
| VANA | 0x22 | 0x00 | not programmed — needs AVDD ~2.8V for OV5675 |
| VCM | 0x24 | 0x00 | not programmed (no VCM on this sensor) |
| VIO | 0x26 | 0x69 | **~1.8V — matches OV5675 DOVDD** |
| VSIO | 0x28 | 0x00 | not programmed |
| VAUX1 | 0x2a | 0x0a | **~1.2V — matches OV5675 DVDD** |
| VAUX2 | 0x2c | 0x00 | not programmed |

VIO and VAUX1 appear to have been initialized by BIOS/firmware with values that match the OV5675 datasheet-typical power rails. VANA (AVDD = 2.8V) still needs to be programmed by the driver.

**GPIO state:**

| Register | Value | Meaning |
|----------|-------|---------|
| GPDI (0x14) | 0x01 | GPIO0 input reads HIGH |
| GPDO (0x15) | 0x08 | GPIO3 output driven HIGH |
| GPCTL0A (0x16) | 0x01 | GPIO pair 0 config A |
| GPCTL0B (0x17) | 0x08 | GPIO pair 0 config B |
| GPCTL1A (0x18) | 0x01 | GPIO pair 1 config A |
| GPCTL1B (0x19) | 0x08 | GPIO pair 1 config B |
| GPCTL2A (0x1a) | 0x01 | GPIO pair 2 config A |
| GPCTL2B (0x1b) | 0x08 | GPIO pair 2 config B |

All three GPIO pair control registers have the same 0x01/0x08 pattern. `GPDO` = 0x08 means **GPIO3 is being actively driven high** — this could be the sensor reset or powerdown line held in inactive state. Cross-reference with the Windows `IoActive_GPIO` disassembly (which touches GPCTL registers 0x16 and 0x18) to confirm which GPIO is used for sensor reset.

**Other non-zero registers:**
- PLLCTL (0x0d) = 0x80 — PLL control, bit 7 set (likely bypass/disable)
- VSIOCTL_H (0x31) = 0x38 — high byte of VSIO control
- ILEDCTL (0x40) = 0x34 — LED control default

### What this means for the board-data patch

The register dump is **encouraging for the minimal-patch approach:**

1. **Two of three OV5675 voltage rails appear pre-programmed by firmware.** VIO (~1.8V) maps to DOVDD, VAUX1 (~1.2V) maps to DVDD. Only VANA (AVDD ~2.8V) needs explicit programming.
2. **All regulators are disabled** — the Linux driver just needs to enable the right ones. No risk of conflicting with already-active rails.
3. **GPIO3 is driven high at reset** — most likely the sensor reset or powerdown line. The board-data GPIO lookup should reference this pin. Compare with Surface Go which uses GPIO9 for reset and GPIO7 for powerdown.

### Remaining uncertainties for colleague

These are the open questions we could not resolve from the review session:

1. **REVID 0x00 vs 0x21** — is this an I2C protocol difference, a post-probe state issue, or something else? Does the kernel regmap use a different read method? This doesn't block the board-data work but should be understood.
2. **Exact rail-to-consumer mapping** — VIO and VAUX1 have plausible defaults, but which TPS68470 rail the Linux board-data should wire to each OV5675 supply name (`avdd`/`dovdd`/`dvdd`) should be confirmed against the Windows VoltageWF/UF extraction. A reasonable first guess:
   - `TPS68470_ANA` → `avdd` (2.8V, needs programming)
   - `TPS68470_VIO` or `TPS68470_VSIO` → `dovdd` (1.8V, VIO already at 0x69)
   - `TPS68470_VAUX1` or `TPS68470_CORE` → `dvdd` (1.2V, VAUX1 already at 0x0a)
3. **Which GPIO pin is reset** — GPIO3 (driven high in GPDO) is the strongest candidate but this should be confirmed from the Windows driver's `IoActive_GPIO` register writes or ACPI `_DSD` data.
4. **VoltageWF vs VoltageUF** — which Windows voltage class applies to this front-facing camera? This determines which disasm artifacts contain the actual sequencing for this sensor.
5. **Exact DMI vendor string** — still needs `cat /sys/class/dmi/id/sys_vendor` for the patch.

## Summary

The research is on the right track. The main observation is that the **actual data needed for a first testable patch is quite small** — voltage values for 3 rails, one GPIO pin number, and DMI strings. The extensive Windows driver RE is excellent insurance if the obvious values don't work, but the priority should be getting a board-data entry drafted and tested via the reprobe harness sooner rather than completing every VoltageWF method first. A wrong-but-close first attempt that gets `ov5675` to appear in the media graph (even if it doesn't stream) would be a huge signal.

The live register dump reinforces this: firmware has already partially set up the PMIC with sensible defaults for OV5675-compatible voltages. The Linux board-data patch likely just needs to enable those rails and wire the GPIO correctly.

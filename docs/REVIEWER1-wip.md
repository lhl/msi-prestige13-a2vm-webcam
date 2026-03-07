# Review: Project State as of 2026-03-08

Written during an in-progress PMIC reverse-engineering session. Read-only review of all project docs, WORKLOG, PLAN, CONTEXT, upstream board-data source, and Windows driver analysis artifacts.

## Overall Assessment

This is impressively thorough and well-organized research. The project has gone from "webcam doesn't work" to a very precise understanding of exactly what's missing in about two days. The documentation discipline is excellent — anyone could pick this up and know exactly where things stand.

## What's Been Established (Strong Evidence)

- The strongest current blocker is **missing MSI board-data** in `tps68470_board_data.c` — but board-data alone may not be sufficient if MSI requires GPIO behavior beyond what `ov5675.c` currently consumes (see `docs/tps68470-reverse-engineering.md` for the two-branch outcome)
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

1. **Read the TPS68470 registers live** via `i2cget` on the bus where `INT3472:06` lives. The PMIC is already powered and at REVID `0x21`. You can read the current state of the voltage control registers (`VACTL` `0x47`, `VDCTL` `0x48`, `S_I2C_CTL` `0x43`, etc.) to see whether anything has been enabled.

2. **Try the OV5675 datasheet-typical voltages first**: `avdd` = 2.8V, `dovdd` = 1.8V, `dvdd` = 1.2V. These are standard for OV5675 and map neatly to `TPS68470_ANA`, `TPS68470_VSIO`, and `TPS68470_CORE` respectively. The Surface Go pattern with INT347A (which is also an OmniVision sensor) uses very similar values.

3. **The GPIO pin for reset** might be discoverable from ACPI `_DSD` data in `ssdt17.dsl` if there's a `gpio-line-names` or similar property, or from the `GPCTL` register access patterns in the Windows driver.

### 3. The VoltageWF vs VoltageUF distinction

The Windows driver has both `Tps68470VoltageWF` and `Tps68470VoltageUF` classes. "WF" and "UF" likely stand for "world-facing" and "user-facing". The concrete recovered call chain (`power-sequencing-notes.md`) is built around `Tps68470VoltageWF::PowerOn/Off`, `IoActive/Idle`, and `IoActive_GPIO` — so the working hypothesis should stay on the WF path. The PowerOn cross-references do point to UF-named helper addresses, which is worth noting but not enough to flip the analysis direction based on naming alone.

### 4. One potential complication to watch for

The `CDEP` routing to `CLP0` instead of `DSC0` means this is on the "PMIC companion" path. The existing upstream board-data entries (Surface Go, Dell 7212) all use the same `CLP`-style TPS68470 path, so the Linux `int3472-tps68470` driver should handle it. But double-check that the `tps68470.c` probe doesn't have any additional Lunar Lake or IPU7-era requirements that weren't present for the Kaby Lake era Surface Go. The Torvalds HEAD diff against v6.19 only touched `discrete.c` and `tps68470.c` — worth checking what exactly changed in `tps68470.c`.

### 5. ~~Gap: exact DMI strings~~ (resolved)

The exact vendor string is already recorded in `docs/kernel-tree-status.md`. The v1 patch uses `DMI_EXACT_MATCH(DMI_BOARD_VENDOR, "Micro-Star International Co., Ltd.")`.

### 6. ~~ACPI DSL files not committed~~ (resolved)

These were committed in `cf08cf9` as noted in `docs/tps68470-reverse-engineering.md`.

## Live I2C Register Dump (2026-03-08)

We ran a read-only register dump of the TPS68470 on I2C bus 1 during the review session. The script is at `scripts/i2c-dump.sh` (run as root).

### Bus scan

`i2cdetect -y 1` shows **only one device responding on bus 1: address 0x4D.** Nothing at 0x4C or elsewhere.

### Corrected dump (second run)

The first dump used a wrong register map and its voltage/identity analysis was invalid. The script was rewritten to use addresses from `include/linux/mfd/tps68470.h`. The corrected dump follows.

**Identity:** REVID (0xFF) = **0x21** — confirmed, matches kernel log. The first dump's "REVID = 0x00" was reading the wrong register (0x00 instead of 0xFF).

**Regulator value registers:**

| Rail | Register | Value | Notes |
|------|----------|-------|-------|
| VCM | VCMVAL (0x3c) | 0x00 | not programmed |
| VAUX1 | VAUX1VAL (0x3d) | 0x00 | not programmed |
| VAUX2 | VAUX2VAL (0x3e) | 0x00 | not programmed |
| VIO | VIOVAL (0x3f) | **0x34** | pre-programmed by firmware |
| VSIO | VSIOVAL (0x40) | **0x34** | pre-programmed, same as VIO |
| VA | VAVAL (0x41) | 0x00 | not programmed |
| VD | VDVAL (0x42) | 0x00 | not programmed |

VIO and VSIO are both at 0x34. This matches the TPS68470 reset default for these registers, so it is consistent with the PMIC being in its power-on-reset state rather than necessarily indicating firmware programming. The VIO = VSIO equality is consistent with the Surface Go pattern, but cannot be attributed to firmware intent based on the dump alone. VA and VD are both zero — the driver will need to program these for OV5675's avdd and dvdd.

**Regulator control registers:**

| Register | Value | Notes |
|----------|-------|-------|
| S_I2C_CTL (0x43) | 0x00 | disabled |
| VCMCTL (0x44) | 0x00 | disabled |
| VAUX1CTL (0x45) | 0x00 | disabled |
| VAUX2CTL (0x46) | 0x00 | disabled |
| VACTL (0x47) | 0x00 | disabled |
| VDCTL (0x48) | **0x04** | bit 2 set, but enable bit 0 is NOT set |

All regulators are disabled. VDCTL = 0x04 is the only non-zero control register — bit 2 is set but the enable bit (bit 0) is off. This is likely a reset default rather than a firmware-set value.

**GPIO state:**

All 7 regular GPIOs are in input-with-pullup mode (GPCTLA = 0x01 for all), which matches the TPS68470 reset defaults. GPDO (0x27) = 0x00, nothing is actively driven. SGPO (0x22) = 0x00.

The genuinely interesting value is GPDI (0x26) = **0x69** = `0b01101001`:

| GPIO | Reads | Notes |
|------|-------|-------|
| 0 | HIGH | floating high through pullup |
| **1** | **LOW** | pulled down externally |
| **2** | **LOW** | pulled down externally |
| 3 | HIGH | floating high through pullup |
| 4 | LOW | pulled down externally |
| 5 | HIGH | floating high through pullup |
| 6 | HIGH | floating high through pullup |

GPIO1 and GPIO2 reading LOW through pullups suggests they have external connections pulling them down. The Windows driver's `IoActive_GPIO` targets these same pins (registers 0x16 and 0x18). This is **strong support for GPIO1/GPIO2 as the leading candidates** for the sensor control lines, though the GPDI reading only shows observed input levels — it does not confirm line function or the reset-vs-powerdown role assignment, which is still a guess.

**Clock registers:** All zero except PLLCTL (0x0d) = 0x80 (PLL disabled/bypass). No clocks are running.

## Review of v1 Patch Candidate (commit 0452fe2)

Reviewed `reference/patches/ms13q3-int3472-tps68470-v1.patch`, `docs/linux-board-data-candidate.md`, and `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`.

### What's good

1. **Patch structure is correct.** It follows the exact same pattern as Surface Go and Dell 7212 — regulator consumer supplies, init data, GPIO lookup table, board-data struct, and DMI match table entry.
2. **`dev_name` is correct.** `"i2c-INT3472:06"` matches the live sysfs device.
3. **Consumer device names are correct.** `"i2c-OVTI5675:00"` matches the live ACPI device.
4. **Regulator-to-supply mapping is reasonable.** ANA→avdd, CORE→dvdd, VSIO→dovdd follows the same pattern as Surface Go's OmniVision sensor.
5. **Voltage values are standard OV5675.** 2.8V/1.2V/1.8V match the datasheet.
6. **VIO always-on at 1.8V** matches the Surface Go pattern for the sensor-I2C daisy chain.
7. **DMI match uses three fields** (board vendor, product name, board name) for good specificity.
8. **GPIO pin numbers (1 and 2) are correctly derived** from the Windows `IoActive_GPIO` disassembly touching registers 0x16 (GPCTL1A) and 0x18 (GPCTL2A). The kernel's `TPS68470_GPIO_CTL_REG_A(x) = 0x14 + x*2` formula confirms 0x16→GPIO1 and 0x18→GPIO2.
9. **The patch validates** with `git apply --check` against v6.19.

### Concerns and risks

1. **GPIO1/GPIO2 role assignment is still a guess.** The patch maps GPIO1→reset, GPIO2→powerdown. The Windows driver touches both GPCTL1A and GPCTL2A, but the disassembly doesn't clearly show which is reset vs powerdown. If the first test fails, **swapping these is the first thing to try.**

2. **`ov5675.c` only consumes `reset`, not `powerdown`.** The `powerdown` GPIO lookup is harmless (it won't be requested) but also won't be used. If the sensor needs powerdown asserted/deasserted during bring-up, this is a potential gap. The agent identified this risk clearly.

3. **PowerOn cross-references point to UF-named helper addresses.** The power-sequencing notes show that `Tps68470VoltageWF::PowerOn` dispatches to helpers whose addresses cross-reference to `Tps68470VoltageUF::SetVACtl`, etc. This is worth noting if deeper register-level debugging is needed, but the working analysis is correctly built around the WF call chain and should not be shifted based on naming alone.

4. **Minor doc error in power-sequencing-notes.md:** States `VDCTL 0x48, S_I2C_CTL 0x43, and VCMCTL 0x44` — the 0x48 for VDCTL is correct per the kernel header, but the earlier reverse-engineering doc (`tps68470-reverse-engineering.md`) lists `VDCTL 0x46` which is actually VAUX2CTL. This inconsistency should be cleaned up. (Doesn't affect the patch — the Linux framework uses named constants, not raw addresses.)

### Verdict

**The patch is a sound first test candidate.** The structure is correct, the evidence trail is well-documented, and the main risks are clearly identified. The most likely failure mode is GPIO role assignment (reset vs powerdown swap), not a fundamental mapping error.

**Recommended test sequence remains:**

1. Apply patch to a kernel tree and build
2. Boot patched kernel
3. Run `scripts/webcam-run.sh snapshot` and `reprobe-modules`
4. Check whether `No board-data found for this model` is gone
5. Check whether `ov5675` appears in the media graph
6. If it fails, first try swapping GPIO1↔GPIO2 roles

**Before testing, also run the corrected `scripts/i2c-dump.sh`** to get valid voltage register readings from 0x3C-0x48 and the real REVID from 0xFF. This will confirm whether firmware has pre-programmed any voltage values and give a clean baseline.

## Summary

The research is on the right track. The v1 patch candidate is structurally sound and ready for a first live test.

The corrected live I2C dump confirms the PMIC is in its reset-default state (no regulators enabled, no GPIOs configured as outputs). The most useful observation is GPDI = 0x69, which shows GPIO1 and GPIO2 are externally pulled low — strong support for them being the sensor control lines, consistent with the Windows `IoActive_GPIO` evidence and the v1 patch GPIO choice.

The main remaining risk is the GPIO1/GPIO2 role assignment (which is reset, which is powerdown) and whether `ov5675.c`'s lack of `powerdown` consumption will be a problem. The corrected dump does not resolve this — a patched test is needed.

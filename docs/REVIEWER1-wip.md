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

## Summary

The research is on the right track. The main observation is that the **actual data needed for a first testable patch is quite small** — voltage values for 3 rails, one GPIO pin number, and DMI strings. The extensive Windows driver RE is excellent insurance if the obvious values don't work, but the priority should be getting a board-data entry drafted and tested via the reprobe harness sooner rather than completing every VoltageWF method first. A wrong-but-close first attempt that gets `ov5675` to appear in the media graph (even if it doesn't stream) would be a huge signal.

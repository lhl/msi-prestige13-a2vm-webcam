# TPS68470 Reverse Engineering

This is the canonical note for the MSI Prestige 13 AI+ Evo A2VMG camera bring-up work that depends on `INT3472`, `TPS68470`, ACPI table structure, and the MSI-submitted Windows `iactrllogic64.sys` control-logic driver.

It is the place to resume from when we need to answer any of these questions:

- what evidence we already have for the MSI-specific camera power path
- how to regenerate the Windows-driver analysis artifacts
- how to capture and review the ACPI tables on this exact machine
- what concrete sequencing logic has already been recovered from the Windows package

## Current Result

- Linux still fails before the sensor appears in the media graph because `int3472-tps68470` reports `No board-data found for this model`.
- The Windows control-logic driver is not generic glue. It contains named `TPS68470` clock, voltage, GPIO, sensor, and flash control routines, plus a common low-level register-write helper.
- We have already recovered one concrete clock write sequence from `tps68470::Tps68470Clock::StartClock`.
- We now have a full raw ACPI capture in `reference/acpi/20260308T004459-unknown-host/`.
- That capture confirms the laptop identity as `Prestige 13 AI+ Evo A2VMG` / board `MS-13Q3` / BIOS `E13Q3IMS.109`.
- The first `iasl` pass in that capture failed because the script assumed uppercase `DSDT.dat` / `SSDT*.dat` names while `acpixtract` emitted lowercase `dsdt.dat` / `ssdt*.dat`, so the raw dump and binary tables are usable but the generated DSL summary is incomplete.

## Reproduction

### ACPI capture

This requires root on the laptop:

```bash
sudo scripts/capture-acpi.sh
```

That writes a timestamped directory under `reference/acpi/` containing:

- raw `acpidump.txt`
- `dmi.txt`
- extracted binary tables under `tables/`
- `iasl` disassembly attempts under `dsl/`
- `camera-related-hits.txt` for `INT3472`, `OVTI5675`, `CLDB`, `_DSD`, GPIO, and I2C terms

Current state:

- the first successful root-collected capture is `reference/acpi/20260308T004459-unknown-host/`
- the raw dump and extracted tables are valid
- the scripted DSL generation from that run needs a small filename fix before future captures produce `camera-related-hits.txt` automatically

### Windows driver extraction

This is repeatable without root:

```bash
scripts/extract-iactrllogic64.sh
```

That regenerates `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/`, including:

- `strings-tps68470.txt`
- `method-string-addresses.txt`
- `method-string-xrefs.txt`
- `debug-directory.txt`
- `pe-header-and-imports.txt`
- targeted `disasm-*.txt` windows for sensor, clock, and voltage methods

## Windows Driver Facts

Source binary:

- `reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/extracted/iactrllogic64.sys`

Build provenance from `debug-directory.txt`:

- build timestamp: `2025-09-29 17:19:12 UTC`
- PDB path: `W:\repo\w\camerasw\Source\Camera\Platform\LNL\x64\Release\iactrllogic64.pdb`
- PDB GUID: `804BA0D7-738B-4CC9-8027-7AF3103C24B5`

Imports from `pe-header-and-imports.txt`:

- `ntoskrnl.exe`
- `HAL.dll`
- `WDFLDR.SYS`

Notable imported routines:

- `IoGetDevicePropertyData`
- `KeDelayExecutionThread`
- `KeStallExecutionProcessor`
- `MmGetSystemRoutineAddress`
- `PoFx*`

That import surface is consistent with a real KMDF hardware-control driver that issues timed transactions, not just an installation stub.

## Named Method Families

From `strings-tps68470.txt` and `method-string-addresses.txt`:

- `tps68470::TPS68470::SensorInitialize`
- `tps68470::TPS68470::SensorOn`
- `tps68470::TPS68470::SensorOff`
- `tps68470::Tps68470Clock::StartClock`
- `tps68470::Tps68470Clock::StopCLock`
- `tps68470::Tps68470Clock::ConfigHCLKAB`
- `tps68470::Tps68470Clock::EnablePLL`
- `tps68470::Tps68470Clock::Initialize`
- `tps68470::Tps68470Clock::SetHCLKAB`
- `tps68470::Tps68470VoltageUF::*`
- `tps68470::Tps68470VoltageWF::*`
- `CommonFunc::Cmd_SensorInitialize`
- `CommonFunc::Cmd_SensorPowerOn`
- `CommonFunc::Cmd_SensorPowerOff`

Implication: MSI and/or Intel are carrying camera board-specific behavior in the Windows driver. The Linux failure is therefore unlikely to be only "the sensor driver is missing".

## Concrete Sequencing Recovered

### Common write helper

Files:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-register-write-wrapper.txt`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-transport-helper.txt`

Key result:

- `0x140010be0` is a common write wrapper that takes a register index plus a value and a small width/mode parameter.
- It calls `0x1400110f4`, and if that fails it performs a delay path and retries once.
- `0x1400110f4` builds a small transaction buffer whose payload width depends on the controller state at `[ctx+0x608]` and on the width parameter (`1`, `2`, `3`, `4`, or the special case `0x20`).

This is the strongest current evidence that the Windows code is issuing structured PMIC register transactions rather than delegating the whole sequence to firmware.

### Clock start sequence

File:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-start.txt`

`tps68470::Tps68470Clock::StartClock` at `0x14000c230` writes this register sequence through the common helper:

1. `0x0a`
2. `0x08`
3. `0x07`
4. `0x0b`
5. `0x0c`
6. `0x06`
7. `0x10`
8. `0x09`
9. `0x0d`

The values are not constants. They are assembled from stored config bytes in the object, including offsets around:

- `0x14` through `0x19`
- `0x1c` through `0x1e`

It also packs bitfields before some writes:

- one value combines the low two bits from offsets `0x1c` and `0x1d`
- another value shifts offset `0x1e` and ORs in `0x81`

This looks like board-specific clock and mux configuration, not a trivial enable.

### Clock config helper

File:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-confighclkab.txt`

`tps68470::Tps68470Clock::ConfigHCLKAB` at `0x14000b8d0`:

- reads register `0x0d`
- clears bit `0`
- writes the masked value back to `0x0d`
- then reads register `0x0f`

That means the clock path is doing read-modify-write logic, not just blasting a canned byte sequence.

### VoltageWF examples

Files:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvactl.txt`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvsioctl-gpio.txt`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-ioactive-gpio.txt`

What is concrete so far:

- `Tps68470VoltageWF::SetVACtl` uses register `0x47`.
  - It reads the current byte, conditionally sets or clears bit `0`, and writes the new value back.
  - The decision depends on both the enable flag and whether a stored configuration word at object offset `0x0a` is nonzero.
- `Tps68470VoltageWF::SetVSIOCtl_GPIO` uses register `0x43`.
  - It follows the same general pattern: read the current byte, conditionally set or clear bit `0`, then write it back.
  - The decision depends on the enable flag and whether a stored configuration word at offset `0x10` is nonzero.
- `Tps68470VoltageWF::IoActive_GPIO` performs additional GPIO-related register read/modify/write steps using registers `0x16` and `0x18`.

This strongly suggests the Windows driver is carrying a board-specific set of stored configuration fields that decide which rails or GPIO-backed subfunctions are active on this platform.

## SensorOn / SensorOff Shape

Files:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoron.txt`
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoroff.txt`

What we can say confidently now:

- `SensorOn` and `SensorOff` are real method bodies that operate on several subordinate objects, not empty wrappers.
- Both copy a 0x40-byte configuration blob from the caller onto the stack and pass that blob through a chain of virtual-method calls.
- `SensorOn`:
  - requires a subordinate object at `this+0x18`
  - calls a method at that object's vtable offset `+0x08`
  - checks another object at `this+0x08`
  - if needed, calls base-object methods at vtable offsets `+0x08` and `+0x10`
  - then calls another method on the `this+0x18` object with enable flag `1`
  - finally performs a local cleanup call
- `SensorOff`:
  - optionally calls a helper at `0x14000db08` depending on mode values from the caller
  - calls the `this+0x18` subordinate path with enable flag `0`
  - then calls another `this+0x18` vtable method at offset `+0x28`
  - then performs local cleanup and a timed helper call

So even before full decompilation, the recovered control flow shows that camera power-up and power-down are coordinated in software and depend on MSI/Intel-owned config objects.

## Why This Matters For Linux

These findings push the Linux-side hypothesis in a more precise direction:

- The blocker is probably not "missing `ov5675` support".
- The blocker is probably not only "missing one DMI string".
- The Windows driver appears to encode board-specific PMIC and GPIO behavior, likely through per-board config structures plus explicit register writes.

That still leaves two realistic Linux outcomes:

1. The MSI board is close enough to an existing `TPS68470` pattern that Linux only needs a new board-data match and config struct.
2. The MSI board needs new regulator/GPIO/clock data derived from the Windows sequence and the ACPI tables.

The raw `acpidump` is what should tell us which object graph and GPIO naming the firmware exposes on this exact laptop.

## Immediate Next Steps

1. Run `sudo scripts/capture-acpi.sh` on this laptop and commit the resulting `reference/acpi/...` directory.
2. Compare the recovered Windows register indices against the local `reference/tps68470.pdf` register map.
3. Decide whether the Linux patch path looks like:
   - a missing board-data match only, or
   - a new MSI-specific `TPS68470` data definition
4. Correlate the Windows control logic with Linux `drivers/platform/x86/intel/int3472/` expectations in:
   - `reference/linux-mainline-v6.19/drivers/platform/x86/intel/int3472/`
   - `reference/linux-torvalds-head/drivers/platform/x86/intel/int3472/`

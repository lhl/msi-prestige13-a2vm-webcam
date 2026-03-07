# ACPI Capture

- Captured UTC: 2026-03-07T15:44:59Z
- Host: unknown-host
- Kernel: 6.18.9-arch1-2

## Files

- `acpidump.txt` — raw text ACPI dump
- `dmi.txt` — DMI identity snapshot taken alongside the dump
- `tables/` — binary tables extracted by `acpixtract -a`
- `dsl/` — regenerated DSDT/SSDT disassembly outputs
- `camera-related-hits.txt` — grep summary for camera-relevant ACPI terms from the committed DSL
- `live-linux-acpi-state.txt` — live sysfs snapshot of `OVTI5675` and `INT3472` state captured during review

## Current Status

- Raw ACPI text and extracted binary tables are from the original root capture on this laptop.
- The committed DSL under `dsl/` was regenerated afterward from those binary tables once the capture directory became writable.
- `camera-related-hits.txt` is valid for this capture now; the originally committed empty version came from the first failed lowercase-table disassembly attempt.

## Regeneration

```bash
sudo scripts/capture-acpi.sh
```

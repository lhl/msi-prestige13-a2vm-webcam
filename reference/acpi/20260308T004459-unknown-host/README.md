# ACPI Capture

- Captured UTC: 2026-03-07T15:44:59Z
- Host: unknown-host
- Kernel: 6.18.9-arch1-2

## Files

- `acpidump.txt` — raw text ACPI dump
- `dmi.txt` — DMI identity snapshot taken alongside the dump
- `tables/` — binary tables extracted by `acpixtract -a`
- `dsl/` — DSDT/SSDT disassembly attempts via `iasl`
- `camera-related-hits.txt` — grep summary for camera-relevant ACPI terms

## Regeneration

```bash
sudo scripts/capture-acpi.sh
```

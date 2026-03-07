# iactrllogic64 Static Analysis

- Package: `msi-ov5675-70.26100.19939.1`
- Source binary: `/home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/extracted/iactrllogic64.sys`
- Generated UTC: 2026-03-07T15:39:23Z

## Files

- `strings-tps68470.txt` — named TPS68470- and sensor-related method strings
- `method-string-addresses.txt` — string virtual-address mapping inside the PE image
- `method-string-xrefs.txt` — disassembly lines that reference those method-name strings
- `pe-header-and-imports.txt` — PE metadata and imports
- `debug-directory.txt` — PDB path and CodeView GUID
- `load-config.txt` — GuardCF table and related load-config metadata
- `disasm-*.txt` — targeted disassembly windows for the current investigation

## Regeneration

```bash
scripts/extract-iactrllogic64.sh
```

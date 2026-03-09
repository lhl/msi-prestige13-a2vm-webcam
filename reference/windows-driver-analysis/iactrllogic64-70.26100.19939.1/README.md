# iactrllogic64 Static Analysis

- Package: `msi-ov5675-70.26100.19939.1`
- Source binary: `/home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/extracted/iactrllogic64.sys`
- Generated UTC: 2026-03-09T03:36:59Z

## Files

- `strings-tps68470.txt` — named TPS68470- and sensor-related method strings
- `strings-tps68470-with-offsets.txt` — same string set with raw file offsets for address correlation
- `method-string-addresses.txt` — string virtual-address mapping inside the PE image
- `method-string-xrefs.txt` — disassembly lines that reference those method-name strings
- `pe-header-and-imports.txt` — PE metadata and imports
- `debug-directory.txt` — PDB path and CodeView GUID
- `load-config.txt` — GuardCF table and related load-config metadata
- `disasm-*.txt` — targeted disassembly windows for the current investigation, including VoltageWF constructor/init/setconf, WF/UF power paths, and CrdG2TiSensor helpers

## Regeneration

```bash
scripts/extract-iactrllogic64.sh
```

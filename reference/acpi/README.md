# ACPI Reference Area

Root-only ACPI captures from this machine should be stored here in timestamped subdirectories.

Capture command:

```bash
sudo scripts/capture-acpi.sh
```

Each capture directory should contain:

- raw `acpidump.txt`
- `dmi.txt`
- extracted binary tables under `tables/`
- `iasl` output under `dsl/`
- `camera-related-hits.txt`

The goal is to keep ACPI evidence in-repo so future work does not depend on rediscovering or re-running the same capture steps.

Current capture:

- `20260308T004459-unknown-host/`
  - first raw dump from the MSI Prestige 13 AI+ Evo A2VMG / `MS-13Q3`
  - raw dump and extracted tables are valid
  - first `iasl` disassembly attempt failed because the capture script assumed uppercase table filenames

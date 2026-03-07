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

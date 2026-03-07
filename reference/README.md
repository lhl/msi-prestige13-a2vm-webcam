# Reference Index

Captured upstream sources relevant to webcam bring-up on the MSI Prestige 13 AI+ Evo A2VMG / A2VM family.

## Current References

- `reference/greymouser-summit-13-ai-evo-a2vm.md`
  - Related MSI Summit 13 AI+ Evo A2VMTG repo with Linux IIO sensor and LED control work
  - Captured: 2026-03-08
- `reference/intel-ipu7-drivers-issue-17.md`
  - Intel IPU7 upstream issue for this laptop family
  - Captured: 2026-03-07
- `reference/intel-control-logic-microsoft-update-catalog-71.26100.23.20279.md`
  - Microsoft Update Catalog entry and CAB URL for the Windows `ACPI\INT3472` control-logic package
  - Captured: 2026-03-07
- `reference/jeremy-grosser-prestige13-notes.md`
  - MSI Prestige 13 Debian notes gist with camera-related findings
  - Captured: 2026-03-07
- `reference/linux-mainline-v6.19/README.md`
  - Local snapshot of `drivers/platform/x86/intel/int3472/` from the inspected `v6.19` kernel tree
  - Captured: 2026-03-07
- `reference/linux-torvalds-head/README.md`
  - Current Torvalds `HEAD` snapshot of `drivers/platform/x86/intel/int3472/` for upstream comparison
  - Captured: 2026-03-07
- `reference/msi-ov5675-microsoft-update-catalog-70.26100.19939.1.md`
  - Exact Microsoft Update Catalog entry and direct CAB URL for the MSI-submitted `OV5675` package
  - Captured: 2026-03-07
- `reference/tps68470.pdf`
  - Local TPS68470 datasheet copy for PMIC and regulator reference
  - Captured locally: 2026-03-07
- `reference/acpi/README.md`
  - Root-only ACPI capture area for this exact machine
  - Added: 2026-03-08
- `reference/acpi/20260308T004459-unknown-host/README.md`
  - First real ACPI capture from the MSI Prestige 13 AI+ Evo A2VMG / `MS-13Q3`
  - Captured: 2026-03-08
- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/README.md`
  - Repeatable static-analysis artifacts for the MSI package's `iactrllogic64.sys`
  - Generated: 2026-03-08
- `reference/patches/ms13q3-int3472-tps68470-v1.patch`
  - First-pass Linux `tps68470_board_data` candidate for `MS-13Q3` / `OVTI5675:00`
  - Drafted: 2026-03-08
- `reference/windows-driver-packages/README.md`
  - In-repo archive index for vendored Windows camera packages and extracted trees
  - Captured: 2026-03-07

## Conventions

- Prefer stable descriptive filenames.
- Record source URL and capture date at the top of each note.
- Summarize the source in our own words; keep direct quotes minimal.
- Update this index whenever a new reference is added.

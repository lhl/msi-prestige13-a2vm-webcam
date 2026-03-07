# Windows Driver Package Archive

Captured: 2026-03-07

This directory vendors the Windows camera-driver packages we are dissecting for Linux webcam bring-up. The goal is to keep the exact CABs and extracted trees inside the private repo so future analysis does not depend on `/tmp` state or rediscovering Microsoft Update Catalog links.

## Layout

- `reference/windows-driver-packages/intel-control-logic-71.26100.23.20279/`
  - CAB: `intel-control-logic-71.26100.23.20279.cab`
  - Extracted tree: `extracted/`
  - Source note: `reference/intel-control-logic-microsoft-update-catalog-71.26100.23.20279.md`
- `reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/`
  - CAB: `ovti5675-msi-70.26100.19939.1.cab`
  - Extracted tree: `extracted/`
  - Source note: `reference/msi-ov5675-microsoft-update-catalog-70.26100.19939.1.md`

## Current archive contents

- `intel-control-logic-71.26100.23.20279`
  - Source origin: Microsoft Update Catalog package for `ACPI\INT3472`
  - Original local paths:
    - `/tmp/int3472-winpkg/intel-control-logic-71.26100.23.20279.cab`
    - `/tmp/int3472-winpkg/extracted`
  - Current in-repo footprint: about `246M`
  - Current file count: `178`
- `msi-ov5675-70.26100.19939.1`
  - Source origin: Microsoft Update Catalog package for `ACPI\OVTI5675`
  - Original local paths:
    - `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
    - `/tmp/ovti5675-msi/extracted2`
  - Current in-repo footprint: about `219M`
  - Current file count: `78`

## Git LFS policy

The binary-heavy file types under this archive path are tracked with Git LFS:

- `*.cab`
- `*.sys`
- `*.dll`
- `*.bin`
- `*.aiqb`
- `*.cpf`
- `*.cat`
- `*.bmp`

Text files such as `*.inf`, `*.xml`, and `*.txt` stay in normal git so they remain directly diffable.

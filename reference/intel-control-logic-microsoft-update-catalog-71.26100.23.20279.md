# Intel Control Logic Microsoft Update Catalog Package

Captured: 2026-03-07

## Source URLs

- Search URL (hardware ID): `https://www.catalog.update.microsoft.com/Search.aspx?q=ACPI%5CINT3472`
- Scoped view: `https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=eafdad1e-3b31-4a1a-891c-b8a328c30d4a`

## Exact catalog entry

- Title: `Intel Corporation - System - 71.26100.23.20279`
- UpdateID: `eafdad1e-3b31-4a1a-891c-b8a328c30d4a`
- Company: `Compal Electronics, Inc`
- Driver Manufacturer: `Intel Corporation`
- Supported Hardware IDs:
  - `ACPI\INT3472`
  - `ACPI\INT346F`

## Direct download

- CAB URL: `https://catalog.s.download.windowsupdate.com/d/msdownload/update/driver/drvs/2026/01/17f6073e-7505-4879-96c9-1d96dfbd956f_72163f3e02120b81d4e24b4397bb3b857c62e454.cab`

## Local copy on this machine

- Downloaded CAB: `/tmp/int3472-winpkg/intel-control-logic-71.26100.23.20279.cab`
- Extracted files: `/tmp/int3472-winpkg/extracted`

## Key extracted files

- `iactrllogic64.inf`
- `iactrllogic64.sys`
- `iacamera64.inf`
- `iacamera64.sys`
- `iaisp64.inf`
- `iaisp64.sys`
- multiple sensor-specific graph blobs and tuning files (`*.bin`, `*.cpf`, `*.aiqb`)

## Why this package matters

- It covers the Windows `ACPI\INT3472` control-logic path that Linux currently fails on with `No board-data found for this model`.
- `iactrllogic64.sys` contains `TPS68470`-related strings, which is strong evidence that Windows carries PMIC sequencing logic relevant to Linux board-data reconstruction.

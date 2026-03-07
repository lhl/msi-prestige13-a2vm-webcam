# MSI OV5675 Microsoft Update Catalog Package

Captured: 2026-03-07

## Source URLs

- Search URL: `https://www.catalog.update.microsoft.com/Search.aspx?q=ov5675`
- Search URL (hardware ID): `https://www.catalog.update.microsoft.com/Search.aspx?q=ACPI%5COVTI5675`
- Scoped view: `https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=8fd6696d-67b8-4bc7-a477-6d8800725426`
- Scoped view (`www` form): `https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=8fd6696d-67b8-4bc7-a477-6d8800725426`

## Exact catalog entry

- Title: `Intel Corporation Driver Update (70.26100.19939.1)`
- Last Modified: `2025-10-30`
- Size: `46.0 MB`
- UpdateID: `8fd6696d-67b8-4bc7-a477-6d8800725426`
- Description: `Intel Corporation System driver update released in October 2025`
- Architecture: `AMD64`
- Classification: `Drivers`
- Supported products:
  - `Windows 11 Client, version 24H2 and later, Servicing Drivers`
  - `Windows 11 Client, version 24H2 and later, Upgrade & Servicing Drivers`
- Supported languages: `Arabic, Bulgarian, Chinese (Traditional), Czech, Danish, German, Greek, English, Spanish, Finnish, French, Hebrew, Hungarian, Italian, Japanese, Korean, Dutch, Norwegian, Polish, Portuguese (Brazil), Romanian, Russian, Croatian, Slovak, Swedish, Thai, Turkish, Ukrainian, Slovenian, Estonian, Latvian, Lithuanian, Chinese (Simplified), Portuguese (Portugal), Serbian (Latin), Chinese - Hong Kong SAR`
- Company: `MICRO-STAR INTERNATIONAL CO., LTD`
- Driver Manufacturer: `Intel Corporation`
- Driver Class: `OtherHardware`
- Driver Model: `Camera Sensor OV5675`
- Driver Provider: `Intel Corporation`
- Version: `70.26100.19939.1`
- Version Date: `2025-10-30`
- Supported Hardware ID: `ACPI\OVTI5675`

Related links shown in the catalog entry:

- More information: `https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/hardware-submission-support`
- Support URL: `https://support.microsoft.com/select/?target=hub`

## Direct download

- CAB URL: `https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2026/02/8a77f110-818a-4dee-b65b-291e97512d0f_0e7b66ca05a48e8131f5ef36e983f419b4ebef52.cab`

## Local copy on this machine

- Downloaded CAB: `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
- Extracted files: `/tmp/ovti5675-msi/extracted2`

## Key extracted files

- `ov5675.inf`
- `ov5675.sys`
- `ov5675_extension_msi.inf`
- `iacamera64.inf`
- `iacamera64_ext_msi.inf`
- `iactrllogic64.inf`
- `iactrllogic64.sys`
- `iaisp64.inf`
- `graph_settings_ov5675_bcab65_lnl.bin`
- `graph_settings_ov5675_s5vm17_lnl.bin`

## Why this package matters

- This is an MSI-submitted package for the exact sensor hardware ID `ACPI\OVTI5675`.
- It is newer than the package mentioned in the upstream GitHub issue comment (`Camera_QS_70.26100.16578.14_MSI_13Q3_LNL_20240726.zip`).
- It includes both the sensor driver and the Windows-side control-logic stack (`iactrllogic64`) plus MSI/Lunar Lake graph-setting blobs.

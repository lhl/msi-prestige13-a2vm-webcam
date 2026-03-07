# Kernel Tree Status

Updated: 2026-03-07

## Local source location

The full local `linux-mainline` source tree currently used for inspection is:

`~/.cache/paru/clone/linux-mainline/src/linux-mainline`

On this machine, that tree reports:

- Git revision: `05f7e89ab973`
- Version tag: `v6.19`

## Most relevant files

- `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
- `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470.c`
- `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`

## Local machine identity used for matching

- `sys_vendor`: `Micro-Star International Co., Ltd.`
- `product_name`: `Prestige 13 AI+ Evo A2VMG`
- `board_name`: `MS-13Q3`

## Current finding in local `v6.19` source

The `INT3472` / `TPS68470` board-data table does **not** contain this MSI laptop.

The current table in `tps68470_board_data.c` only includes:

- `Microsoft Corporation` / `Surface Go`
- `Microsoft Corporation` / `Surface Go 2`
- `Microsoft Corporation` / `Surface Go 3`
- `Dell Inc.` / `Latitude 7212 Rugged Extreme Tablet`

It also hardcodes board-data `dev_name` values only for:

- `i2c-INT3472:05`
- `i2c-INT3472:01`

This machine’s boot log shows:

- `i2c-INT3472:06`
- `error -ENODEV: No board-data found for this model`

So the current local source strongly supports the conclusion that the PMIC board-data path for this MSI board is still missing in `v6.19`.

## Related confirmation

The sensor side is present in the same source tree:

- `drivers/media/i2c/ov5675.c` includes ACPI match `OVTI5675`

So the current source-tree picture is:

- `ov5675` sensor support: present
- `INT3472` / `TPS68470` generic support: present
- MSI `MS-13Q3` board-data entry: absent

## Fast commands to revisit later

```bash
cd ~/.cache/paru/clone/linux-mainline/src/linux-mainline
git rev-parse --short HEAD
git describe --tags --always
nl -ba drivers/platform/x86/intel/int3472/tps68470_board_data.c | sed -n '260,336p'
nl -ba drivers/platform/x86/intel/int3472/tps68470.c | sed -n '176,184p'
nl -ba drivers/media/i2c/ov5675.c | sed -n '1355,1379p'
```

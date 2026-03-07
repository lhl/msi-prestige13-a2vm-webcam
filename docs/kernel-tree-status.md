# Kernel Tree Status

Updated: 2026-03-08

## Local package-cache layout

The current `paru` package-cache root for `linux-mainline` is:

`~/.cache/paru/clone/linux-mainline`

Right now it contains:

- `PKGBUILD` and package artifacts at the package root
- a cached bare Git repository at `~/.cache/paru/clone/linux-mainline/linux-mainline`
- no editable `src/linux-mainline` worktree yet

The editable source worktree that `makepkg` actually builds from is:

`~/.cache/paru/clone/linux-mainline/src/linux-mainline`

That worktree only appears after `makepkg` runs the source checkout / prepare phase.

## Current cached upstream source

The cached bare repo currently reports:

- Git revision: `4ae12d8bd9a8`
- Version describe: `v7.0-rc2-467-g4ae12d8bd9a8`

## Most relevant files

- cached-source view:
  - `HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - `HEAD:drivers/platform/x86/intel/int3472/tps68470.c`
  - `HEAD:drivers/media/i2c/ov5675.c`
- build-worktree paths after `makepkg` prepare:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470.c`
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`

## Local machine identity used for matching

- `sys_vendor`: `Micro-Star International Co., Ltd.`
- `product_name`: `Prestige 13 AI+ Evo A2VMG`
- `board_name`: `MS-13Q3`

## Current finding in cached `v7.0-rc2` source

The `INT3472` / `TPS68470` board-data table does **not** contain this MSI laptop.

The current cached `tps68470_board_data.c` still only includes:

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

So the current cached upstream source still strongly supports the conclusion that the PMIC board-data path for this MSI board is missing in `v7.0-rc2`.

## Current patch status

The first candidate patch in this repo still applies cleanly to the current cached board-data source content:

- `reference/patches/ms13q3-int3472-tps68470-v1.patch`

That was re-checked by extracting the current `HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c` from the bare cache into a temp tree and running `git apply --check` against it.

## Related confirmation

The sensor side is present in the same source tree:

- `drivers/media/i2c/ov5675.c` includes ACPI match `OVTI5675`

So the current source-tree picture is:

- `ov5675` sensor support: present
- `INT3472` / `TPS68470` generic support: present
- MSI `MS-13Q3` board-data entry: absent

## Fast commands to revisit later

```bash
git --git-dir=~/.cache/paru/clone/linux-mainline/linux-mainline rev-parse --short HEAD
git --git-dir=~/.cache/paru/clone/linux-mainline/linux-mainline describe --tags --always
git --git-dir=~/.cache/paru/clone/linux-mainline/linux-mainline show HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c | tail -n 80

# after makepkg has created the editable worktree:
cd ~/.cache/paru/clone/linux-mainline/src/linux-mainline
git rev-parse --short HEAD || true
git describe --tags --always || true
nl -ba drivers/platform/x86/intel/int3472/tps68470_board_data.c | sed -n '260,360p'
nl -ba drivers/platform/x86/intel/int3472/tps68470.c | sed -n '176,184p'
nl -ba drivers/media/i2c/ov5675.c | sed -n '1355,1379p'
```

# Module Iteration Workflow

Updated: 2026-03-08

This note captures the faster iteration path for camera-related kernel work on
this laptop so we do not need a full kernel rebuild for every small change.

## Short answer

Yes. For the current `linux-mainline` setup, we can usually iterate on the
camera path by rebuilding only the affected modules instead of rebuilding the
entire kernel package.

The current `.config` in the `7.0.0-rc2` worktree has these as modules:

- `CONFIG_INTEL_SKL_INT3472=m`
- `CONFIG_VIDEO_OV5675=m`
- `CONFIG_IPU_BRIDGE=m`
- `CONFIG_GPIO_TPS68470=m`
- `CONFIG_REGULATOR_TPS68470=m`

That means changes in these areas do not normally require a full kernel image
rebuild:

- `drivers/platform/x86/intel/int3472/`
- `drivers/media/i2c/ov5675.c`
- `drivers/media/pci/intel/ipu-bridge.c`
- `drivers/clk/clk-tps68470.c`
- `drivers/gpio/gpio-tps68470.c`
- `drivers/regulator/tps68470-regulator.c`

## Good use cases

Use the module-only path when changing:

- `tps68470_board_data.c`
- `tps68470.c`
- `ov5675.c`
- `ipu-bridge.c`
- camera-adjacent PMIC clock / GPIO / regulator modules

Use a full kernel rebuild when changing:

- built-in storage or boot-critical code
- `.config`
- exported symbols or common headers that cause wide rebuild fallout
- anything that stops being a module

## Fast rebuild commands

Assuming the running test kernel is already the matching
`7.0.0-rc2-1-mainline-dirty` build:

```bash
cd ~/.cache/paru/clone/linux-mainline/src/linux-mainline

make M=drivers/platform/x86/intel/int3472 modules
make M=drivers/media/i2c modules
make M=drivers/media/pci/intel modules
make M=drivers/clk modules
make M=drivers/gpio modules
make M=drivers/regulator modules
```

This is still broader than the absolute minimum, but it is much faster than a
full `makepkg`.

## Install path

Copy only the modules you actually changed into the running kernel's module
tree, then run `depmod`.

Examples:

```bash
sudo install -Dm644 \
  drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko \
  /usr/lib/modules/$(uname -r)/kernel/drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko

sudo install -Dm644 \
  drivers/media/i2c/ov5675.ko \
  /usr/lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko

sudo install -Dm644 \
  drivers/media/pci/intel/ipu-bridge.ko \
  /usr/lib/modules/$(uname -r)/kernel/drivers/media/pci/intel/ipu-bridge.ko

sudo depmod -a "$(uname -r)"
```

If you changed one of the PMIC helper modules, install that updated `.ko` too.

## Reload strategy

After installing replacement modules, prefer a targeted reload rather than a
reboot when possible.

Typical sensor-path iteration:

```bash
sudo modprobe -r ov5675
sudo modprobe ov5675
```

Typical board-data / PMIC iteration:

```bash
sudo modprobe -r ov5675 intel_skl_int3472_tps68470 intel_skl_int3472_common
sudo modprobe intel_skl_int3472_tps68470
sudo modprobe ov5675
```

If module dependencies or the live graph get stuck, reboot once and continue
with module-only rebuilds afterward.

## Practical recommendation for this repo

For the next diagnostic step, a full kernel rebuild is unnecessary.

The likely next edit is in `ov5675.c` or `ipu-bridge.c`, so the faster loop is:

1. edit the source under `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
2. rebuild only the touched modules
3. install the new `.ko` files into `/usr/lib/modules/$(uname -r)/...`
4. run `depmod`
5. reload the relevant modules or reboot if the live state is messy
6. capture the result with `scripts/webcam-run.sh`

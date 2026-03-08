# OV5675 Diagnostic Patch

Updated: 2026-03-08

This note captures the first small diagnostic patch for the remaining
`ov5675` probe failure on the patched `7.0.0-rc2-1-mainline-dirty` kernel.

## Why this patch exists

The first MSI `INT3472` / `TPS68470` board-data patch moved the failure
forward:

- `No board-data found for this model` is gone
- `i2c-OVTI5675:00` now exists
- `ov5675` still does not bind
- there is still no useful `ov5675` probe error in the kernel log

The current `ov5675` driver has two silent early `-ENXIO` exits in
`ov5675_get_hwcfg()`:

- no firmware node on the sensor device
- no firmware graph endpoint on that firmware node

Those are good candidates because they would fit the current symptom pattern:

- sensor client instantiated
- no media subdevice
- no explicit `ov5675` error line

## Patch artifact

Patch file:

- `reference/patches/ov5675-probe-diagnostics-v1.patch`

What it adds:

- explicit error for missing firmware node
- explicit error for missing firmware graph endpoint
- explicit `dev_err_probe()` logging for regulator lookup failures
- explicit `dev_err_probe()` logging for endpoint-parse failures

Expected new log lines if one of those paths is the blocker:

- `ov5675 ... no firmware node found for sensor device`
- `ov5675 ... no firmware graph endpoint found`
- `ov5675 ... failed to get sensor regulators`
- `ov5675 ... failed to parse firmware graph endpoint`

## Step-By-Step Test

These steps use a module-only rebuild on the already booted
`7.0.0-rc2-1-mainline-dirty` kernel.

### 1. Capture a before snapshot

```bash
cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam
scripts/webcam-run.sh snapshot --label before-ov5675-diag --note "before ov5675 diagnostic patch"
```

### 2. Apply the diagnostic patch to the prepared `linux-mainline` source tree

```bash
cd ~/.cache/paru/clone/linux-mainline/src/linux-mainline
patch -Np1 < /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/patches/ov5675-probe-diagnostics-v1.patch
```

Optional verification:

```bash
rg -n 'no firmware node found|no firmware graph endpoint found|failed to get sensor regulators|failed to parse firmware graph endpoint' drivers/media/i2c/ov5675.c
```

### 3. Rebuild only the `ov5675` module

```bash
make M=drivers/media/i2c modules
```

### 4. Replace the installed Arch module with a compressed replacement

The installed module is currently:

- `/usr/lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko.zst`

Compress the rebuilt module so the replacement matches the packaged filename:

```bash
zstd -T0 -f drivers/media/i2c/ov5675.ko -o /tmp/ov5675.ko.zst
```

Optional backup:

```bash
sudo cp -a \
  /usr/lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko.zst \
  /tmp/ov5675.ko.zst.stock.$(date +%Y%m%dT%H%M%S)
```

Install the replacement and refresh module metadata:

```bash
sudo install -Dm644 /tmp/ov5675.ko.zst \
  /usr/lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko.zst

sudo depmod -a "$(uname -r)"
```

### 5. Reload the module

```bash
sudo modprobe -r ov5675
sudo modprobe ov5675
```

If the live graph state looks stale, use the repo harness instead:

```bash
sudo scripts/webcam-run.sh reprobe-modules --label after-ov5675-diag
```

### 6. Capture the result

```bash
scripts/webcam-run.sh snapshot --label after-ov5675-diag --note "after ov5675 diagnostic patch"

journalctl -b -k --no-pager | \
  rg 'ov5675|OVTI5675|firmware graph|firmware node|xvclk|reset|regulator|ipu7'

ls -l /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || true
media-ctl -p -d /dev/media0
find /dev -maxdepth 1 -name 'v4l-subdev*' | sort
```

## How to interpret the result

- `no firmware node found for sensor device`
  - the sensor client exists, but Linux is not attaching the expected firmware
    node to it
- `no firmware graph endpoint found`
  - the likely next target is firmware-node / `ipu-bridge` hookup, not PMIC
    power sequencing
- `failed to get sensor regulators`
  - the board-data regulator consumer mapping is still incomplete or wrong
- `failed to parse firmware graph endpoint`
  - the fwnode exists, but its endpoint data is missing or malformed for
    `ov5675`
- no new `ov5675` diagnostic line, but a later failure appears
  - that is still useful; it means the probe progressed past the silent early
    exits

## Practical takeaway

For this patch, a full kernel rebuild is unnecessary. The module-only path is
the right default:

1. patch `drivers/media/i2c/ov5675.c`
2. rebuild `drivers/media/i2c`
3. replace `ov5675.ko.zst`
4. `depmod`
5. reload and capture

# Worklog

## 2026-03-08

### Record the clean combined-patch boot result and pivot to `ov5675` power-on sequencing

- Plan: preserve the first clean combined-patch boot, resolve the earlier
  dummy-regulator ambiguity, and turn the new `dvdd` timeout into the next
  concrete module-only patch target.
- Commands:
  - reviewed the new clean-boot run:
    - `runs/2026-03-08/20260308T143023-snapshot-clean-boot-after-ipu-bridge/`
  - reviewed the user-run checks:
    - `journalctl -b -k --no-pager | rg 'TPS68470 REVID|Found supported sensor|Connected 1 cameras|supply avdd|supply dovdd|supply dvdd|failed to find sensor|probe with driver ov5675 failed'`
    - `readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || echo int3472-unbound`
    - `readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo ov5675-unbound`
    - `find /dev -maxdepth 1 -name 'v4l-subdev*' | sort`
  - extracted the sharper failure lines from the same boot:
    - `journalctl -b -k --no-pager | rg 'Failed to enable|failed to power on|ov5675 i2c-OVTI5675:00|tps68470|TPS68470 REVID'`
  - reviewed the relevant kernel paths:
    - `drivers/media/i2c/ov5675.c`
    - `drivers/regulator/core.c`
    - `drivers/regulator/tps68470-regulator.c`
  - `apply_patch` adding and updating:
    - `runs/2026-03-08/20260308T143023-snapshot-clean-boot-after-ipu-bridge/manual-followup.txt`
    - `docs/ov5675-power-on-order.md`
    - `reference/patches/ov5675-serial-power-on-v1.patch`
    - `docs/webcam-status.md`
    - `docs/ipu-bridge-ovti5675-candidate.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the clean combined-patch boot is much better than the earlier disturbed
    session:
    - `INT3472:06` binds cleanly
    - `OVTI5675` is still recognized by `ipu-bridge`
    - the dummy-regulator warnings do not appear
  - the remaining failure is now specific:
    - `Failed to enable dvdd: -ETIMEDOUT`
    - `ov5675 i2c-OVTI5675:00: failed to power on: -110`
  - that means the current blocker is no longer:
    - missing board data
    - missing graph endpoint hookup
    - missing regulator lookup
  - the current blocker is now:
    - `ov5675_power_on()` failing while enabling `dvdd`
  - the next targeted local hypothesis is:
    - Linux should try a serial rail-enable order matching recovered Windows
      sequencing:
      - `avdd`
      - `dvdd`
      - `dovdd`
- Decision: stop using `media-ctl` as the main signal for now; until
  `ov5675_power_on()` succeeds there will still be no sensor subdevice to show.

### Record the first `ipu-bridge` success and narrow the remaining question to a clean-boot regulator check

- Plan: preserve the first successful `ipu-bridge` `OVTI5675` result, but
  document carefully that the later regulator failure is not yet a clean
  verdict because the `INT3472` companion was already in a broken state from
  earlier manual reprobe work.
- Commands:
  - reviewed the user-run bridge-test output:
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|firmware graph|firmware node|xvclk|reset|regulator|ipu7'`
    - `readlink -e /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo unbound`
    - `readlink -e /sys/bus/i2c/devices/i2c-INT3472:06/driver || echo int3472-unbound`
  - reviewed live and captured state:
    - `lsmod | rg 'ipu_bridge|ov5675|intel_skl_int3472|tps68470|intel_ipu7'`
    - `runs/2026-03-08/20260308T134757-snapshot-after-ipu-bridge-ovti5675/`
    - earlier context line:
      - `int3472-tps68470 i2c-INT3472:06: INT3472 seems to have no dependents`
  - `apply_patch` adding and updating:
    - `runs/2026-03-08/20260308T134757-snapshot-after-ipu-bridge-ovti5675/manual-followup.txt`
    - `docs/ipu-bridge-ovti5675-candidate.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the `ipu-bridge` follow-up patch clearly worked:
    - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
    - `intel-ipu7 0000:00:05.0: Connected 1 cameras`
    - the old `ov5675 ... no firmware graph endpoint found` line disappeared
  - the failure moved forward again:
    - `ov5675` now reaches regulator lookup
    - then reports `avdd` / `dovdd` / `dvdd` not found and falls back to dummy
      regulators
    - then fails sensor detect with `-5`
  - important nuance:
    - this happened after an earlier manual reprobe had already produced
      `INT3472 seems to have no dependents`
    - by the time of live follow-up, `i2c-INT3472:06` was unbound
    - so this run proves the bridge fix, but does **not** yet give a clean
      fresh-boot verdict on the regulator path
- Decision: the next test should be a fresh boot with both patches already
  installed, then a clean baseline capture before any manual reprobe.

### Record the `ov5675` diagnostic result and draft the `ipu-bridge` follow-up

- Plan: preserve the first diagnostic-patch run result, reduce the remaining
  blocker to the next concrete kernel file, and turn that into the next
  module-only patch candidate.
- Commands:
  - reviewed the user-run diagnostic output:
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|firmware graph|firmware node|xvclk|reset|regulator|ipu7'`
    - `ls -l /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || true`
    - `media-ctl -p -d /dev/media0`
    - `find /dev -maxdepth 1 -name 'v4l-subdev*' | sort`
  - reviewed the new captured runs:
    - `runs/2026-03-08/20260308T133322-snapshot-before-ov5675-diag/`
    - `runs/2026-03-08/20260308T133515-snapshot-after-ov5675-diag/`
    - `runs/2026-03-08/20260308T133658-reprobe-modules-after-ov5675-diag/`
  - reviewed the bridge and sensor code:
    - `drivers/media/pci/intel/ipu-bridge.c`
    - `drivers/media/i2c/ov5675.c`
    - `drivers/platform/x86/intel/int3472/common.c`
  - `apply_patch` adding and updating:
    - `runs/2026-03-08/20260308T133515-snapshot-after-ov5675-diag/manual-followup.txt`
    - `reference/patches/ipu-bridge-ovti5675-v1.patch`
    - `docs/ipu-bridge-ovti5675-candidate.md`
    - `docs/webcam-status.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `WORKLOG.md`
- Result:
  - the diagnostic patch produced the first explicit `ov5675` probe error:
    - `ov5675 i2c-OVTI5675:00: no firmware graph endpoint found`
  - this means the remaining blocker is now more specific than "sensor probe
    still fails":
    - the sensor client exists
    - the `ov5675` driver is probing
    - the failure happens before chip-ID and streaming logic
  - `ipu_bridge` is loaded on the same kernel, but local `ipu-bridge.c` only
    creates software-node graph endpoints for sensors in
    `ipu_supported_sensors[]`
  - `OVTI5675` is absent from that table
  - local `ov5675.c` expects a single link-frequency at `450000000`
  - drafted the next minimal patch candidate in
    `reference/patches/ipu-bridge-ovti5675-v1.patch`
- Decision: shift the next module-only test from `ov5675.c` to `ipu-bridge.c`;
  the leading hypothesis is now missing `OVTI5675` bridge support, not missing
  PMIC board data.
### Draft `ov5675` diagnostic patch and tighten the module-only integration workflow

- Plan: turn the silent `ov5675` early-exit theory into a real patch artifact,
  and document the exact module-only apply/build/install/reload steps against
  the current `linux-mainline` package layout.
- Commands:
  - reviewed the current `ov5675` probe path:
    - `sed -n '1120,1385p' ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `rg -n "return -ENXIO|fwnode_graph_get_next_endpoint|dev_err_probe|chip ID|xvclk|reset" ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
  - verified the installed module layout:
    - `ls /lib/modules/$(uname -r)/kernel/drivers/media/i2c/ov5675.ko.zst`
    - `modinfo -F filename ov5675`
  - `apply_patch` adding and updating:
    - `reference/patches/ov5675-probe-diagnostics-v1.patch`
    - `docs/ov5675-diagnostic-patch.md`
    - `docs/module-iteration.md`
    - `docs/README.md`
    - `README.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `WORKLOG.md`
- Result:
  - confirmed the current `ov5675` driver has two silent early `-ENXIO` exits
    in `ov5675_get_hwcfg()`:
    - no firmware node
    - no firmware graph endpoint
  - drafted `reference/patches/ov5675-probe-diagnostics-v1.patch` to expose
    those failure paths and to log regulator and endpoint-parse errors via
    `dev_err_probe()`
  - documented the exact module-only integration loop in
    `docs/ov5675-diagnostic-patch.md`
  - corrected the earlier install guidance to match the real Arch module
    layout:
    - installed modules are `.ko.zst`
    - the clean replacement path is to overwrite the packaged `.ko.zst`
      filename, then run `depmod`
- Decision: next test should use the new `ov5675` diagnostic patch with a
  module-only rebuild instead of another full kernel compile.
### Record `v1` patched-kernel result and document module-only iteration

- Plan: preserve the first successful boot and validation results from the
  patched `MS-13Q3` board-data kernel, capture the user-run `ov5675` follow-up
  bind attempt, and document a faster module-only iteration path for the next
  patches.
- Commands:
  - reviewed committed and untracked run evidence:
    - `runs/2026-03-08/20260308T065505-snapshot-after-v1-board-data-boot/*`
    - `runs/2026-03-08/20260308T124909-snapshot-after-v1-board-data-boot/*`
  - reviewed the user-provided terminal transcript for:
    - `readlink -f /sys/bus/i2c/devices/i2c-OVTI5675:00/driver || echo unbound`
    - `sudo modprobe -r ov5675`
    - `sudo modprobe ov5675`
    - `echo i2c-OVTI5675:00 | sudo tee /sys/bus/i2c/drivers/ov5675/bind`
    - `journalctl -b -k --no-pager | rg 'ov5675|OVTI5675|tps68470|INT3472|supply|reset|powerdown|clk'`
    - `media-ctl -p -d /dev/media0`
    - `v4l2-ctl --list-devices`
    - `find /dev -maxdepth 1 -name 'v4l-subdev*' | sort`
  - reviewed kernel build layout for faster iteration:
    - `drivers/platform/x86/intel/int3472/Makefile`
    - `drivers/media/i2c/Makefile`
    - `drivers/media/pci/intel/Makefile`
    - `.config` entries for:
      - `CONFIG_INTEL_SKL_INT3472`
      - `CONFIG_VIDEO_OV5675`
      - `CONFIG_IPU_BRIDGE`
      - `CONFIG_GPIO_TPS68470`
      - `CONFIG_REGULATOR_TPS68470`
  - `apply_patch` updating:
    - `WORKLOG.md`
    - `PLAN.md`
    - `state/CONTEXT.md`
    - `README.md`
    - `docs/README.md`
    - `docs/webcam-status.md`
    - `docs/linux-board-data-candidate.md`
    - `docs/module-iteration.md`
    - `runs/2026-03-08/20260308T124909-snapshot-after-v1-board-data-boot/manual-followup.txt`
- Result:
  - the first patched kernel booted successfully as `7.0.0-rc2-1-mainline-dirty`
  - the original blocker is gone:
    - `No board-data found for this model` no longer appears
  - the patched kernel moved the failure forward usefully:
    - `i2c-OVTI5675:00` now exists
    - `intel-ipu7 ... no subdev found in graph` still remains
    - the graph still has no sensor entity
    - there are still no `/dev/v4l-subdev*` nodes
  - the user-run follow-up bind attempt failed with:
    - `tee: /sys/bus/i2c/drivers/ov5675/bind: No such device or address`
  - that means the next blocker is now `ov5675` probe / bind, not the original
    missing `tps68470_board_data` match
  - documented the practical faster loop for next edits:
    - `intel_skl_int3472_tps68470`, `ov5675`, `ipu-bridge`, and the relevant
      TPS68470 helper pieces are all modules in the current test kernel
    - next iterations can usually use module-only rebuild/install instead of a
      full `makepkg`
- Decision: keep the `v1` board-data patch as the correct first-stage fix and
  switch to module-only iteration for the next diagnostic `ov5675` / `ipu-bridge`
  work.

### Preserve the reordered manual sensor-check batch and refresh current `linux-mainline` source status

- Plan: commit the reordered manual sensor-check attempt as evidence, distinguish the dry-run from the real execute run, and re-check the current `linux-mainline` package-cache layout before moving to a patched-kernel test.
- Commands:
  - reviewed:
    - `git status --short`
    - `runs/2026-03-08/20260308T021210-manual-i2c-sensor-check/script.log`
    - `runs/2026-03-08/20260308T021300-manual-i2c-sensor-check-second-manual-check/script.log`
    - `runs/2026-03-08/20260308T021300-manual-i2c-sensor-check-second-manual-check/metadata.env`
  - checked current `linux-mainline` package cache:
    - `git -C /home/lhl/.cache/paru/clone/linux-mainline/linux-mainline describe --tags --always`
    - `git -C /home/lhl/.cache/paru/clone/linux-mainline/linux-mainline rev-parse --short HEAD`
    - `find /home/lhl/.cache/paru/clone/linux-mainline -maxdepth 2 -type d | sort`
    - `git --git-dir=/home/lhl/.cache/paru/clone/linux-mainline/linux-mainline show HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c | rg -n 'MS-13Q3|Micro-Star|Prestige|INT3472:06|driver_data =|DMI_'`
    - `git --git-dir=/home/lhl/.cache/paru/clone/linux-mainline/linux-mainline show HEAD:drivers/platform/x86/intel/int3472/tps68470_board_data.c | tail -n 80`
    - temp check:
      - extracted `tps68470_board_data.c` from the bare cache into a temp tree
      - `git apply --check /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/patches/ms13q3-int3472-tps68470-v1.patch`
  - `apply_patch` updating:
    - `WORKLOG.md`
    - `state/CONTEXT.md`
    - `docs/kernel-tree-status.md`
- Result:
  - `20260308T021210-manual-i2c-sensor-check` is only a dry-run confirmation of the reordered script plan
  - `20260308T021300-manual-i2c-sensor-check-second-manual-check` is the actual second execute run, but it failed on the very first `REVID` read
  - that means the second execute run did **not** exercise the reordered sequence at all; it only preserves evidence that the I2C controller was still wedged from the previous manual PMIC experiment
  - the current `linux-mainline` package cache layout is now:
    - package root: `~/.cache/paru/clone/linux-mainline`
    - bare Git cache: `~/.cache/paru/clone/linux-mainline/linux-mainline`
    - no editable `src/linux-mainline` worktree exists until `makepkg` prepare/build creates it
  - the current cached upstream source is:
    - describe: `v7.0-rc2-467-g4ae12d8bd9a8`
    - commit: `4ae12d8bd9a8`
  - the current cached `tps68470_board_data.c` still only contains Surface Go/2/3 and Dell 7212 entries; it still does **not** contain MSI `MS-13Q3` or `i2c-INT3472:06`
  - the current first-pass patch candidate `reference/patches/ms13q3-int3472-tps68470-v1.patch` still applies cleanly to the current cached `v7.0-rc2` board-data source content
- Decision: preserve this probe batch, but stop using additional manual PMIC pokes as the main path; the next highest-value test is a patched `linux-mainline` build using the current `v7.0-rc2` source worktree.

### Record first executed manual TPS68470 sensor-check run and tighten the sequence

- Plan: review the first live userland PMIC-poke run, preserve the resulting evidence, and adjust the script so the next run tests the sensor immediately after passthrough enable instead of failing on a follow-up PMIC read.
- Commands:
  - reviewed:
    - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/script.log`
    - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/pre-pmic-regs.txt`
    - `runs/2026-03-08/20260308T020606-manual-i2c-sensor-check-first-manual-check/post-reset-regs.txt`
    - `journalctl -k --since '2026-03-08 02:05:30' --until '2026-03-08 02:07:30'`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - `apply_patch` updating:
    - `scripts/i2c-sensor-check.sh`
    - `WORKLOG.md`
- Result:
  - the first executed manual run reached the PMIC cleanly and confirmed the corrected baseline state:
    - `REVID=0x21`
    - `VIOVAL=0x34`
    - `VSIOVAL=0x34`
    - `VACTL=0x00`
    - `VDCTL=0x04`
  - the run stayed healthy through:
    - voltage programming
    - full 19.2 MHz clock programming
    - GPIO1/GPIO2 mode changes
  - the first operation after setting `S_I2C_CTL` to `0x03` failed, and the kernel logged repeated `i2c_designware.1: controller timed out`
  - that means the current script ordering was non-diagnostic:
    - it proved the bus break happened at or immediately after passthrough enable
    - it did **not** prove the sensor failed to answer chip-ID reads
  - the script now makes `S_I2C_CTL` the final PMIC write before direct sensor reads and makes post-passthrough PMIC snapshots / cleanup best-effort instead of fatal
- Decision: keep the first executed run as evidence; use the reordered script for the next manual check if we want one more high-risk sanity test.

### Harden manual TPS68470 sensor-check experiment script

- Plan: keep the manual PMIC poke path available as an explicit experiment, but make it less misleading by matching the kernel clock path more closely, removing non-diagnostic `i2cdetect` scans, and defaulting to dry-run.
- Commands:
  - reviewed:
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/clk/clk-tps68470.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `docs/reprobe-harness.md`
  - `apply_patch` rewriting:
    - `scripts/i2c-sensor-check.sh`
  - validated:
    - `bash -n scripts/i2c-sensor-check.sh`
    - `scripts/i2c-sensor-check.sh` (dry-run only)
- Result:
  - the manual script now programs the full 19.2 MHz TPS68470 clock sequence instead of only toggling `PLLCTL`
  - it explicitly writes `VIOVAL`, `VSIOVAL`, `VAVAL`, and `VDVAL`, so it no longer depends on inherited PMIC state from a previous boot or run
  - it now uses read-modify-write updates for GPIO and regulator enable registers instead of clobbering whole register values
  - it removed `i2cdetect` bus scans and uses direct chip-ID reads only, which makes a negative result less misleading
  - it defaults to dry-run and requires `--execute` for actual writes
  - it logs each run under `runs/YYYY-MM-DD/...`
  - no live hardware execution was performed as part of this edit; only dry-run validation was done
- Decision: keep; this is still a higher-risk experiment than the safe reprobe harness, but it is now a more controlled sanity-check path and a failed result should be easier to interpret.

### Draft first Linux `MS-13Q3` `tps68470_board_data` patch candidate

- Plan: turn the ACPI plus Windows sequencing evidence into a concrete first-pass Linux patch candidate and a test note that is specific enough for the first patched reprobe.
- Commands:
  - reviewed Linux consumer expectations:
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/include/linux/platform_data/tps68470.h`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
  - generated a patch candidate from a modified temp copy of:
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c`
  - wrote:
    - `reference/patches/ms13q3-int3472-tps68470-v1.patch`
    - `docs/linux-board-data-candidate.md`
  - validated:
    - `git apply --check /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/reference/patches/ms13q3-int3472-tps68470-v1.patch`
- Result:
  - drafted the first testable Linux patch candidate for this laptop
  - mapped regulators for `i2c-OVTI5675:00` as:
    - `avdd` via `TPS68470_ANA`
    - `dvdd` via `TPS68470_CORE`
    - `dovdd` via `TPS68470_VSIO`
  - mapped the active PMIC device as `i2c-INT3472:06`
  - used PMIC regular GPIO 1 / GPIO 2 as the initial camera-control candidate because the Windows path reconfigures `GPCTL1A` and `GPCTL2A`
  - recorded the main remaining risk explicitly:
    - upstream `ov5675.c` only consumes `reset`
    - Windows appears to use two PMIC GPIO lines
    - board-data alone may not be sufficient for a full bring-up
- Decision: keep; this is the minimum concrete patch path that can falsify or confirm the current MSI board-data hypothesis quickly.

### Deepen `iactrllogic64.sys` extraction for `VoltageWF` and sensor-power sequencing

- Plan: promote the recovered Windows `VoltageWF` and `CrdG2TiSensor` power-path behavior into first-class repo artifacts so the Linux patch-design step can rely on durable evidence instead of transient terminal analysis.
- Commands:
  - reviewed and extended `scripts/extract-iactrllogic64.sh`
  - inspected targeted disassembly around:
    - `0x140011ae0` through `0x140011ff4`
    - `0x140012c90` through `0x14001357c`
    - `0x1400146a8` through `0x140014b60`
  - correlated those regions against:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-addresses.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-xrefs.txt`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/include/linux/mfd/tps68470.h`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/regulator/tps68470-regulator.c`
    - `/home/lhl/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/gpio/gpio-tps68470.c`
  - `apply_patch` adding:
    - new extractor outputs for `VoltageWF::PowerOn/PowerOff`, `IoActive/IoIdle`, and `CrdG2TiSensor::*`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
- Result:
  - confirmed `Tps68470VoltageWF::PowerOn` is an orchestration path, not a single register write:
    - it stages VA, VD, VSIO, and VCM helper calls and logs steps `0x20` through `0x24`
  - confirmed `Tps68470VoltageWF::PowerOff` tears down VA, VD, and VCM explicitly, while `VSIO` is handled through a separate IO-state path
  - confirmed `Tps68470VoltageWF::IoActive` / `IoIdle` use a refcount around `S_I2C_CTL` `0x43`
  - confirmed `Tps68470VoltageWF::IoActive_GPIO` reconfigures `GPCTL1A` `0x16` and `GPCTL2A` `0x18`
  - narrowed the Linux GPIO hypothesis:
    - this MSI path likely uses PMIC regular GPIO 1 and GPIO 2
    - this does not look like the Surface Go style use of logical outputs `s_enable` / `s_resetn`
- Decision: keep; this is the first durable extraction step that materially constrains the Linux board-data design.

### Complete first ACPI capture with committed DSL and live Linux state

- Plan: finish the first ACPI evidence set so the repo contains the actual disassembly outputs and live ACPI/sysfs snapshot, then fix the capture script so future runs reproduce the same layout without manual cleanup.
- Commands:
  - regenerated DSL from the existing capture in temp:
    - copied `reference/acpi/20260308T004459-unknown-host/tables/*.dat` to `/tmp/ms13q3-acpi-commit/`
    - `iasl -d dsdt.dat`
    - `iasl -d ssdt*.dat`
  - refreshed committed analysis files:
    - regenerated `reference/acpi/20260308T004459-unknown-host/camera-related-hits.txt`
    - generated `reference/acpi/20260308T004459-unknown-host/live-linux-acpi-state.txt`
    - removed accidental duplicate `reference/acpi/20260308T004459-unknown-host/tables/*.dsl`
  - `apply_patch` updating:
    - `scripts/capture-acpi.sh`
    - `reference/acpi/20260308T004459-unknown-host/README.md`
    - `docs/tps68470-reverse-engineering.md`
    - `state/CONTEXT.md`
- Result:
  - committed the first full reviewed ACPI evidence set for this laptop, including `dsdt.dsl`, `ssdt*.dsl`, valid `camera-related-hits.txt`, and `live-linux-acpi-state.txt`
  - confirmed the live Linux snapshot matches the reviewed firmware path:
    - `OVTI5675:00` at `\_SB_.LNK0`
    - `INT3472:06` at `\_SB_.CLP0`
    - inactive alternate `INT3472:00` at `\_SB_.DSC0`
  - confirmed `dsdt.dsl` disassembles cleanly only as a standalone `iasl -d dsdt.dat` pass on this firmware; the combined namespace mode fails with `AE_ALREADY_EXISTS`
  - fixed `scripts/capture-acpi.sh` so future runs:
    - disassemble lowercase `dsdt.dat` / `ssdt*.dat`
    - keep `.dsl` outputs under `dsl/` instead of scattering them under `tables/`
    - capture `live-linux-acpi-state.txt` automatically
- Decision: keep; this turns the ACPI capture into a self-contained, reproducible reference instead of a partially reviewed raw dump.

### Review first ACPI capture and correlate it with live Linux plus Windows artifacts

- Plan: disassemble the captured ACPI tables from a writable temp area, identify the machine's active camera path, map that to the live ACPI/sysfs state, and fix the capture script based on the first-run failure.
- Commands:
  - regenerated DSL from the committed capture in temp:
    - copied `reference/acpi/20260308T004459-unknown-host/tables/*.dat` to `/tmp/ms13q3-acpi-review/`
    - `iasl -e ssdt*.dat -d dsdt.dat`
    - `iasl -d ssdt*.dat`
  - reviewed ACPI structure:
    - `/tmp/ms13q3-acpi-review/ssdt17.dsl`
    - `/tmp/ms13q3-acpi-review/dsdt-disasm.log`
    - `/tmp/ms13q3-acpi-review/ssdt-disasm.log`
  - reviewed live ACPI/sysfs state:
    - `/sys/bus/acpi/devices/OVTI5675:00/*`
    - `/sys/bus/acpi/devices/INT3472:06/*`
    - `/sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/i2c-1/i2c-INT3472:06/*`
  - reviewed Linux-side consumers and PMIC register definitions:
    - `drivers/media/i2c/ov5675.c`
    - `drivers/platform/x86/intel/int3472/tps68470.c`
    - `drivers/platform/x86/intel/int3472/tps68470_board_data.c`
    - `drivers/clk/clk-tps68470.c`
    - `drivers/regulator/tps68470-regulator.c`
    - `include/linux/mfd/tps68470.h`
  - `apply_patch` fixing `scripts/capture-acpi.sh` and updating the canonical note and state files
- Result:
  - confirmed the camera topology lives in `ssdt17.dat` / `MiCaTabl`, which defines six `LNK*` sensor links, six `DSC*` `INT3472` PMIC nodes, and six `CLP*` `INT3472` PMIC nodes backed by an `MNVS` operation region
  - confirmed the live active sensor is `OVTI5675:00` at ACPI path `\_SB_.LNK0` with `status=15`
  - confirmed the live active PMIC companion is `INT3472:06` at ACPI path `\_SB_.CLP0` with `status=15`, and its physical Linux device is `i2c-INT3472:06`
  - confirmed the alternate `DSC0` `INT3472:00` path exists but is inactive on this machine
  - confirmed `CDEP()` in the ACPI table selects `DSC0 + I2C bus` only when `C0TP == 1`, but returns `CLP0` when `C0TP > 1`; this laptop is therefore on the Windows PMIC companion path, not the simpler discrete path
  - confirmed the Windows `StartClock` register sequence maps directly to Linux TPS68470 clock registers:
    - `0x06` `POSTDIV2`
    - `0x07` `BOOSTDIV`
    - `0x08` `BUCKDIV`
    - `0x09` `PLLSWR`
    - `0x0A` `XTALDIV`
    - `0x0B` `PLLDIV`
    - `0x0C` `POSTDIV`
    - `0x0D` `PLLCTL`
    - `0x10` `CLKCFG2`
  - confirmed `ov5675` expects regulators `avdd`, `dovdd`, and `dvdd`, plus a `reset` GPIO and a 19.2 MHz clock
  - confirmed the likely blocker is now narrower:
    - missing MSI-specific `tps68470_board_data` for `i2c-INT3472:06`
    - likely with `OVTI5675:00`-specific regulator consumer mappings and GPIO policy
    - not just a missing DMI string
  - fixed `scripts/capture-acpi.sh` so future runs disassemble lowercase `dsdt.dat` and `ssdt*.dat` files correctly
- Decision: keep; this is the first machine-specific ACPI-to-Linux path confirmation and it narrows the next patch-design work to MSI `TPS68470` board data and PMIC policy.

### Commit first ACPI capture for MSI `MS-13Q3`

- Plan: commit the first real root-collected ACPI capture from this laptop before deeper analysis, and record both the successful raw dump and the script failure that left the DSL pass incomplete.
- Commands:
  - `sudo scripts/capture-acpi.sh`
  - reviewed:
    - `reference/acpi/20260308T004459-unknown-host/metadata.env`
    - `reference/acpi/20260308T004459-unknown-host/dmi.txt`
    - `reference/acpi/20260308T004459-unknown-host/acpidump.txt`
    - `reference/acpi/20260308T004459-unknown-host/acpixtract.log`
    - `reference/acpi/20260308T004459-unknown-host/dsl/ssdt-disasm.log`
- Result:
  - captured the first in-repo raw ACPI dump for this exact machine under `reference/acpi/20260308T004459-unknown-host/`
  - confirmed DMI identity from the same capture:
    - product: `Prestige 13 AI+ Evo A2VMG`
    - board: `MS-13Q3`
    - BIOS: `E13Q3IMS.109`
    - BIOS date: `09/04/2024`
  - confirmed the raw dump contains camera-relevant `INT3472` and `CLDB` strings
  - confirmed binary ACPI tables were extracted successfully under `tables/`
  - confirmed the first `iasl` disassembly attempt failed because `scripts/capture-acpi.sh` expected uppercase `DSDT.dat` and `SSDT*.dat` while this run produced lowercase `dsdt.dat` and `ssdt*.dat`
  - confirmed `camera-related-hits.txt` is empty in this first run because the DSL generation step failed
- Decision: keep; the raw capture is valid and should be preserved now, then analyzed and followed by a script fix in a separate step.

### Add canonical ACPI plus Windows-control-logic reverse-engineering workflow

- Plan: make the ACPI capture and Windows `iactrllogic64.sys` analysis reproducible in-repo, then write one canonical note that preserves the concrete reverse-engineering results.
- Commands:
  - checked current constraints:
    - `which acpidump`
    - `sudo -n true`
    - `ls -l /sys/firmware/acpi/tables`
    - `acpidump -b`
  - added scripts:
    - `scripts/capture-acpi.sh`
    - `scripts/extract-iactrllogic64.sh`
  - generated Windows analysis artifacts:
    - `scripts/extract-iactrllogic64.sh`
  - reviewed generated outputs:
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/debug-directory.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/pe-header-and-imports.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/method-string-addresses.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoron.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-sensoroff.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-start.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-clock-confighclkab.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvactl.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-voltage-wf-setvsioctl-gpio.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-register-write-wrapper.txt`
    - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/disasm-transport-helper.txt`
- Result:
  - added a root-capable ACPI capture helper that stores reproducible evidence under `reference/acpi/`
  - confirmed raw ACPI table capture is still blocked from the current unprivileged session because `/sys/firmware/acpi/tables/*` is root-readable only
  - generated a stable in-repo analysis tree for `iactrllogic64.sys`
  - confirmed the Windows driver contains named `TPS68470` sensor, clock, voltage, GPIO, and flash routines plus `CommonFunc::Cmd_SensorPowerOn` / `Cmd_SensorPowerOff`
  - confirmed the binary build provenance:
    - PDB path `W:\repo\w\camerasw\Source\Camera\Platform\LNL\x64\Release\iactrllogic64.pdb`
    - PDB GUID `804BA0D7-738B-4CC9-8027-7AF3103C24B5`
  - recovered a concrete `Tps68470Clock::StartClock` write sequence using registers `0x0a`, `0x08`, `0x07`, `0x0b`, `0x0c`, `0x06`, `0x10`, `0x09`, and `0x0d`
  - recovered a `ConfigHCLKAB` helper that reads and masks register `0x0d` before writing it back
  - recovered a common register-write helper at `0x140010be0` that retries through `0x1400110f4`
  - recovered `VoltageWF` examples that read/modify/write at least registers `0x47` and `0x43`
- Decision: keep; this is now the canonical reverse-engineering base for the next ACPI capture and Linux patch-design pass.

### Commit first baseline snapshot and reprobe run set

- Plan: record the first real `runs/` output from the safe harness so the baseline failure state and exact reprobe behavior are preserved in git.
- Commands:
  - `scripts/webcam-run.sh snapshot --label baseline --note "before first reprobe"`
  - `sudo scripts/webcam-run.sh reprobe-modules --label first-reprobe --note "baseline reprobe after boot"`
  - reviewed:
    - `runs/2026-03-08/20260308T001800-snapshot-baseline/summary.env`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/summary.env`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/action.log`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/journal-since-run-start.txt`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/media-ctl-media0.txt`
    - `runs/2026-03-08/20260308T001807-reprobe-modules-first-reprobe/post/v4l2-list-devices.txt`
- Result:
  - captured the first baseline snapshot and first real reprobe run under `runs/2026-03-08/`
  - confirmed the reprobe sequence completed successfully with no module-load failures
  - confirmed the same blocker reproduces cleanly after reprobe:
    - `TPS68470 REVID: 0x21`
    - `error -ENODEV: No board-data found for this model`
    - `intel-ipu7 ... no subdev found in graph`
  - confirmed `media-ctl` still shows an IPU-only topology with no sensor subdevice attached after reprobe
- Decision: keep; this is the baseline evidence batch for future diffs against patched kernels or new sequencing hypotheses.

### Add related MSI Summit 13 low-level Linux repo as a future comparison reference

- Plan: capture a nearby MSI Lunar Lake Linux-support repo that is not webcam-specific but may still hold useful board-level patterns for later comparison.
- Commands:
  - opened `https://github.com/greymouser/Summit-13-AI-Evo-A2VM`
  - `apply_patch` adding `reference/greymouser-summit-13-ai-evo-a2vm.md`
  - `apply_patch` updating `reference/README.md`, `README.md`, and `state/CONTEXT.md`
- Result:
  - added a reference note for the related `MSI Summit 13 AI+ Evo A2VMTG` / `MS-13P5` repo
  - captured that its visible Linux focus is currently IIO sensor support and audio mute / speaker LED control
  - recorded it as a future low-level comparison source rather than a direct webcam bring-up reference
- Decision: keep; related MSI platform work may expose useful DMI, ACPI, firmware, or vendor-integration patterns later.

### Build safe snapshot/reprobe harness for repeatable Linux testing

- Plan: add a low-risk harness that records every meaningful reprobe attempt with enough evidence to analyze failures later, without doing raw PMIC or I2C register writes.
- Commands:
  - inspected current repo docs and plan files
  - inspected current sysfs driver hooks for `int3472-tps68470` and `ov5675`
  - inspected current module state and kernel logs
  - `apply_patch` adding `scripts/webcam-run.sh`
  - `apply_patch` adding `docs/reprobe-harness.md`
  - `apply_patch` adding `runs/README.md`
  - `apply_patch` updating `README.md`, `docs/README.md`, `PLAN.md`, and `state/CONTEXT.md`
  - `bash -n scripts/webcam-run.sh`
  - `scripts/webcam-run.sh snapshot --runs-root /tmp/...`
  - `scripts/webcam-run.sh reprobe-modules --dry-run --runs-root /tmp/...`
- Result:
  - added `scripts/webcam-run.sh` with two actions: `snapshot` and `reprobe-modules`
  - each run now captures pre/post state, exact step order, filtered kernel logs, media/V4L2 output, and relevant sysfs state under `runs/`
  - the harness is explicitly limited to snapshot and module reload activity; it does not do `i2cset`, raw `i2ctransfer` writes, or address-scanning `i2cdetect`
  - documented the run layout and usage in `docs/reprobe-harness.md`
  - smoke-tested `snapshot` and `reprobe-modules --dry-run` successfully using temporary run roots under `/tmp`
- Decision: keep; this gives us a repeatable low-risk testing baseline before any deeper reverse engineering or kernel patching.

## 2026-03-07

### Snapshot Torvalds `HEAD` `int3472` subtree for upstream comparison

- Plan: capture the current upstream `drivers/platform/x86/intel/int3472/` tree from Torvalds Linux `HEAD` and compare it against the local `v6.19` snapshot.
- Commands:
  - opened `https://web.git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/platform/x86/intel/int3472`
  - opened `https://github.com/torvalds/linux/tree/master/drivers/platform/x86/intel/int3472`
  - `git ls-remote https://github.com/torvalds/linux.git HEAD`
  - sparse-cloned Torvalds Linux `HEAD` and copied `drivers/platform/x86/intel/int3472/`
  - `git diff --no-index --stat -- reference/linux-mainline-v6.19/drivers/platform/x86/intel/int3472 reference/linux-torvalds-head/drivers/platform/x86/intel/int3472`
- Result:
  - captured Torvalds `HEAD` at `4ae12d8bd9a830799db335ee661d6cbc6597f838`
  - added an in-repo upstream snapshot under `reference/linux-torvalds-head/`
  - confirmed that only `discrete.c` and `tps68470.c` differ from the local `v6.19` snapshot
  - did not observe a new MSI board-data entry in `tps68470_board_data.c`
- Decision: keep; this narrows the current upstream delta and confirms that plain upstream drift has not already fixed the MSI board-data gap.

### Vendor Windows package trees, TPS68470 PDF, and local `int3472` kernel snapshot

- Plan: move the active binary artifacts and local source snapshot into `reference/` so future reverse engineering does not depend on `/tmp` or the paru cache path.
- Commands:
  - `git lfs track 'reference/windows-driver-packages/**/*.cab' 'reference/windows-driver-packages/**/*.sys' 'reference/windows-driver-packages/**/*.dll' 'reference/windows-driver-packages/**/*.bin' 'reference/windows-driver-packages/**/*.aiqb' 'reference/windows-driver-packages/**/*.cpf' 'reference/windows-driver-packages/**/*.cat' 'reference/windows-driver-packages/**/*.bmp'`
  - copied `/tmp/int3472-winpkg/intel-control-logic-71.26100.23.20279.cab`
  - copied `/tmp/int3472-winpkg/extracted`
  - copied `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
  - copied `/tmp/ovti5675-msi/extracted2`
  - `git lfs track 'reference/**/*.pdf'`
  - copied `~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/`
- Result:
  - vendored the two Windows package trees into `reference/windows-driver-packages/`
  - enabled Git LFS for the binary-heavy Windows-package payloads and for PDFs under `reference/`
  - added a local reference copy of `drivers/platform/x86/intel/int3472/` from the inspected `v6.19` tree
  - added `reference/tps68470.pdf` to the repo as a local PMIC datasheet reference
- Decision: keep; this lowers future setup cost and gives us stable in-repo inputs for both Windows-package and kernel-source analysis.

### Document exact MSI `OV5675` Catalog package and local download path

- Plan: record the exact Microsoft Update Catalog entry, direct CAB URL, and local download paths for the MSI-submitted `OV5675` package so we can reliably reopen it later.
- Commands:
  - opened `https://www.catalog.update.microsoft.com/Search.aspx?q=ACPI%5COVTI5675`
  - opened `https://www.catalog.update.microsoft.com/ScopedViewInline.aspx?updateid=8fd6696d-67b8-4bc7-a477-6d8800725426`
  - downloaded `https://catalog.s.download.windowsupdate.com/c/msdownload/update/driver/drvs/2026/02/8a77f110-818a-4dee-b65b-291e97512d0f_0e7b66ca05a48e8131f5ef36e983f419b4ebef52.cab`
  - extracted `/tmp/ovti5675-msi/ovti5675-msi-70.26100.19939.1.cab`
- Result:
  - confirmed the exact MSI package entry is `Intel Corporation Driver Update (70.26100.19939.1)`
  - confirmed company field `MICRO-STAR INTERNATIONAL CO., LTD`
  - confirmed supported hardware ID `ACPI\\OVTI5675`
  - documented the direct CAB URL plus local paths in `reference/msi-ov5675-microsoft-update-catalog-70.26100.19939.1.md`
- Decision: keep; this makes the Windows package reference stable and removes the need to rediscover the exact Catalog entry.

### Tighten AGENTS progress-summary expectations

- Plan: make user-facing updates state the concrete result or blocker, so status stays useful as the repo and session history grow.
- Commands:
  - `nl -ba AGENTS.md | sed -n '1,220p'`
  - `apply_patch` updating `AGENTS.md`
- Result:
  - added a `Communication rules` section to `AGENTS.md`
  - future progress updates are now required to state what was actually done and what was actually learned
  - if there is no substantive result yet, the update must say that explicitly instead of only describing activity
- Decision: keep; this should make multi-step research sessions easier to follow and audit.

### Document local `linux-mainline` source location and board-data status

- Plan: record the exact local kernel-source path and the concrete `v6.19` finding so it is easy to reopen the same files later.
- Commands:
  - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline rev-parse --short HEAD`
  - `git -C ~/.cache/paru/clone/linux-mainline/src/linux-mainline describe --tags --always`
  - `nl -ba ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470_board_data.c | sed -n '240,336p'`
  - `nl -ba ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/platform/x86/intel/int3472/tps68470.c | sed -n '176,184p'`
  - `nl -ba ~/.cache/paru/clone/linux-mainline/src/linux-mainline/drivers/media/i2c/ov5675.c | sed -n '1355,1379p'`
- Result:
  - documented the reusable local source location as `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
  - confirmed that local source is `v6.19` at `05f7e89ab973`
  - confirmed `tps68470_board_data.c` only contains Surface Go variants and Dell Latitude 7212, with no MSI `MS-13Q3` / `Prestige 13 AI+ Evo A2VMG`
  - confirmed the `ov5675` ACPI match for `OVTI5675` exists in the same tree
- Decision: keep; this closes the first local-kernel-tree inspection step and gives us a stable place to resume from later.

### Add shared `CLAUDE.md` symlink

- Plan: add a repo-local `CLAUDE.md` symlink pointing to `AGENTS.md` so Codex and Claude Code read the same instructions.
- Commands:
  - `ln -s AGENTS.md CLAUDE.md`
  - `ls -l AGENTS.md CLAUDE.md`
- Result:
  - created relative symlink `CLAUDE.md -> AGENTS.md`
  - repo now has one shared instruction source for both tools
- Decision: keep; this avoids instruction drift between parallel agent environments.

### AGENTS commit-discipline update

- Plan: tighten `AGENTS.md` so multi-agent and mixed human/agent work in one worktree stays safe.
- Commands:
  - `nl -ba AGENTS.md | sed -n '1,220p'`
  - `apply_patch` updating `AGENTS.md`
- Result:
  - commit policy now explicitly requires frequent commits on logical task completion
  - commit units are defined as coherent evidence/doc/probe/patch bundles
  - staged-diff review commands are now part of the written repo policy
- Decision: keep; this should reduce cross-agent drift and make future hardware bring-up sessions easier to isolate and review.

### Repo bootstrap and initial webcam evidence capture

- Added repo-level process docs:
  - `README.md`
  - `AGENTS.md`
  - `PLAN.md`
  - `WORKLOG.md`
  - `state/CONTEXT.md`
  - `docs/README.md`
  - `reference/README.md`
- Added initial upstream reference notes:
  - `reference/intel-ipu7-drivers-issue-17.md`
  - `reference/jeremy-grosser-prestige13-notes.md`
- Added current technical assessment:
  - `docs/webcam-status.md`

### Local machine evidence gathered

- Commands:
  - `cat /sys/class/dmi/id/product_name`
  - `cat /sys/class/dmi/id/product_version`
  - `uname -a`
  - `lspci -nnk | rg -A3 -B2 -i 'ipu|image|camera|multimedia'`
  - `lsmod | rg 'ipu|ivsc|v4l2|uvc|sensor|ov'`
  - `journalctl -k -b --no-pager | rg -i 'ipu|ivsc|ov5675|tps68470|camera|v4l2|cio2'`

- Confirmed machine identity:
  - model `Prestige 13 AI+ Evo A2VMG`
  - revision `REV:1.0`
- Confirmed current kernel:
  - `6.18.9-arch1-2`
- Confirmed camera/IPU-related device and driver state:
  - Lunar Lake IPU at PCI ID `8086:645d`
  - kernel driver `intel-ipu7`
  - modules loaded: `intel_ipu7`, `intel_ipu7_isys`, `ov5675`
  - device nodes present: `/dev/media0` and `/dev/video*`
- Captured the strongest current boot-log evidence:
  - `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`
  - `int3472-tps68470 i2c-INT3472:06: error -ENODEV: No board-data found for this model`
  - `intel-ipu7 0000:00:05.0: no subdev found in graph`

### Assessment

- The webcam is still not usable end to end.
- The current evidence points more strongly at missing MSI-specific `INT3472` / `TPS68470` board data or power sequencing than at a missing core IPU7 driver.
- `OVTI5675:00` and the loaded `ov5675` module make the sensor identity much less mysterious than it was in late 2024.

### Notes

- After the initial scaffold pass, the `claudecycles-revisited` repo was reviewed as an additional process reference.
- The most useful convention imported from it was a small restart capsule in `state/CONTEXT.md` plus stricter command/evidence logging discipline in `WORKLOG.md`.

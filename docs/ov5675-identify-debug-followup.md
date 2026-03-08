# `ov5675` Identify Debug Follow-Up

Updated: 2026-03-09

This note captures the next module-only debug branch after the first clean boot
with `ov5675-powerdown-followup-v1.patch`.

## Current Assessment

The current Linux path now matches the Windows bring-up only at a high level:

- correct sensor path: `OVTI5675:00`
- working `ipu-bridge` hookup
- working `INT3472:06` board-data match
- staged rail-enable order matching the recovered Windows `VA -> VD -> VSIO`
- two PMIC GPIOs exposed to Linux as `reset` and `powerdown`

But the first clean boot after adding `powerdown` handling did not move the
failure forward:

- `ov5675 i2c-OVTI5675:00: failed to find sensor: -5`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -5`

So we still do not fully match the board-specific Windows sequence.

## Why The Current Linux Signal Is Too Weak

Two current blind spots make the remaining gap harder to diagnose than it
should be:

1. `ov5675_read_reg()` collapses all failed I2C transfers to `-EIO`.
2. `ov5675_identify_module()` does only one chip-ID read attempt with the
   current built-in settle gap.

That means the present Linux failure:

- `failed to find sensor: -5`

does not tell us whether the real remaining problem is:

- transport timeout vs other I2C error
- chip ID mismatch vs no reply
- too-short post-power-on timing
- a GPIO semantic mismatch that still leaves the sensor asleep

## Why Windows Still Looks Richer Than Linux

Recovered Windows `SensorPowerOn` evidence still includes steps we have not
fully matched:

- `IoActive_IO`
- a conditional helper at `0x140013868`
- a conditional helper at `0x14001357c`
- `IoActive_GPIO`

That does not automatically mean Linux is missing a large subsystem, but it
does mean our current model is still simplified relative to the Windows path.

## Patch Candidate

Patch file:

- `reference/patches/ov5675-identify-debug-v1.patch`

Patch goals:

- preserve real negative I2C error codes from `i2c_transfer()` and
  `i2c_master_send()`
- add per-attempt chip-ID logging in `ov5675_identify_module()`
- add a tunable extra post-power-on delay
- add tunable chip-ID retry count and retry delay

This is intentionally a debug patch, not a final support patch.

## Why This Is The Best Next Iteration

It keeps the next experiment module-local:

- only `drivers/media/i2c/ov5675.c`
- only rebuild `ov5675.ko`

It also makes the next result much more informative than another bare `-5`.

## Reload Helper

Test helper:

- `scripts/03-ov5675-identify-debug-check.sh`

It reloads `ov5675` with explicit module parameters, captures a normal run via
`scripts/webcam-run.sh`, and writes a focused summary with the key identify
lines.

## Suggested First Runs

Baseline diagnostic reload:

```bash
sudo scripts/03-ov5675-identify-debug-check.sh \
  --label identify-debug-v1 \
  --identify-retries 5 \
  --identify-retry-delay-us 2000 \
  --extra-delay-us 0
```

Delay-biased follow-up:

```bash
sudo scripts/03-ov5675-identify-debug-check.sh \
  --label identify-debug-v1-delay5ms \
  --identify-retries 8 \
  --identify-retry-delay-us 2000 \
  --extra-delay-us 5000
```

## First Result

The first reload-only run after installing the debug build did not reach the
new identify logging:

- run directory:
  - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/`
- focused summary:
  - `runs/2026-03-09/20260309T004918-snapshot-identify-debug-v1/focused-summary.txt`
- high-value kernel lines since reload:
  - `ov5675 i2c-OVTI5675:00: setup of GPIO reset failed: -110`
  - `ov5675 i2c-OVTI5675:00: failed to get reset-gpios: -110`
  - `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

That means the reload-only path is still being contaminated by the earlier
boot-time failure. We still do not have chip-ID attempt logs from this debug
branch.

## Revised Next Test

The next trustworthy use of this debug branch is on first load at clean boot,
not on an in-session reload after `ov5675` has already failed once.

Recommended approach:

1. put the debug module parameters into a temporary `modprobe.d` override so
   they apply when `ov5675` autoloads
2. reboot
3. capture a clean-boot checkpoint with `scripts/01-clean-boot-check.sh`

Suggested temporary `modprobe.d` line:

```conf
options ov5675 identify_retry_count=5 identify_retry_delay_us=2000 extra_post_power_on_delay_us=0
```

If that still fails before identify logging appears, the next strong
conclusion is that the sensor path is wedging before `ov5675_identify_module()`
ever runs, which would push the next patch space back toward GPIO semantics or
board-data sequencing rather than sensor-identify timing.

## Success Criteria

Minimum success:

- the kernel log shows a more precise negative signal than plain `-5`

Better success:

- one of the retry attempts succeeds and identifies the sensor
- `/dev/v4l-subdev*` appears
- the media graph gains a sensor entity

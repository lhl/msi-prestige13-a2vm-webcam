# Webcam Bring-Up Plan

Updated: 2026-03-12

This is the active plan after the first successful raw Bayer capture on the
`exp18` kernel branch with explicit `media-ctl` pipeline setup.

## Goal

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG,
or reduce the remaining blocker to a specific upstream patch or vendor-only gap
with strong evidence.

## Current Assessment

- IPU7 core support is present enough to enumerate the Lunar Lake IPU and load
  firmware.
- `OVTI5675:00` is the correct sensor path.
- the current `tested` patch stack is still valid:
  - `ms13q3-int3472-tps68470-v1.patch`
  - `ipu-bridge-ovti5675-v1.patch`
  - `ov5675-serial-power-on-v1.patch`
- what that stack already fixed:
  - the old `No board-data found for this model` failure is gone
  - `ipu-bridge` now finds `OVTI5675:00`
  - the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
- the current best local branch is now `exp18`:
  - standard regulator-side `VSIO` enable read back cleanly as `0x03`
  - the old timeout storm did not return
  - the media graph gained `ov5675 10-0036`
  - `/dev/v4l-subdev0` now exists
- the remaining blocker is no longer first sensor bind:
  - the first raw `/dev/video0` stream now fails at `VIDIOC_STREAMON` with
    `Link has been severed`
  - the raw output file stays at `0` bytes
  - a later no-reboot sweep forced `/dev/video0` through `/dev/video7` to
    `4096x3072 BA10`
  - all eight nodes accepted `VIDIOC_S_FMT`
  - all eight still failed `VIDIOC_STREAMON` with `Link has been severed`
  - the post-boot PMIC dump path still returns `ERROR` for every register
- completed negative branches:
  - `GPIO1` / `GPIO2` role swap
  - both one-line polarity variants
  - staged `ov5675` GPIO release `sequence=1`
  - staged `ov5675` GPIO release `sequence=2`
  - staged `ov5675` GPIO release control `sequence=0`
  - `exp3` `VD = 1050 mV`
  - `exp5` `WF` GPIO mode follow-up
  - `exp6` `UF` / `gpio.4` last resort
- completed high-signal PMIC findings:
  - `exp1` proved the clock path is real, not a dummy fallback
  - `exp2` reached the staged `S_I2C_CTL` path, but readback stayed `0x00`
    and unwind hit `VSIO: failed to disable: -ETIMEDOUT`
  - `exp4` proved a `WF::Initialize`-style value-programming hook executed,
    but that alone still did not wake the sensor
  - `exp7` isolated the first bad PMIC operation to `VSIO` enable on
    `S_I2C_CTL` `0x43`
  - in `exp7`, `regmap_update_bits()` on `0x43` returned `0`, but the
    immediate readback already failed with `-110`
  - after that point, `i2c_designware.1` entered a timeout storm and later
    PMIC accesses also failed with `-110`
  - `exp8` confirmed the same failure point with a narrower trace:
    - `ANA` and `CORE` still enable cleanly
    - the first bad transition is still the `VSIO` write to `0x43`
    - the boot delay persists even without the broader `exp7` snapshots
  - `exp9` split the `0x43` path and answered the main question:
    - IO-side `BIT(1)` reads back cleanly as `0x02`
    - the wedge begins only after the later GPIO-side `BIT(0)` update
    - the run now fails earlier at `failed to power on: -110`
  - `exp10` kept only `BIT(1)` in the regulator path and changed the outcome:
    - no `i2c_designware` timeout storm
    - `ANA`, `CORE`, and `VSIO BIT(1)` all read back cleanly
    - the sensor gets back to chip-ID reads, but they now fail with `-121`
- `exp11` tested one later GPIO-phase `BIT(0)` hook and came back negative:
  - chip-ID behavior stayed at `-121`
  - the late `BIT(0)` write on `sensor-gpio.1` immediately wedged PMIC
    readback again
  - the old timeout storm returned
- `exp12` came back negative as a direct fix, but it added one useful answer:
  - the Antti-inspired daisy-chain setup lands on `GPIO1` / `GPIO2`
  - the current `MS-13Q3` sensor lookup then immediately re-drives both lines
    back to output mode
  - the sensor failure shape still ends at `-121`
- `exp13` came back positive for wiring isolation, but negative as a direct
  fix:
  - once Linux stops exporting `GPIO1` / `GPIO2` to `OVTI5675:00`, it leaves
    them in daisy-chain input mode for the observed probe window
  - the one-shot reclaim guard did not fire
  - the sensor failure shape still ends at `-121`
- `exp14` came back positive for remote-line activation, but negative as a
  direct fix:
  - `GPIO9` is now an observed Linux-visible remote control line
  - `GPIO1` / `GPIO2` remained isolated in daisy-chain input mode
  - `GPIO9` reached observed `SGPO = 0x04` during probe
  - the sensor failure shape still ends at `-121`
- `exp15` came back positive for remote-line activation, but negative as a
  direct fix:
  - `GPIO7` is now an observed Linux-visible remote control line
  - `GPIO1` / `GPIO2` remained isolated in daisy-chain input mode
  - `GPIO7` reached observed `SGPO = 0x01` during probe
  - the sensor failure shape still ends at `-121`
- `exp16` came back positive for combined remote-line activation, but negative
  as a direct fix:
  - `GPIO1` / `GPIO2` remained isolated in daisy-chain input mode
  - `GPIO7` and `GPIO9` were both actively driven during the identify window
  - observed combined `SGPO` reached `0x05`
  - the sensor failure shape still ends at `-121`
- `exp17` came back positive for a safe later `BIT(0)` assertion, but negative
  as a direct fix:
  - `GPIO1` / `GPIO2` remained isolated in daisy-chain input mode
  - `GPIO7` and `GPIO9` were still active on the clean remote-line branch
  - the late PMIC write on `sensor-gpio.9` read back cleanly:
    - `before=0x02`
    - `after=0x03`
  - the old timeout storm did not return
  - the sensor failure shape still ends at `-121`
- the current `MS-13Q3` `GPIO1` / `GPIO2` board model is still only a
  candidate, not a validated wiring map:
  - the original board-data patch introduced it as a first-pass guess
  - the later label-swap and polarity tests were lower-signal than they first
    looked because current `ov5675` drives both logical descriptors together
- Antti Laakso's working Prestige 14 patch on the same `OV5675` / `TPS68470` /
  Lunar Lake generation is now the strongest external wiring prior:
  - `GPIO1` / `GPIO2` reserved for daisy-chain
  - remote sensor-control lines moved elsewhere
- current leading interpretation:
  - the remaining gap is now after sensor bind, not basic platform support
  - the early regulator-phase `BIT(0)` write was wrong
  - the old direct-use `GPIO1` / `GPIO2` Linux board model was wrong as a
    clean Antti-style branch
  - the current-driver two-line `GPIO9` / `GPIO7` approximation is active,
    but still insufficient
  - the late clean-branch `BIT(0)` re-test is safe, but still insufficient
- `exp18` proved standard `VSIO` is safe once the clean daisy-chain branch
  is in place
- `exp19` proved the first userspace stream fails later at `STREAMON`, not at
  sensor bind
- **the `STREAMON` severed-link failure was caused by missing userspace
  `media-ctl` pipeline setup** -- once the CSI2-to-capture link is enabled and
  pad formats aligned, the sensor delivers real frames

## Workstreams

### 1. Capture and userspace validation

- [x] Stage and run `exp19` on top of the positive `exp18` patch.
- [x] Determine whether raw `v4l2-ctl` streaming on `/dev/video0` succeeds,
  times out, or fails with a userspace-visible pipeline error.
- [x] Determine whether the default `/dev/video0` capture-node format mismatch
  is the main cause of the `VIDIOC_STREAMON` failure.
- [x] Determine whether the `VIDIOC_STREAMON` `Link has been severed` failure
  needs explicit media-pad programming or reflects a deeper capture-path gap.
  - **Answer: explicit `media-ctl` link enable + pad format setup is
    sufficient. Raw Bayer capture now works.**
- [ ] Investigate the `csi2-0 error: Received packet is too long` warnings.
- [ ] Test with higher-level capture tools (`libcamera`, `cheese`, `mpv`).
- [ ] Consider automated pipeline setup (udev rule, libcamera handler, etc.).

### 2. Post-boot PMIC visibility

- [ ] Determine why `scripts/pmic-reg-dump.sh` still returns `ERROR` for every
  register after boot even though the kernel can identify the PMIC.
- [ ] Decide whether the fix is:
  - corrected userspace access path
  - different bus / timing assumptions
  - or a kernel-side debug dump instead of `i2cget`

### 3. Windows config-path extraction

- [ ] Recover more of the code above `WF::SetConf` so the source of the
  five-value tuple is clearer.
- [ ] Recover the runtime conditions that choose the `WF` versus `UF` path on
  this laptop.
- [ ] Determine whether a board-specific config blob or policy object exists in
  the Windows driver path that Linux does not model yet.

### 4. Antti-model branch design

- [x] Stage a separate Antti-inspired daisy-chain cross-check as `exp12`
  without replacing `exp10` as the verified baseline.
- [x] Stage `exp13`: keep `exp10`, enable daisy-chain, and remove
  `OVTI5675:00` use of `GPIO1` / `GPIO2`.
- [x] Stage `exp14`: carry `exp13` forward and test `GPIO9` as the first
  remote control-line candidate.
- [x] Stage `exp15`: carry `exp13` forward and test `GPIO7` as the alternate
  remote control-line candidate.
- [x] Stage `exp16`: carry the clean daisy-chain branch forward and test the
  best two-line `GPIO7` / `GPIO9` approximation.
- [x] Make `exp13` self-diagnosing.
  - add a one-shot `dump_stack()` for any daisy-chain-enabled attempt to drive
    `GPIO1` or `GPIO2` as outputs
- [x] Stage `exp17`: re-test `S_I2C_CTL BIT(0)` only on top of a clean
  daisy-chain-isolated branch.
- [x] Stage `exp18`: restore standard `VSIO` enable on top of the clean
  daisy-chain-isolated branch without reintroducing the local late-`BIT(0)`
  hook.

## Near-Term Priority

1. Use `exp18` as the current kernel branch.
2. Use `scripts/06-media-pipeline-setup.sh` for repeatable capture validation.
3. Investigate the `csi2-0 error: Received packet is too long` warnings.
4. Test with higher-level capture tools (`libcamera`, `cheese`, `mpv`).
5. Clean up the patch stack for upstream submission:
   - remove experiment instrumentation logging
   - separate minimal board-data from diagnostic scaffolding
6. Fix or replace the post-boot PMIC dump path.
7. Keep the broader Windows config-path questions open for upstreamability
   context, but they are no longer blocking basic bring-up.

## Open Questions

- Why does `csi2-0 error: Received packet is too long` appear during capture?
  Is it a CSI2 blanking/format configuration detail or something more?
- Why does userspace PMIC register dumping fail completely after boot when the
  kernel can still log `TPS68470 REVID: 0x21`?
- What is the minimum clean patch set needed for upstream submission?
- Will `libcamera` or other higher-level tools work with this pipeline, or do
  they need an IPU7-specific pipeline handler?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- a full March 9 status report under `docs/`
- reference-backed Windows PMIC notes under `reference/windows-driver-analysis/`
- current support summary under `docs/webcam-status.md`
- recorded `exp13` / `exp14` / `exp15` / `exp16` / `exp17` / `exp18` run
  evidence plus the staged `exp19` capture-validation wrappers

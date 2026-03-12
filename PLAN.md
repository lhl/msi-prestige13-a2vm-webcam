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
  - raw Bayer capture from `/dev/video0` now works after explicit userspace
    `media-ctl` setup
  - fresh-boot `06` reruns proved the working `2592x1944` + enabled-link
    state is script-established, not inherited
  - normal auto-negotiated client use still fails:
    - `ffmpeg` / `mpv`: `VIDIOC_STREAMON` `Broken pipe`
    - GStreamer `v4l2src`: allocation / `not-negotiated`
    - direct advertised `YUYV`: still fails
  - an explicit framework-level bridge does work:
    - GStreamer `video/x-bayer,format=grbg10le`: success
    - `bayer2rgb` + `videoconvert`: success
    - JPEG export: success
  - the next app-facing routes are now explicit:
    - `libcamera`
    - `v4l2loopback`
  - current local `09` result is now split:
    - `libcamera` tools still missing
    - `v4l2loopback` bridge is consumer-facing through `/dev/video42` once
      the module/device is present
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
- [x] Re-run `scripts/06-media-pipeline-setup.sh` immediately after a fresh
  boot to establish the true pre/post media-graph delta.
  - **Answer: the boot default is `Intel IPU7 CSI2 0` at `4096x3072` with
    `CSI2:1 -> Capture 0` disabled; steps 2-5 create the working
    `2592x1944` + `[ENABLED]` state.**
- [x] Stage and run a repeatable normal-usage client check on top of the
  known-good manual pipeline setup.
  - **Answer: `scripts/07-normal-usage-check.sh` now exists and the first live
    run is recorded under
    `runs/2026-03-12/20260312T021942-snapshot-07-normal-usage-check/`.**
- [ ] Investigate the `csi2-0 error: Received packet is too long` warnings.
  - current hard clue: `bytesused = 10,077,696`,
    `Size Image = 10,082,880`, `Bytes per Line = 5,184`
  - the `5,184`-byte delta is exactly one extra scanline in the capture
    buffer
- [x] Determine whether currently installed higher-level headless clients can
  stream after the known-good manual pipeline setup.
  - **Answer: no.**
  - `ffmpeg`: `ioctl(VIDIOC_STREAMON): Broken pipe`
  - `mpv`: same `Broken pipe` path through FFmpeg's V4L2 demuxer
  - GStreamer `v4l2src`: buffer-pool activation failed, then
    `reason not-negotiated (-4)`
- [x] Determine whether any explicit userspace bridge works even though normal
  auto-negotiated clients still fail.
  - **Answer: yes.**
  - `scripts/08-userspace-bridge-check.sh` recorded the first positive
    framework-level bridge under
    `runs/2026-03-12/20260312T032317-snapshot-08-userspace-bridge-check/`
  - direct `YUYV` still fails:
    - `v4l2-ctl`: `VIDIOC_STREAMON returned -1 (Broken pipe)`
    - `ffmpeg -input_format yuyv422`: `Broken pipe`
    - GStreamer explicit `video/x-raw,format=YUY2`: `not-negotiated`
  - explicit GStreamer Bayer handling works:
    - `video/x-bayer,format=grbg10le`: success
    - `bayer2rgb` + `videoconvert`: success
    - `jpegenc`: emitted a normal `2592x1944` JPEG artifact
- [x] Stage and run one repeatable checkpoint for the two next integration
  routes: `libcamera` and `v4l2loopback`.
  - **Answer: yes.**
  - `scripts/09-libcamera-loopback-check.sh` now exists and the first live run
    is recorded under
    `runs/2026-03-12/20260312T033726-snapshot-09-libcamera-loopback-check/`
  - latest positive rerun is recorded under
    `runs/2026-03-12/20260312T040735-snapshot-09-libcamera-loopback-check/`
  - current local result is split:
    - `cam`, `libcamera-hello`, `libcamera-still`, and `libcamera-vid` are
      still missing
    - the `v4l2loopback` bridge now feeds a normal consumer-facing
      `/dev/video42` node
- [ ] Test remaining higher-level tools that were not covered headlessly.
  - install and try `libcamera-*` / `cam`
  - manually exercise `cheese` in a GUI session
- [x] Determine whether the working explicit GStreamer bridge can be exposed as
  a more normal webcam path.
  - **Answer: yes, through `v4l2loopback`.**
  - `scripts/09-libcamera-loopback-check.sh --loopback-device /dev/video42`
    proved a consumer-facing node with both `ffmpeg` and GStreamer consumers.
- [ ] Package the working bridge as a more normal webcam path.
  - likely candidates: a small repo-local wrapper, a user service, or a manual
    launch recipe for `/dev/video42`
- [ ] Determine why the advertised direct standard-pixel formats (`YUYV`,
  `UYVY`, `BGR3`, etc.) are not actually streamable from the configured state.
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
2. Use fresh-boot `scripts/06-media-pipeline-setup.sh` reruns as the capture
   truth source for userspace-path changes.
3. Use `scripts/07-normal-usage-check.sh` as the auto-negotiated higher-level
   client compatibility truth source.
4. Use `scripts/08-userspace-bridge-check.sh` as the explicit userspace-bridge
   truth source.
5. Use `scripts/09-libcamera-loopback-check.sh` as the next-step integration
   truth source for both `libcamera` and `v4l2loopback`.
6. Install `libcamera` tools and rerun `09`.
7. Turn the working `v4l2loopback` bridge into a repeatable user-facing path:
   - preserve the exact producer command
   - decide whether the right packaging is a small wrapper or a user service
   - then test real apps against `/dev/video42`
8. Determine whether the real long-term answer should still be `libcamera` /
   an IPU7-specific pipeline handler rather than only a repo-local bridge.
9. Determine why the advertised direct standard-pixel formats (`YUYV`,
   `UYVY`, `BGR3`, etc.) are not actually streamable.
10. Investigate the `csi2-0 error: Received packet is too long` warnings and
   the one-scanline `Size Image` vs `bytesused` mismatch.
11. ~~Clean up the patch stack for upstream submission~~ **done**:
   - `upstream-patch/` now contains a 6-patch `git format-patch` mailbox
     series
   - the daisy-chain plumbing now uses a software-node property instead of
     new public TPS68470 platform data
   - `ov5675` now consumes an optional `powerdown` GPIO, so the final board
     data does not describe an unused line
   - validated on `2026-03-12` with:
     - `checkpatch.pl --strict`
     - clean `git am` replay against `4ae12d8bd9a8`
     - clean plain `git am` replay against the current local
       `linux-mainline` `v7.0-rc2` checkout base `11439c4635ed`
     - build / boot / runtime retest on the current local
       `linux-mainline` `7.0.0-rc2-1-mainline-dirty` kernel:
       - clean-boot bind (`01`): yes
       - raw capture after pipeline setup (`06`): yes
       - `cam -l` discovery (`09`): yes
       - `webcam-preview.sh`: yes
       - Chrome on `webcamtests.com`: yes
       - Firefox on `webcamtests.com`: yes, with
         `media.webrtc.camera.allow-pipewire=true`
   - still needs:
     - retest the exact same series after refreshing the local
       `linux-mainline` checkout
     - retest the exact same series on a current Linux `HEAD` build
     - actual mailing-list submission
12. Fix or replace the post-boot PMIC dump path.
13. Keep the broader Windows config-path questions open for upstreamability
   context, but they are no longer blocking basic bring-up.

## Open Questions

- Why does `csi2-0 error: Received packet is too long` appear during capture?
  Is it a CSI2 blanking/format configuration detail, given that
  `Size Image - bytesused = 5,184` bytes (one scanline), or something more?
- Why do `ffmpeg` and `mpv` fail at `VIDIOC_STREAMON` with `Broken pipe` from
  the same configured state where `v4l2-ctl` streams successfully?
- Why do the advertised direct standard-pixel formats (`YUYV`, `UYVY`,
  `BGR3`, etc.) still fail from that same state?
- Why does GStreamer `v4l2src` auto-negotiation fail allocation /
  `not-negotiated` from that same state while explicit `video/x-bayer` caps
  succeed?
- Will `libcamera` discovery or capture work once the tools are installed on
  this machine?
- What is the best packaging for the now-working `v4l2loopback` bridge:
  one-shot wrapper, persistent user service, or something else?
- Why does userspace PMIC register dumping fail completely after boot when the
  kernel can still log `TPS68470 REVID: 0x21`?
- What is the minimum clean patch set needed for upstream submission?
- Will `libcamera` or other higher-level tools work with this pipeline once
  installed, or do they need an IPU7-specific pipeline handler or a Bayer
  bridge layer?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- a full March 9 status report under `docs/`
- reference-backed Windows PMIC notes under `reference/windows-driver-analysis/`
- current support summary under `docs/webcam-status.md`
- recorded `exp13` / `exp14` / `exp15` / `exp16` / `exp17` / `exp18` run
  evidence plus the staged `exp19` capture-validation wrappers

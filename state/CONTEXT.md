# Context

Updated: 2026-03-12

## Objective

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG,
or reduce the remaining blocker to a specific upstream patch or vendor-only gap
with strong evidence.

## Resume

- Repo root:
  - `/home/lhl/github/lhl/msi-prestige13-a2vm-webcam`
- Fastest way back into the latest repo session:
  - `cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam && codex resume --last`
- Picker filtered to this repo:
  - `cd /home/lhl/github/lhl/msi-prestige13-a2vm-webcam && codex resume`
- Show all recorded sessions:
  - `codex resume --all`

## Current State

- IPU7 core support is present and firmware loads.
- `OVTI5675:00` is the correct sensor path.
- the validated `tested` patch stack is:
  - `ms13q3-int3472-tps68470-v1.patch`
  - `ipu-bridge-ovti5675-v1.patch`
  - `ov5675-serial-power-on-v1.patch`
- what those three patches already fixed:
  - the old `No board-data found for this model` failure is gone
  - `ipu-bridge` now finds `OVTI5675:00` and reports one connected camera
  - the old clean-boot `Failed to enable dvdd: -ETIMEDOUT` line is gone
- the current best local branch is `exp18`:
  - standard regulator-side `VSIO` enable read back cleanly as `0x03`
  - the old timeout storm did not return
  - the media graph gained `ov5675 10-0036` linked into `Intel IPU7 CSI2 0`
  - `/dev/v4l-subdev0` now exists
- **raw Bayer capture is now working** with explicit userspace pipeline setup:
  - the missing piece was `media-ctl` link enable + pad format alignment
  - 4 frames captured at 30 fps, 10,077,696 bytes/frame
  - `VIDIOC_STREAMON returned 0 (Success)`
  - the latest clean-boot rerun confirmed the setup is causal, not inherited:
    - pre-state `Intel IPU7 CSI2 0` defaults to `SGRBG10_1X10/4096x3072`
    - `CSI2:1 -> Capture 0` starts disabled
    - steps 2-5 switch the graph to the working `2592x1944` + `[ENABLED]`
      state
  - required userspace commands before streaming:
    - `media-ctl -l '"Intel IPU7 CSI2 0":1 -> "Intel IPU7 ISYS Capture 0":0 [1]'`
    - `media-ctl -V '"Intel IPU7 CSI2 0":0/0 [fmt:SGRBG10_1X10/2592x1944]'`
    - `media-ctl -V '"Intel IPU7 CSI2 0":1/0 [fmt:SGRBG10_1X10/2592x1944]'`
    - `v4l2-ctl --set-fmt-video=width=2592,height=1944,pixelformat=BA10`
  - route setup (`media-ctl -R`) returns `ENOTSUP` -- not needed on IPU7
- remaining minor issues:
  - 5x `csi2-0 error: Received packet is too long` warnings during capture
  - current hard clue: `bytesused = 10,077,696`,
    `Size Image = 10,082,880`, `Bytes per Line = 5,184`
  - the `5,184`-byte delta is exactly one extra scanline in the allocated
    capture buffer
  - normal plug-and-play client compatibility still fails after the known-good
    manual setup:
    - `ffmpeg`: `ioctl(VIDIOC_STREAMON): Broken pipe`
    - `mpv`: same `Broken pipe` path through FFmpeg's V4L2 demuxer
    - GStreamer `v4l2src`: buffer-pool activation failed, then
      `reason not-negotiated (-4)`
    - advertised direct standard-pixel `YUYV` also fails:
      - `v4l2-ctl`: `VIDIOC_STREAMON returned -1 (Broken pipe)`
      - `ffmpeg -input_format yuyv422`: `Broken pipe`
      - GStreamer explicit `video/x-raw,format=YUY2`: `not-negotiated`
  - an explicit userspace bridge now exists:
    - GStreamer explicit `video/x-bayer,format=grbg10le` succeeds
    - `bayer2rgb` + `videoconvert` succeeds
    - `jpegenc` emitted a normal `2592x1944` JPEG artifact under the first
      `08` run
    - `libcamera-*` / `cam`: missing locally
    - `cheese`: present, but not yet exercised in a GUI session
  - post-boot PMIC dumping still returns `ERROR` for every register

## What March 9 Added

- `exp1` PMIC instrumentation proved:
  - `ov5675` gets a real clock provider via the common clock framework
  - `tps68470_clk_prepare()` really runs
  - the remaining blocker is not a dummy xvclk path
- `exp2` staged `S_I2C_CTL` was informative but not a clean negative:
  - the helper path runs
  - `S_I2C_CTL` still reads back as `0x00`
  - unwind later hits `VSIO: failed to disable: -ETIMEDOUT`
- `exp3` `VD = 1050 mV` was a clean negative
- `exp4` `WF::Initialize`-style value programming really executed, but still
  ended at the same `-110` identify timeout
- `exp5` `WF` GPIO mode follow-up was negative
- `exp6` `UF` / `gpio.4` last resort was negative
- `exp7` raw PMIC regmap trace isolated the first bad PMIC transaction:
  - PMIC access is healthy through clock setup plus `ANA` and `CORE` enable
  - the first bad operation is `VSIO` enable on `S_I2C_CTL` `0x43`
  - the `regmap_update_bits()` call returns `0`, but the immediate readback is
    already `-110`
  - after that point, `i2c_designware.1` starts timing out and later PMIC
    accesses collapse to `-110`
- `exp8` focused `S_I2C_CTL` trace confirmed the same failure point with a
  narrower patch:
  - `ANA` and `CORE` still read back cleanly
  - the combined `VSIO` write to `0x43` still returns success but immediate
    readback fails with `-110`
  - the timeout storm still persists, though without the `exp7` emergency-mode
    outcome
- `exp9` split-step `S_I2C_CTL` trace answered the next narrow question:
  - IO-side `BIT(1)` reads back cleanly as `0x02`
  - the wedge begins only after the later GPIO-side `BIT(0)` update
  - the run now fails earlier at `ov5675 ... failed to power on: -110`
- `exp10` `BIT(1)`-only `S_I2C_CTL` changed the failure shape again:
  - `ANA`, `CORE`, and `VSIO BIT(1)` all read back cleanly
  - the old `i2c_designware.1` timeout storm is gone
  - the sensor gets back to chip-ID reads, but they now fail with `-121`
  - `VSIO BIT(1)` also disables cleanly on unwind
- `exp11` tested one later GPIO-phase `BIT(0)` hook:
  - chip-ID behavior stayed at `-121`
  - the observed late `BIT(0)` event was:
    - `pmic_gpio: sensor-gpio.1 value=0 ... before=0x02 update_ret=0 after_ret=-110`
  - after that point, the old timeout storm returned
  - so `exp10` remains the best clean-boot PMIC state
- the post-boot PMIC dump path is still not usable:
  - `scripts/pmic-reg-dump.sh` returned `ERROR` for all registers in
    representative PMIC experiment runs

## What March 12 Added

- ran `scripts/06-media-pipeline-setup.sh` on the current `exp18` boot and
  **achieved first successful raw Bayer capture**:
  - run:
    - `runs/2026-03-12/20260312T004947-snapshot-06-media-pipeline-setup/`
  - the missing piece was explicit userspace `media-ctl` pipeline setup:
    - step 1 (route): `ENOTSUP` -- IPU7 CSI2 does not support explicit routing
    - step 2 (CSI2 sink format to 2592x1944): succeeded
    - step 3 (CSI2 source format to 2592x1944): succeeded
    - step 4 (link enable CSI2:1 -> Capture 0): succeeded -- this was the key
    - step 5 (video node format to BA10): succeeded
  - `VIDIOC_STREAMON returned 0 (Success)`
  - 4 frames captured at 30 fps (33.39 ms delta)
  - 40,310,784 bytes total raw Bayer data
  - 5x `csi2-0 error: Received packet is too long` warnings in dmesg
  - raw data starts with plausible 10-bit Bayer values
- reran `scripts/06-media-pipeline-setup.sh` immediately after a clean reboot
  and captured the real causal baseline:
  - run:
    - `runs/2026-03-12/20260312T020148-snapshot-06-media-pipeline-setup/`
  - the fresh-boot pre-state is the true default graph:
    - `Intel IPU7 CSI2 0` sink/source pads default to `SGRBG10_1X10/4096x3072`
    - `Intel IPU7 CSI2 0`:1 -> `Intel IPU7 ISYS Capture 0`:0 starts as `[]`
  - the script-established post-state is the actual working delta:
    - CSI2 sink format `2592x1944`
    - CSI2 source format `2592x1944`
    - CSI2:1 -> Capture 0 link `[ENABLED]`
    - `/dev/video0` format `2592x1944 BA10`
  - the remaining warning now has a concrete geometry clue:
    - dequeued frame `bytesused = 10,077,696`
    - capture-node `Size Image = 10,082,880`
    - `Bytes per Line = 5,184`
    - delta `5,184` bytes = exactly one scanline
- staged and ran `scripts/07-normal-usage-check.sh` as the first repeatable
  higher-level client compatibility probe:
  - run:
    - `runs/2026-03-12/20260312T021942-snapshot-07-normal-usage-check/`
  - result:
    - raw `v4l2-ctl` sanity capture still succeeded after the known-good
      manual setup
    - installed headless higher-level clients still failed:
      - `ffmpeg`: `ioctl(VIDIOC_STREAMON): Broken pipe`
      - `mpv`: same `Broken pipe` path via FFmpeg's V4L2 demuxer
      - GStreamer `v4l2src`: buffer-pool activation failed, then
        `reason not-negotiated (-4)`
    - local tool availability matters:
      - `ffmpeg`, `gst-launch-1.0`, `mpv`, and `cheese` are installed
      - `libcamera-hello`, `libcamera-still`, `libcamera-vid`, and `cam` are
        missing
    - so the repo now has a direct measured answer:
      - manual raw capture works
      - normal client usage still does not
- staged and ran `scripts/08-userspace-bridge-check.sh` as the first explicit
  userspace-bridge probe:
  - run:
    - `runs/2026-03-12/20260312T032317-snapshot-08-userspace-bridge-check/`
  - result:
    - raw `BA10` capture still succeeded from the known-good configured state
    - the advertised direct `YUYV` path is still unusable:
      - `v4l2-ctl`: `VIDIOC_STREAMON returned -1 (Broken pipe)`
      - `ffmpeg -input_format yuyv422`: `Broken pipe`
      - GStreamer explicit `video/x-raw,format=YUY2`: `not-negotiated`
    - `ffmpeg`'s V4L2 inventory now adds one concrete explanation:
      - it marks the advertised 10-bit Bayer formats unsupported on this path
      - it only lists `uyvy422`, `yuyv422`, `rgb565le`, and `bgr24` as
        supported
    - an explicit framework bridge does work:
      - GStreamer explicit `video/x-bayer,format=grbg10le` succeeds
      - `bayer2rgb` + `videoconvert` succeeds
      - `jpegenc` emitted a normal `2592x1944` JPEG artifact
    - so the remaining gap is now narrower:
      - raw delivery works
      - framework-level Bayer bridging works
      - auto-negotiated / plug-and-play client integration still does not

## What March 11 Added

- preserved a full repo-local review of Antti Laakso's March 10, 2026 Prestige
  14 patch thread under:
  - `docs/antti-prestige14-thread-review.md`
- recorded the main new upstream-relevance conclusion:
  - another MSI `OV5675` / `TPS68470` wiring pattern likely exists
  - on that pattern, `GPIO1` / `GPIO2` are used for daisy-chain mode rather
    than as the direct sensor-control pair
- ran `exp12` as a separate Antti-inspired cross-check:
  - patch:
    - `reference/patches/ms13q3-daisy-chain-crosscheck-v1.patch`
  - scripts:
    - `scripts/exp12-ms13q3-daisy-chain-crosscheck-update.sh`
    - `scripts/exp12-ms13q3-daisy-chain-crosscheck-verify.sh`
  - behavior:
    - enable daisy-chain mode on `GPIO1` / `GPIO2`
    - keep the current `MS-13Q3` `reset` / `powerdown` lookup on those same
      pins
    - log whether Linux later re-drives them out of input mode
  - status:
    - negative as a direct fix
    - proved that Linux immediately re-drives both lines back to output mode
    - first run should be read as layered on the previously installed
      regulator behavior
    - the `exp12` wrappers now reinstall `tps68470-regulator.ko` too so
      reruns restore the baseline regulator module explicitly
    - do not replace `exp10` as the best verified PMIC baseline
- staged the next ordered Antti-model branch set with repo-local patch and
  wrapper pairs, then ran it through `exp17`:
  - `exp13`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-isolation-v1.patch`
    - scripts:
      - `scripts/exp13-ms13q3-daisy-chain-isolation-update.sh`
      - `scripts/exp13-ms13q3-daisy-chain-isolation-verify.sh`
  - `exp14`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-gpio9-reset-v1.patch`
    - scripts:
      - `scripts/exp14-ms13q3-daisy-chain-gpio9-reset-update.sh`
      - `scripts/exp14-ms13q3-daisy-chain-gpio9-reset-verify.sh`
  - `exp15`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-gpio7-reset-v1.patch`
    - scripts:
      - `scripts/exp15-ms13q3-daisy-chain-gpio7-reset-update.sh`
      - `scripts/exp15-ms13q3-daisy-chain-gpio7-reset-verify.sh`
  - `exp16`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-gpio7-gpio9-approx-v1.patch`
    - scripts:
      - `scripts/exp16-ms13q3-daisy-chain-gpio7-gpio9-approx-update.sh`
      - `scripts/exp16-ms13q3-daisy-chain-gpio7-gpio9-approx-verify.sh`
  - `exp17`:
    - patch:
      - `reference/patches/ms13q3-daisy-chain-bit0-retest-v1.patch`
    - scripts:
      - `scripts/exp17-ms13q3-daisy-chain-bit0-retest-update.sh`
      - `scripts/exp17-ms13q3-daisy-chain-bit0-retest-verify.sh`
- preserved the two key branch-shape refinements from follow-up review:
  - `exp13` is self-diagnosing with a one-shot `dump_stack()` if `GPIO1` /
    `GPIO2` still get re-driven as outputs
  - `exp17` exists as an explicit clean-daisy-chain `BIT(0)` re-test after
    `exp13` proves no reclaim
- recorded one important design constraint for those branches:
  - current `ov5675` only consumes `reset` index `0` plus optional
    `powerdown` index `0`
  - Antti's dual-reset board data therefore cannot be copied literally without
    either single-line candidate runs first or an `ov5675` consumer change
- staged the next follow-up as `exp19`:
  - keep the positive `exp18` patch unchanged
  - add `scripts/04-userspace-capture-check.sh`
  - use a custom verify wrapper to record raw userspace streaming on
    `/dev/video0`
- ran `exp19` and recorded the first userspace-capture result:
  - update run:
    - `runs/2026-03-11/20260311T223549-ms13q3-userspace-capture-validation-update/`
  - verify run:
    - `runs/2026-03-11/20260311T223717-snapshot-exp19-userspace-capture/`
  - result:
    - negative, but high-signal
    - `/dev/video0` opened cleanly
    - buffer allocation and queueing succeeded
    - `VIDIOC_STREAMON` failed with `Link has been severed`
    - the raw output file stayed at `0` bytes
    - no matching kernel journal lines appeared during the capture attempt
- ran a no-reboot userspace format sweep on the same positive `exp18` boot:
  - run:
    - `runs/2026-03-11/20260311T232226-userland-format-sweep/`
  - result:
    - negative, but high-signal
    - `/dev/video0` through `/dev/video7` all accepted `VIDIOC_S_FMT` to
      `4096x3072 BA10`
    - all eight nodes still failed `VIDIOC_STREAMON` with
      `Link has been severed`
    - all eight raw output files stayed at `0` bytes
    - no matching kernel journal lines appeared during the sweep
- ran `exp13` and recorded the first clean daisy-chain-isolation result:
  - update run:
    - `runs/2026-03-11/20260311T184340-ms13q3-daisy-chain-isolation-update/`
  - verify run:
    - `runs/2026-03-11/20260311T184614-snapshot-exp13-clean-boot/`
  - result:
    - positive for wiring isolation, negative as a direct fix
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - no later `direction-output-after gpio.1` / `gpio.2`
    - no one-shot reclaim `dump_stack()`
    - sensor failure remained flat at repeated `-121`
- ran `exp14` and recorded the first remote-line candidate result:
  - update run:
    - `runs/2026-03-11/20260311T185841-ms13q3-daisy-chain-gpio9-reset-update/`
  - verify run:
    - `runs/2026-03-11/20260311T190240-snapshot-exp14-clean-boot/`
  - result:
    - positive for remote-line activation, negative as a direct fix
    - `direction-output-after gpio.9 ...`
    - `set-after gpio.9 ... sgpo=0x04`
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - sensor failure remained flat at repeated `-121`
- ran `exp15` and recorded the second remote-line candidate result:
  - update run:
    - `runs/2026-03-11/20260311T194617-ms13q3-daisy-chain-gpio7-reset-update/`
  - verify run:
    - `runs/2026-03-11/20260311T195819-snapshot-exp15-clean-boot/`
  - result:
    - positive for remote-line activation, negative as a direct fix
    - `direction-output-after gpio.7 ...`
    - `set-after gpio.7 ... sgpo=0x01`
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - sensor failure remained flat at repeated `-121`
    - verify-side PMIC dump did not complete:
      - `sudo: timed out reading password`
- ran `exp16` and recorded the first two-line remote approximation result:
  - update run:
    - `runs/2026-03-11/20260311T202133-ms13q3-daisy-chain-gpio7-gpio9-approx-update/`
  - verify run:
    - `runs/2026-03-11/20260311T202258-snapshot-exp16-clean-boot/`
  - result:
    - positive for combined remote-line activation, negative as a direct fix
    - `set-after gpio.7 ... sgpo=0x01`
    - `set-after gpio.9 ... sgpo=0x05`
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - sensor failure remained flat at repeated `-121`
    - verify-side PMIC dump returned `ERROR` for all registers again
- ran `exp17` and recorded the clean daisy-chain late-`BIT(0)` re-test result:
  - update run:
    - `runs/2026-03-11/20260311T203041-ms13q3-daisy-chain-bit0-retest-update/`
  - verify run:
    - `runs/2026-03-11/20260311T203557-snapshot-exp17-clean-boot/`
  - result:
    - positive for safe later `BIT(0)`, negative as a direct fix
    - `probe-after gpio.1 ... ctl=0x00`
    - `probe-after gpio.2 ... ctl=0x00`
    - `set-after gpio.7 ... sgpo=0x01`
    - `set-after gpio.9 ... sgpo=0x05`
    - `exp17_pmic_gpio ... before=0x02 ... after=0x03`
    - no `controller timed out` return
    - sensor failure remained flat at repeated `-121`
    - `disable-bit1-only VSIO ... before=0x03 ... after=0x01`
    - verify-side PMIC dump returned `ERROR` for all registers again

## Current Interpretation

- **Raw Bayer capture is now working.**
- The `exp18` kernel branch + explicit `media-ctl` pipeline setup delivers
  real frames from `/dev/video0`.
- The `STREAMON` "Link has been severed" failure was caused by missing
  userspace `media-ctl` link enable and pad format setup, not by a kernel or
  firmware gap.
- The `media-ctl -R` route command returns `ENOTSUP` on the IPU7 CSI2 entity,
  but that is not needed -- link enable + format alignment is sufficient.
- `scripts/07-normal-usage-check.sh` now proves the remaining gap is at the
  higher-level client layer, not at the raw `v4l2-ctl` layer:
  - `ffmpeg` / `mpv` fail at `VIDIOC_STREAMON` with `Broken pipe`
  - GStreamer `v4l2src` fails allocation / `not-negotiated`
- `scripts/08-userspace-bridge-check.sh` now proves the remaining gap is not
  "no higher-level framework can use the stream" but specifically
  auto-negotiation / standardized-client integration:
  - direct advertised `YUYV` still fails
  - explicit GStreamer `video/x-bayer` succeeds
  - `bayer2rgb` + `videoconvert` succeeds
  - JPEG export succeeds
- 5x `csi2-0 error: Received packet is too long` warnings appear during
  capture; the current hard clue is a one-scanline mismatch between
  `bytesused` and `Size Image`, so this still looks like a CSI2
  blanking/format detail rather than a data-path blocker.
- The full experiment chain from `exp1` through `exp18` successfully narrowed
  the PMIC, GPIO, and wiring model until the sensor bound and streamed.

## Next Best Steps

1. Use `exp18` as the current kernel branch.
2. Use fresh-boot `scripts/06-media-pipeline-setup.sh` reruns as the capture
   truth source for userspace-path changes.
3. Use `scripts/07-normal-usage-check.sh` as the current auto-negotiated
   higher-level client truth source.
4. Use `scripts/08-userspace-bridge-check.sh` as the current explicit
   userspace-bridge truth source.
5. Test whether the working GStreamer Bayer bridge can be exposed to normal
   apps, or whether the real answer is `libcamera` / an IPU7 pipeline handler.
6. Determine why the advertised direct standard-pixel formats (`YUYV`,
   `UYVY`, `BGR3`, etc.) are not actually streamable.
7. Investigate the `Received packet is too long` CSI2 warnings and the
   one-scanline `Size Image` vs `bytesused` mismatch.
8. Install and try `libcamera-*` / `cam`, then manually exercise `cheese`.
9. Clean up the patch stack for upstream submission.
10. Fix or replace the post-boot PMIC dump path.
11. Do not rerun the broad `exp7` snapshot patch as a default path.

## Key Paths

- Local kernel package root:
  - `~/.cache/paru/clone/linux-mainline`
- Editable kernel worktree:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
- Patch-stack workflow:
  - `docs/patch-kernel-workflow.md`
  - `scripts/patch-kernel.sh`
- PMIC experiment workflow:
  - `docs/pmic-followup-experiments.md`
  - `scripts/lib-experiment-workflow.sh`
  - `scripts/04-userspace-capture-check.sh`
  - `scripts/05-userspace-format-sweep.sh`
  - `scripts/exp19-ms13q3-userspace-capture-validation-update.sh`
  - `scripts/exp19-ms13q3-userspace-capture-validation-verify.sh`
- Complete March 9 report:
  - `docs/20260309-status-report.md`
- Short live status:
  - `docs/webcam-status.md`
- Windows PMIC analysis:
  - `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`
  - `docs/wf-vs-uf-gpio-analysis.md`

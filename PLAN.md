# Webcam Bring-Up Plan

Updated: 2026-03-11

This is the active plan after the completed March 9 PMIC experiment batch and
the completed `exp13` / `exp14` / `exp15` / `exp16` / `exp17` Antti-model
follow-up runs.

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
- the current remaining clean-boot blocker is now split into two observed
  phases:
  - the older baseline path still ends in `-110` chip-ID timeouts
  - the latest `exp10` path avoids the PMIC timeout storm but still ends in
    `-121` chip-ID failures
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
  - the remaining gap is PMIC-side behavior, not basic platform support
  - the early regulator-phase `BIT(0)` write was wrong
  - the old direct-use `GPIO1` / `GPIO2` Linux board model was wrong as a
    clean Antti-style branch
  - the current-driver two-line `GPIO9` / `GPIO7` approximation is active,
    but still insufficient
  - the late clean-branch `BIT(0)` re-test is safe, but still insufficient
  - the next high-value discriminator is whether standard `VSIO` enable
    becomes safe only once the clean daisy-chain branch is in place
  - after that, the next likely gap is still `ov5675` consumer/timing
    behavior, not another blind remote-line guess

## Workstreams

### 1. PMIC state truth

- [x] Run the `BIT(1)`-only follow-up in the regulator `VSIO` path.
- [x] Determine whether keeping `BIT(1)` while omitting `BIT(0)` lets the bus
  stay alive long enough to return to the sensor identify stage.
- [x] Determine whether a later board-specific `BIT(0)` assertion can be safe
  on the clean remote-line branch.
- [ ] Decide whether any later board-specific `BIT(0)` assertion belongs
  anywhere in Linux at all, and if so on which exact signal/phase.

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

1. Keep `exp10` as the verified PMIC baseline while comparing post-branch-set
   work.
2. Treat `exp12` as completed collision evidence, not as a direct test of
   Antti's working model.
3. Treat `exp13` as completed evidence, not as the next branch to run.
   - it proved Linux can leave `GPIO1` / `GPIO2` in Antti-style
     daisy-chain input mode for the observed probe window
   - it did not improve the flat repeated `-121` chip-ID failure
4. Treat `exp14` as completed evidence, not as the next branch to run.
   - it proved `GPIO9` is active
   - it also proved `GPIO9` alone is insufficient
5. Treat `exp15` as completed evidence, not as the next branch to run.
   - it proved `GPIO7` is active
   - it also proved `GPIO7` alone is insufficient
6. Treat `exp16` as completed evidence, not as the next branch to run.
   - it proved the current two-line approximation drives both remote lines
   - it also proved that combined remote-line activity still stays flat at
     repeated `-121`
7. Treat `exp17` as completed evidence, not as a future branch.
   - it proved the clean remote-line branch can tolerate one later
     `S_I2C_CTL BIT(0)` assertion
   - the observed late write read back cleanly as `0x03`
   - the sensor still stayed flat at repeated `-121`
   - the old timeout storm did not return
8. Run staged `exp18` next.
   - restore standard `VSIO` enable on top of the clean daisy-chain branch
   - do not bundle that with endpoint-wait or broad regulator-set changes yet
9. Scope the `ov5675` consumer-model or timing gap directly if that still
   stays negative.
10. Keep using:
   - `scripts/patch-kernel.sh`
   - `scripts/exp*-*-update.sh`
   - `scripts/exp*-*-verify.sh`
   - `scripts/01-clean-boot-check.sh`
   to keep evidence reproducible
11. Keep the broader Windows config-path and PMIC dump questions open, but do
    not let them delay the next narrow PMIC comparison branch.

## Open Questions

- Why does the `S_I2C_CTL` `0x43` update path report success while immediate
  PMIC readback collapses to `-110`?
- With `exp13` proving no reclaim, why does the clean daisy-chain-isolated
  branch still end at flat repeated `-121` chip-ID failures?
- With `exp16` proving the current two-line `GPIO9` / `GPIO7` approximation is
  active but still flat at `-121`, and `exp17` proving one later `BIT(0)` is
  safe but still non-curative, is the next missing piece an `ov5675`
  consumer change, more exact electrical timing, or simply restoring standard
  `VSIO` enable now that the clean daisy-chain branch exists?
- Where, if anywhere, does this board actually want the later `BIT(0)`
  transition once the regulator-phase PMIC/I2C path is already healthy and one
  late `sensor-gpio.9` write can already read back as `0x03`?
- Why did the earlier late hook only show up on `sensor-gpio.1`, while the
  clean remote-line branch later shows a safe `sensor-gpio.9` `BIT(0)` event?
- Why does userspace PMIC register dumping fail completely after boot when the
  kernel can still log `TPS68470 REVID: 0x21`?
- What exact higher-level Windows configuration feeds `WF::SetConf` on this
  laptop?
- What exact conditions choose `WF` versus `UF` in the Windows power path?
- Are we missing one more PMIC-side control write, or are we missing the exact
  electrical timing on reset / powerdown?

## Deliverables

- Up-to-date `README.md`, `PLAN.md`, `WORKLOG.md`, and `state/CONTEXT.md`
- a full March 9 status report under `docs/`
- reference-backed Windows PMIC notes under `reference/windows-driver-analysis/`
- current support summary under `docs/webcam-status.md`
- recorded `exp13` / `exp14` / `exp15` / `exp16` / `exp17` run evidence plus
  the staged `exp18` patch and wrapper scripts

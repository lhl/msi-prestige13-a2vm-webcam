# Webcam Bring-Up Plan

Updated: 2026-03-11

This is the active plan after the completed March 9 PMIC experiment batch and
the decision to prioritize the Antti-model `exp13`-`exp17` branch set.

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
  - the current Linux `GPIO1` / `GPIO2` board model may also be wrong
  - the next high-value work is to test the Antti-style daisy-chain model
    without immediately re-overriding it in Linux

## Workstreams

### 1. PMIC state truth

- [x] Run the `BIT(1)`-only follow-up in the regulator `VSIO` path.
- [x] Determine whether keeping `BIT(1)` while omitting `BIT(0)` lets the bus
  stay alive long enough to return to the sensor identify stage.
- [ ] Decide whether a later board-specific `BIT(0)` assertion belongs
  anywhere in Linux at all, and if so on which signal/phase.

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
- [ ] Stage `exp13`: keep `exp10`, enable daisy-chain, and remove
  `OVTI5675:00` use of `GPIO1` / `GPIO2`.
- [ ] Stage `exp14`: carry `exp13` forward and test `GPIO9` as the first
  remote control-line candidate.
- [ ] Stage `exp15`: carry `exp13` forward and test `GPIO7` as the alternate
  remote control-line candidate.
- [ ] Stage `exp16`: carry the clean daisy-chain branch forward and test the
  best two-line `GPIO7` / `GPIO9` approximation.
- [ ] Make `exp13` self-diagnosing.
  - add a one-shot `dump_stack()` for any daisy-chain-enabled attempt to drive
    `GPIO1` or `GPIO2` as outputs
- [ ] Stage `exp17`: re-test `S_I2C_CTL BIT(0)` only on top of a clean
  daisy-chain-isolated branch.

## Near-Term Priority

1. Keep `exp10` as the verified PMIC baseline while staging the next branch
   set.
2. Treat `exp12` as completed collision evidence, not as a direct test of
   Antti's working model.
3. Run `exp13` first.
   - prove whether Linux can leave `GPIO1` / `GPIO2` in Antti-style
     daisy-chain input mode for the full probe window
4. Use `exp14` and `exp15` to answer the next constrained question.
   - under current `ov5675` driver limits, is `GPIO9` or `GPIO7` the first
     credible remote control-line candidate
5. Use `exp16` as the closest current-driver approximation of Antti's remote
   mapping only after the single-line branches have been isolated first.
6. Add one self-diagnosing guard to `exp13`.
   - if `GPIO1` / `GPIO2` still get reclaimed, a one-shot stack dump should
     identify the call path immediately
7. Use `exp17` as the explicit PMIC-side follow-up after the wiring-model
   collision is removed.
   - only stage it after `exp13` proves no reclaim
   - carry forward the cleanest daisy-chain-isolated branch from `exp13`
     through `exp16`
8. Keep using:
   - `scripts/patch-kernel.sh`
   - `scripts/exp*-*-update.sh`
   - `scripts/exp*-*-verify.sh`
   - `scripts/01-clean-boot-check.sh`
   to keep evidence reproducible
9. Keep the broader Windows config-path and PMIC dump questions open, but do
   not let them delay the next clean Antti-model branch tests.

## Open Questions

- Why does the `S_I2C_CTL` `0x43` update path report success while immediate
  PMIC readback collapses to `-110`?
- Can `exp13` prove that Linux no longer reclaims `GPIO1` / `GPIO2` once
  daisy-chain mode is enabled?
- If `exp13` still reclaims those lines, what exact call path does the new
  one-shot stack dump point to?
- Under current `ov5675` consumer behavior, is `GPIO9` or `GPIO7` the first
  better remote control-line candidate?
- If `exp16` is still negative, do we need an `ov5675` consumer change to
  model Antti's dual-reset style more faithfully?
- Once a clean daisy-chain branch exists, does `BIT(0)` become safe there or
  does it still immediately re-wedge PMIC access?
- Where, if anywhere, does this board actually want the later `BIT(0)`
  transition once the regulator-phase PMIC/I2C path is already healthy?
- Why did the current late hook only show up on `sensor-gpio.1`, not a cleaner
  earlier GPIO-active phase?
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
- patch-ready notes for `exp13` through `exp17`

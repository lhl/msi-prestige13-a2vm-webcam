# 2026-03-09 Status Report

This report is the complete March 9, 2026 assessment of the MSI Prestige 13
AI+ Evo A2VMG webcam reverse-engineering effort.

It covers:

- what now works in Linux
- what still does not work
- what we extracted from the MSI Windows driver
- what tooling now exists in this repo
- what the completed experiment batch proved
- how this effort compares to simpler `TPS68470` camera bring-up work such as
  the existing Surface Go support
- what fundamental data is still missing
- what the next batch of work should be

## Executive Summary

The webcam still does not work on Linux.

But the state is materially better than it was at the start of this effort:

- IPU7 support is present enough to enumerate hardware and load firmware.
- the correct sensor path is known: `OVTI5675:00`
- the MSI `INT3472` / `TPS68470` board-data gap was real and is now covered by
  a local patch
- the `ipu-bridge` `OVTI5675` support gap was real and is now covered by a
  local patch
- the old clean-boot `dvdd` timeout is gone
- the `ov5675` driver now reaches sensor identification on a clean boot
- the PMIC clock path is real and runs

The remaining failure is now narrow and concrete:

- on clean boot, `ov5675` performs chip-ID reads
- every chip-ID read attempt still times out with `-110`
- `ov5675` remains unbound
- there are still no `/dev/v4l-subdev*` nodes
- the first PMIC transaction after which readback collapses is now identified
  as `VSIO` enable on `S_I2C_CTL` `0x43`

That means this is no longer mainly a "Linux does not know the hardware"
problem. It is now a "Linux still does not reproduce the exact PMIC behavior
or waveform that wakes the sensor far enough to answer I2C" problem.

## Machine And Software Baseline

Machine under test:

- model: `Prestige 13 AI+ Evo A2VMG`
- revision: `REV:1.0`

Linux side:

- kernel: `7.0.0-rc2-1-mainline-dirty`
- editable kernel tree:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`

Important live identities:

- IPU PCI device: `8086:645d`
- PMIC companion device: `i2c-INT3472:06`
- sensor device: `i2c-OVTI5675:00`

Current repo state at this checkpoint:

- the repo includes the raw March 9 run batch under `runs/2026-03-09/`
- Windows packages and extracted artifacts are checked in under `reference/`
- the PMIC experiment workflow is scripted and repeatable

## What Is Working In Linux

### Core platform support

The broad platform path is no longer the blocker:

- `intel-ipu7` loads
- firmware loads
- `/dev/media0` and multiple `/dev/video*` nodes exist

This matters because the IPU core can initialize without a working camera
pipeline. Early in the effort, that ambiguity made it easy to over-credit the
platform side. That ambiguity is mostly gone now.

### Sensor discovery and graph progress

The local patched kernel now gets past several earlier blockers:

- the MSI-specific `INT3472` / `TPS68470` board-data patch is active enough to
  instantiate the sensor client
- the `ipu-bridge` follow-up patch now recognizes `OVTI5675`
- clean boot shows:
  - `intel-ipu7 0000:00:05.0: Found supported sensor OVTI5675:00`
  - `intel-ipu7 0000:00:05.0: Connected 1 cameras`

That is meaningful progress. The camera path is no longer failing at pure
enumeration.

### PMIC identity and clock path

The PMIC is at least reachable enough in kernel space to identify itself:

- `int3472-tps68470 i2c-INT3472:06: TPS68470 REVID: 0x21`

`exp1` proved that the clock object feeding `ov5675` is not just a silent
dummy fallback:

- `resolved xvclk provider via common clock framework at 19200000 Hz`
- `tps68470_clk_prepare PLLCTL=0xd5 CLKCFG1=0x0a CLKCFG2=0x05 rate=19200000`
- later unwind:
  - `tps68470_clk_unprepare PLLCTL=0x00 CLKCFG1=0x00 CLKCFG2=0x00 rate=19200000`

That removes one entire class of explanation.

## What Is Still Not Working

All recent clean-boot checkpoints still converge on the same failure:

- `ov5675 i2c-OVTI5675:00: chip id read attempt 1/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 2/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 3/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 4/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: chip id read attempt 5/5 failed: -110`
- `ov5675 i2c-OVTI5675:00: failed to find sensor: -110`
- `ov5675 i2c-OVTI5675:00: probe with driver ov5675 failed with error -110`

Consequences:

- `ov5675` does not bind
- there are still no `/dev/v4l-subdev*` nodes
- the webcam is still unusable from userspace

The old broad failures are not the main problem anymore:

- not "No board-data found for this model"
- not "no firmware graph endpoint found"
- not the old clean-boot `Failed to enable dvdd: -ETIMEDOUT`

## Current Baseline Patch Stack

The current `tested` baseline stack is:

1. `reference/patches/ms13q3-int3472-tps68470-v1.patch`
2. `reference/patches/ipu-bridge-ovti5675-v1.patch`
3. `reference/patches/ov5675-serial-power-on-v1.patch`

What those three patches already fixed:

- the old MSI `INT3472` board-data failure
- missing `OVTI5675` support in `ipu-bridge`
- the clean-boot `dvdd` timeout in `ov5675_power_on()`

This is important when judging progress relative to other efforts. Those
patches are not hypothetical anymore. They already moved the failure forward
substantially.

Experiment provenance note:

- the March 9 `exp1` through `exp6` PMIC runs were executed on the repo's
  `candidate` baseline profile, not the pure `tested` profile
- `candidate` means:
  - the `tested` baseline stack above
  - plus the current extra `ov5675` debug patches:
    - `ov5675-powerdown-followup-v1.patch`
    - `ov5675-identify-debug-v1.patch`
    - `ov5675-gpio-release-sequencing-debug-v1.patch`
- that matches the recorded experiment metadata:
  - `baseline_profile=candidate`

## Reverse-Engineering Timeline So Far

### 1. Initial broad hypothesis

At the beginning, the most likely explanation was that Linux lacked MSI-specific
`TPS68470` board-data for the camera PMIC.

That was supported by:

- existing Linux support in `tps68470_board_data.c` focusing on other devices
  such as Surface Go and Dell 7212
- external notes already pointing at `TPS68470` as the camera blocker on this
  laptop family

### 2. Board-data gap confirmed and patched

The local patch adding MSI `MS-13Q3` board-data was necessary.

Once applied:

- the old board-data failure disappeared
- `i2c-OVTI5675:00` appeared

This proved the effort was not stuck on a false lead.

### 3. Firmware graph gap exposed and patched

The first `ov5675` diagnostic work exposed:

- `no firmware graph endpoint found`

That led to the `ipu-bridge` `OVTI5675` follow-up patch.

Once applied:

- `intel-ipu7` found `OVTI5675:00`
- `Connected 1 cameras`

### 4. Regulator and power-on ordering improved

The next meaningful fix was the `ov5675` serial power-on change.

That removed:

- the old `dvdd` timeout

And moved the failure forward again:

- from power-on failure to sensor identify failure

### 5. GPIO and identify debugging narrowed the failure

The `ov5675` identify-debug work replaced the older collapsed `-5` outcome
with the real remaining signal:

- repeated chip-ID read timeouts `-110`

That was a major narrowing step.

### 6. Lockstep GPIO hypotheses mostly exhausted

Several follow-ups were then tested and came back negative:

- label-only `GPIO1` / `GPIO2` role swap
- first polarity variant
- second polarity variant
- three staged `ov5675` GPIO-release variants

Interpretation:

- with the current `ov5675` power sequence, a pure label swap is close to an
  electrical no-op because both lines are driven in lockstep
- the obvious GPIO-only branches are mostly exhausted

### 7. Windows driver extraction materially deepened

The March 9 extraction work showed that the MSI Windows PMIC path contains much
more than static rail enables.

That changed the leading hypothesis from:

- "maybe board-data and GPIO labels are enough"

to:

- "Linux may still be missing board-specific PMIC behavior that Windows
  performs in code"

### 8. PMIC experiments 1-6 completed

The first full PMIC batch is now done.

### 9. `exp7` isolated the first bad PMIC transaction

The next PMIC tracing step moved the project from "the PMIC path is still
suspicious" to "the first bad operation is now known."

`exp7` proved:

- PMIC access is healthy through:
  - clock setup
  - `ANA` enable on `VACTL`
  - `CORE` enable on `VDCTL`
- the first bad PMIC transaction is:
  - `VSIO` enable on `S_I2C_CTL` `0x43`
- in that transition:
  - `regmap_update_bits()` returns `0`
  - immediate readback already fails with `-110`

After that point:

- `i2c_designware.1` logs repeated `controller timed out`
- later PMIC readback collapses to `-110`
- the sensor still ends at the same repeated chip-ID timeouts

`exp7` also showed that broad post-failure PMIC snapshotting is too expensive
to leave in place as the default path:

- the timeout storm was large enough to interact badly with boot
- one run hit a `boot.mount` timeout and emergency mode before `/boot` mounted
  successfully after bypass
- that looks like collateral from the instrumentation-amplified I2C timeout
  path, not evidence that `/boot` is the root webcam problem

Outcome:

- no experiment fixed the webcam
- but several experiments added high-value signal
- the remaining uncertainty is now smaller and more concrete

## Windows Driver Extraction State

### What we have

The repo now vendors the exact relevant Windows packages:

- `reference/windows-driver-packages/msi-ov5675-70.26100.19939.1/`
- `reference/windows-driver-packages/intel-control-logic-71.26100.23.20279/`

Static analysis of `iactrllogic64.sys` is repeatable via:

- `scripts/extract-iactrllogic64.sh`

Generated artifacts are checked in under:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/`

That directory now includes:

- method-string extraction
- string xrefs
- PE metadata
- targeted disassembly windows
- synthesized notes

### What we extracted successfully

The strongest current Windows findings are in:

- `reference/windows-driver-analysis/iactrllogic64-70.26100.19939.1/power-sequencing-notes.md`

Recovered `WF` behavior:

- five-voltage tuple:
  - `VD = 1050 mV`
  - `VA = 2800 mV`
  - `VIO = 1800 mV`
  - `VCM = 2800 mV`
  - `VSIO = 1800 mV`
- `WF::Initialize` writes PMIC value registers before later helpers:
  - `0x41`
  - `0x40`
  - `0x42`
  - `0x3c`
  - `0x3f`
- `WF::SetVSIOCtl_IO` uses staged `S_I2C_CTL` behavior around register `0x43`
- `WF::IoActive_GPIO` touches:
  - `GPCTL1A` `0x16`
  - `GPCTL2A` `0x18`
- `SensorPowerOn` layers:
  - `IoActive_IO`
  - a `WF` or `UF` power-on branch
  - `IoActive_GPIO`

What that means:

- Windows definitely programs the PMIC in a board-specific way
- Windows does more than static consumer-supply setup
- the local Linux gap is no longer speculative

### What is still not fully recovered from Windows

We still do not have a complete Linux-ready reconstruction of:

1. the higher-level board config blob that feeds `WF::SetConf`
2. the exact conditions that choose `WF` versus `UF` on this laptop
3. the exact semantic truth of all PMIC GPIO roles and timing
4. whether any additional board-specific condition or consumer beyond the
   current Linux model participates in the wake-up path

The Windows extraction is strong, but not yet complete enough to mechanically
translate into a proven Linux implementation.

## Tooling State

This repo now has unusually strong bring-up tooling for a hardware reverse-
engineering effort of this size.

### Core workflow tooling

- `scripts/patch-kernel.sh`
  - repeatable baseline patch application
  - `tested` and `candidate` profiles
- `scripts/webcam-run.sh`
  - repeatable snapshot and reprobe harness
- `scripts/01-clean-boot-check.sh`
  - clean-boot capture
- `scripts/02-ov5675-reload-check.sh`
  - reload-only checkpoint
- `scripts/03-ov5675-identify-debug-check.sh`
  - identify-debug reload path

### PMIC experiment workflow

- `scripts/lib-experiment-workflow.sh`
- `scripts/exp1-pmic-instrumentation-update.sh`
- `scripts/exp1-pmic-instrumentation-verify.sh`
- `scripts/exp2-wf-s-i2c-ctl-update.sh`
- `scripts/exp2-wf-s-i2c-ctl-verify.sh`
- `scripts/exp3-ms13q3-vd-1050mv-update.sh`
- `scripts/exp3-ms13q3-vd-1050mv-verify.sh`
- `scripts/exp4-wf-init-value-programming-update.sh`
- `scripts/exp4-wf-init-value-programming-verify.sh`
- `scripts/exp5-wf-gpio-mode-followup-update.sh`
- `scripts/exp5-wf-gpio-mode-followup-verify.sh`
- `scripts/exp6-uf-gpio4-last-resort-update.sh`
- `scripts/exp6-uf-gpio4-last-resort-verify.sh`

The wrappers now handle:

- baseline reapply
- experiment isolation by resetting known experiment-touched files
- module-only rebuild/install
- `depmod`
- reboot handoff
- post-boot verify capture
- repo-local temp space via `.tmp/` to avoid `/tmp` quota failures
- best-effort status snapshots
- run-directory ownership normalization after root-assisted capture

### Low-level helpers

- `scripts/capture-acpi.sh`
- `scripts/extract-iactrllogic64.sh`
- `scripts/pmic-reg-dump.sh`
- `scripts/i2c-dump.sh`
- `scripts/i2c-sensor-check.sh`

### Run archival

The `runs/2026-03-09/` tree now preserves:

- clean-boot checkpoints
- failed and successful update attempts
- PMIC experiment outputs
- focused summaries
- experiment journals
- PMIC dump attempts

This matters for process quality. The work is not just "we tried some things
and remember the gist." It is now reproducible.

## PMIC Experiment Results

### Summary Table

| Experiment | Goal | Result | Interpretation |
| --- | --- | --- | --- |
| `exp1` | prove whether the PMIC clock/regulator path really fires | negative for function, positive for signal | real clock path confirmed; not a dummy clock problem |
| `exp2` | stage `S_I2C_CTL` `0x43` | negative and messy | current implementation did not move `0x43` off zero and introduced a disable timeout |
| `exp3` | match Windows `VD = 1050 mV` | clean negative | core-voltage mismatch alone is not the blocker |
| `exp4` | mimic `WF::Initialize` value programming | negative for function, positive for signal | value-register programming alone is insufficient |
| `exp5` | revisit PMIC GPIO mode semantics | clean negative | more blind GPIO mode changes are low value |
| `exp6` | test `UF` / `gpio.4` last resort | clean negative | current local evidence still does not justify pivoting to `UF` |

All six PMIC experiments above ran on `candidate`, not on bare `tested`.

### `exp1` PMIC instrumentation

High-value findings:

- `ov5675` got a real common-clock provider at `19.2 MHz`
- `tps68470_clk_prepare()` ran and programmed PMIC clock registers
- `tps68470_clk_unprepare()` later ran on unwind
- ANA and CORE enable logging fired

Most important negative:

- `VSIO` still logged `S_I2C_CTL=0x00`

Implication:

- the problem is not a dummy xvclk object
- the `S_I2C_CTL` path remains suspicious

### `exp2` staged `S_I2C_CTL`

Observed lines:

- `WF S_I2C_CTL staged enable start old=0x00`
- `WF S_I2C_CTL staged enable done S_I2C_CTL=0x00`
- later:
  - `WF S_I2C_CTL staged disable S_I2C_CTL=0x00`
  - `VSIO: failed to disable: -ETIMEDOUT`

Interpretation:

- this did not behave like a clean reproduction of the Windows staged logic
- the fact that readback stayed `0x00` is the key unresolved question

This experiment is informative, but not conclusive.

### `exp3` `VD = 1050 mV`

Result:

- same repeated `-110` chip-ID timeout

Interpretation:

- the one clear Windows-vs-Linux voltage mismatch was real evidence, but it is
  not enough by itself

### `exp4` `WF::Initialize`-style value programming

Observed line:

- `applying WF init value programming: VD=1050mV VA=2800mV VCM=2800mV VIO=1800mV VSIO=1800mV`

Interpretation:

- the hook executed
- the sensor still did not answer
- therefore the missing piece is not just "Linux never programmed the value
  registers"

### `exp5` GPIO mode follow-up

Observed lines:

- `gpio.1 GPCTL1A output=0x02`
- `gpio.2 GPCTL2A output=0x02`

Interpretation:

- PMIC GPIO mode changes did land
- sensor behavior did not change

### `exp6` `UF` / `gpio.4` last resort

Observed lines:

- `UF gpio.4 last resort: GPDO=0x00 value=0`

Interpretation:

- the current `UF` branch is not giving us a viable wake-up path
- this remains a last-resort branch, not the main direction

## What The Negative Results Actually Mean

These experiments were not wasted work.

What they let us stop pretending:

- that the problem might still be just a missing DMI match
- that the clock object might still be a dummy
- that a small `GPIO1` / `GPIO2` label or polarity change was likely to fix it
- that a blind `UF` / `gpio.4` pivot was the most credible next move
- that the Windows voltage tuple alone would probably solve the issue

What is still plausibly missing:

- exact staged PMIC pass-through behavior around `S_I2C_CTL`
- another PMIC-side write or condition that Linux still does not model
- exact reset / powerdown waveform truth at the sensor pins

## Comparison To Other Linux Webcam Reverse-Engineering Efforts

### Compared to simpler `TPS68470` bring-up such as Surface Go

The existing Linux `tps68470_board_data.c` cases for devices such as Surface Go
and Dell 7212 are fundamentally table-driven:

- regulator consumer mappings
- fixed voltage constraints
- GPIO lookup tables
- DMI match entries

That is important because our MSI effort started by looking like the same class
of problem:

- missing board-data
- missing GPIO mapping
- maybe missing one voltage choice

We solved that class of problem and still did not get a working camera.

That is the strongest evidence that this MSI case is harder than a simple
Surface-style board-data port.

### Is our PMIC setup really harder?

Yes, probably.

The reason is not just "MSI is weird." The reason is that the extracted Windows
driver shows behavior beyond the static board-data model that current Linux
uses:

- `WF::Initialize` value-register programming
- staged `S_I2C_CTL` behavior
- layered `IoActive_IO` and `IoActive_GPIO`
- runtime `WF` versus `UF` selection

That is qualitatively more complex than just filling in a missing DMI table
entry.

### Are we making slower or faster progress than similar efforts?

Two answers are both true:

1. Relative to simple upstream bring-up cases, functional progress is slower.
   - We still do not have a working camera after clearing the obvious gaps.
   - That is because the remaining blocker appears behavioral, not declarative.

2. Relative to typical hobby reverse-engineering efforts, process and evidence
   quality are better than average.
   - We have vendored Windows packages.
   - We have repeatable static extraction.
   - We have clean-boot run archives.
   - We have an idempotent patch-stack workflow.
   - We have isolated experiment wrappers.

So the honest assessment is:

- we are making faster-than-average progress in narrowing the problem
- but slower-than-simple-board-port progress in actually achieving a working
  camera

That is consistent with the problem becoming harder, not with the work being
directionless.

### Why we still do not have something working

The remaining stage is the hardest one:

- the sensor exists
- the graph exists far enough
- some PMIC activity exists
- but the sensor never wakes enough to answer I2C chip-ID reads

That is exactly the stage where missing details are hardest to infer:

- one wrong PMIC control bit
- one missing staged enable
- one wrong polarity
- one wrong timing edge
- one missing pass-through condition

Those failures all look the same at the top level:

- `-110` timeout

## Fundamental Data We Still Do Not Have

This effort is not blocked by total ignorance anymore. We know a lot.

### Data we already do have

We are not missing:

- the sensor identity
- the PMIC identity
- the active ACPI path
- the broad Linux driver path
- evidence that the Windows driver really programs the PMIC
- the exact Windows package and binary carrying that behavior

### Fundamental data still missing

1. Exact live PMIC register state during the failing identify window.
   - This is still a real gap.
   - `scripts/pmic-reg-dump.sh` returns `ERROR` for every post-boot register
     read in representative PMIC experiment runs.
   - Until that is fixed, we cannot independently confirm post-failure PMIC
     state from userspace.

2. Exact raw regmap behavior around `S_I2C_CTL` `0x43`.
   - `exp2` logs the staged helper path running.
   - It does not explain why readback stays `0x00`.
   - We still need raw write/read return codes and better in-kernel state
     capture.

3. Exact higher-level Windows configuration path feeding `WF::SetConf`.
   - We recovered the `WF` tuple and the methods using it.
   - We have not fully recovered the board-specific config source and runtime
     selection logic above that layer.

4. Exact electrical truth of the control waveform.
   - We still do not have direct hardware observation of the PMIC GPIO and
     sensor reset / powerdown lines.
   - Static code analysis can narrow this, but it cannot fully replace an
     electrical trace if the software path stays ambiguous.

5. Why userspace PMIC access fails even though the kernel talks to the PMIC.
   - This is its own missing datum.
   - Until explained, it weakens our secondary verification path.

### Data that may be missing, but is not currently the top blocker

- meaning of the Windows `graph_settings_ov5675_*_lnl.bin` files
- any higher-level Windows camera-stack metadata above the PMIC helper layer

Those may matter eventually, but they are not currently the strongest missing
piece relative to the `-110` chip-ID timeout.

## What We Can Honestly Stop Spending Time On

For now, these are low-value branches:

- more blind `GPIO1` / `GPIO2` label swaps
- more one-line polarity guesses
- more staged `ov5675` GPIO-release permutations without new PMIC evidence
- more `UF` / `gpio.4` work without stronger local evidence

Those branches have enough clean negatives now.

## Current Blockers

1. PMIC readback gap:
   - post-boot PMIC dumps still fail completely
2. `S_I2C_CTL` ambiguity:
   - staged Linux experiment path runs, but readback stays `0x00`
3. incomplete Windows reconstruction:
   - still missing the higher-level config-selection truth
4. lack of electrical truth:
   - no direct line-level waveform capture yet

## Next Steps

Ordered by likely value:

1. Run the narrower `S_I2C_CTL`-focused follow-up.
   - keep the high-value `exp7` signal around `0x43`
   - confirm in a lighter-weight run that:
     - `ANA` enable still succeeds
     - `CORE` enable still succeeds
     - `VSIO` `S_I2C_CTL` `0x43` remains the first transition after which
       PMIC readback fails
   - avoid broad post-failure snapshots once the first `-110` appears

2. Fix or replace the PMIC dump path.
   - figure out why post-boot userspace reads all fail
   - if necessary, add a kernel-side debug dump instead of relying on `i2cget`

3. Recover the higher-level Windows config path.
   - determine what feeds `WF::SetConf`
   - determine what selects `WF` versus `UF`
   - determine whether this laptop consumes a board-specific config blob that
     Linux still lacks

4. Only after steps 1-3, decide whether a second PMIC behavior patch batch is
   justified.
   - likely target:
     - a more faithful `S_I2C_CTL` reproduction
     - or a board-specific PMIC init hook tied to proven runtime conditions

5. If software evidence stalls, collect electrical truth.
   - direct hardware observation of reset / powerdown / PMIC behavior is the
     cleanest remaining way to break the deadlock

## Bottom Line

We are not stuck at the beginning.

We have already moved through:

- missing board-data
- missing sensor bridge support
- missing power-on ordering
- dummy-clock suspicion
- obvious GPIO-guess space

The remaining problem is narrower than before, but harder:

- the sensor still does not wake enough to answer chip-ID reads
- and the strongest remaining explanation is that Linux still lacks some
  exact board-specific PMIC behavior or waveform that Windows performs

That is why the webcam is still not working, and that is also why the next work
should focus on PMIC state truth rather than more broad guesswork.

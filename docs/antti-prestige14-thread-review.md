# Antti Laakso Prestige 14 Patch Thread Review

## Source

- Lore thread:
  - `https://lore.kernel.org/linux-media/20260310124427.693625-1-antti.laakso@linux.intel.com/T/`
- Local thread mirror:
  - `reference/antti-patch/t.mbox`
- Local reference note:
  - `reference/antti-patch/README.md`
- Review date:
  - `2026-03-11`

This note is based on the local mailbox mirror plus the current repo evidence.
The live Lore thread URL could not be fetched directly from the current
environment during this review.

## Short Answer

The thread is relevant, but not as a direct fix for the current A2VMG blocker.

What it adds is evidence that Intel is upstreaming support for a closely
related MSI laptop that also uses:

- `OV5675`
- `TPS68470`
- `INT3472`

The part that matters most to this repo is not the already-familiar
`ipu-bridge` or basic board-data enablement. The important new point is that
the Prestige 14 series models a different `TPS68470` GPIO usage pattern:

- PMIC regular `GPIO1` / `GPIO2` are treated as the TPS68470 I2C daisy-chain
  path
- sensor GPIO exposure is instead modeled on PMIC lines `7` and `9`

That is a real reason to stay cautious about assuming that all nearby MSI
models share one universal PMIC wiring pattern.

## What The Thread Contains

Patch series subject:

- `platform: int3472: Add MSI prestige 14 AI EVO data`

Patch list:

1. `media: i2c: ov5675: Wait for endpoint`
2. `media: ipu-bridge: Add ov5675 sensor`
3. `platform: int3472: Add gpio platform data`
4. `gpio: tps68470: Add i2c daisy chain support`
5. `platform: int3472: Add MSI prestige board data`

The cover letter describes the target as an MSI Prestige 14 AI EVO laptop with
`TPS68470` powering `OV5675`, and explicitly says the GPIO patch enables the
PMIC's I2C daisy-chain functionality.

## Patch-By-Patch Review

### 1. `ov5675: Wait for endpoint`

What it does:

- moves endpoint parsing earlier in `ov5675_get_hwcfg()`
- defers probe before clock / GPIO / regulator acquisition if the endpoint is
  not ready yet

Maintainer feedback:

- concept accepted
- v1 needs cleanup because `bus_cfg` would need to be freed on the new error
  exits

Local relevance:

- low for the current A2VMG state
- this repo is already past the old missing-endpoint stage
- our current stack already proves `ipu-bridge` creates the endpoint Linux
  needs

Conclusion:

- useful upstream cleanup
- not a likely explanation for the current A2VMG `-121` chip-ID failure

### 2. `ipu-bridge: Add ov5675 sensor`

What it does:

- adds `OVTI5675` to `ipu_supported_sensors[]`

Maintainer feedback:

- positive review

Local relevance:

- historical only
- this repo already carries and validates the same idea in
  `reference/patches/ipu-bridge-ovti5675-v1.patch`

Conclusion:

- confirms the local `ipu-bridge` finding was sound
- does not address the current last-mile blocker

### 3. `platform: int3472: Add gpio platform data`

What it does:

- adds board-data plumbing from `intel_skl_int3472_tps68470` into the
  `tps68470-gpio` cell
- passes a `daisy_chain_enable` flag into the GPIO driver

Maintainer feedback:

- acceptable in principle
- Bartosz and Dan both suggested a software-node/property-based variant as a
  cleaner upstream shape than new public platform data

Local relevance:

- this is the mechanical part that would let us test a daisy-chain branch
  locally

Conclusion:

- relevant if we want a local experiment
- likely not the exact upstreamable form we would want to keep long-term

### 4. `gpio: tps68470: Add i2c daisy chain support`

What it does:

- teaches `gpio-tps68470` to configure PMIC `GPIO1` and `GPIO2` as inputs
  without pull-up when daisy-chain mode is enabled

Maintainer feedback:

- positive review

Local relevance:

- this is the main new technical idea in the thread for this repo
- it implies a board family where `GPIO1` / `GPIO2` are not being used as the
  direct sensor reset / powerdown outputs

Conclusion:

- highly relevant as evidence of a second MSI wiring pattern
- not yet evidence that this A2VMG should adopt that pattern

### 5. `platform: int3472: Add MSI prestige board data`

What it does:

- adds a new DMI entry for `Prestige 14 AI+ Evo C2VMG`
- maps:
  - `ANA` => `avdd`
  - `CORE` => `dvdd`
  - `VSIO` => `dovdd`
  - `VIO` => `1.8 V`
- enables the daisy-chain flag
- exposes sensor GPIOs on PMIC `GPIO9` and `GPIO7`

Maintainer feedback:

- Hans wanted the DMI match kept strict because a wrong PMIC configuration
  cannot be assumed safe across nearby MSI models
- Dan and Hans both pointed out that the posted dual-`reset` GPIO lookup is
  not useful as written, because `ov5675` only consumes one GPIO label there

Local relevance:

- mixed
- the regulator mapping mostly agrees with the local MSI hypothesis
- the GPIO wiring does not

Conclusion:

- useful proof that another MSI `OV5675` / `TPS68470` layout exists
- not a drop-in template for `MS-13Q3`

## What The Thread Probably Means For The Prestige 14

The thread strongly suggests Antti had a real machine and a real tested design,
not just a speculative patch series:

- the cover letter frames it as adding camera support
- reviewers engaged it as a normal board-enablement series, not as guesswork
- the daisy-chain sub-series received positive review

But the thread does not by itself prove that the exact posted `v1` text is the
final correct description:

- patch `1/5` still needs error-path rework
- patch `5/5` still has a board-data GPIO issue called out in review

So the right reading is:

- the underlying hardware pattern is likely real
- the exact `v1` series is still under review and not final

## Comparison With The Current A2VMG State

### What already overlaps

These parts line up with what this repo already proved:

- `OVTI5675` belongs in `ipu-bridge`
- `TPS68470` board data is required
- `ANA` / `CORE` / `VSIO` are the right broad rail classes
- this is still an MSI-specific `INT3472` case, not a generic upstream board

### What differs

The important difference is GPIO modeling.

Current local A2VMG working hypothesis:

- PMIC `GPIO1` / `GPIO2` are the first candidate camera-control lines
- current board-data maps them as:
  - `reset` => `gpio.1`
  - `powerdown` => `gpio.2`

Prestige 14 thread model:

- PMIC `GPIO1` / `GPIO2` are used for daisy-chain mode
- sensor GPIO exposure is modeled on PMIC `GPIO9` and `GPIO7`

That does not prove the A2VMG hypothesis is wrong, but it does prove we should
not assume all nearby MSI models share one universal PMIC wiring pattern.

## Comparison With Local Experiments

The thread now lines up with the local experiment history more clearly than it
did before `exp13` through `exp17`.

### What already has a local equivalent

Patch `2/5` `ipu-bridge: Add ov5675`:

- already covered by the repo-local tested baseline
- local equivalent:
  - `reference/patches/ipu-bridge-ovti5675-v1.patch`

Patch `3/5` `platform: int3472: Add gpio platform data`:

- already covered mechanically by the local daisy-chain experiment plumbing
- local equivalents:
  - `exp12` first proved the daisy-chain flag can be plumbed and exercised
  - `exp13` then proved Linux can leave `GPIO1` / `GPIO2` isolated once the
    sensor lookup stops exporting them

Patch `4/5` `gpio: tps68470: Add i2c daisy chain support`:

- already covered mechanically and behaviorally by the local daisy-chain
  branch set
- local equivalents:
  - `exp12` showed the daisy-chain input-mode setup lands but immediately
    collides with the old `GPIO1` / `GPIO2` sensor lookup
  - `exp13` showed the same daisy-chain setup can stay intact on the clean
    branch

Patch `5/5` MSI board data:

- partially covered, but not faithfully replicated
- local equivalents:
  - `exp14` proved `GPIO9` is active
  - `exp15` proved `GPIO7` is active
  - `exp16` proved `GPIO9` and `GPIO7` can both be active together
  - `exp17` proved a later PMIC-side event on that clean remote-line branch
    can be safe

### What still differs from Antti's posted series

Patch `1/5` `ov5675: Wait for endpoint`:

- no direct local equivalent yet
- probably low-signal for this repo because the current A2VMG branch is
  already well past the missing-endpoint stage

Patch `5/5` GPIO lookup shape:

- Antti's posted `v1` uses:
  - `GPIO_LOOKUP_IDX("tps68470-gpio", 9, "reset", 0, GPIO_ACTIVE_LOW)`
  - `GPIO_LOOKUP_IDX("tps68470-gpio", 7, "reset", 1, GPIO_ACTIVE_LOW)`
- the local daisy-chain branch uses:
  - `GPIO9` as `reset`
  - `GPIO7` as `powerdown`
- this is not because the local branch proved Antti wrong
- it is because current `ov5675` only consumes one useful `reset` descriptor,
  and that exact dual-`reset` issue was also called out in review

PMIC `VSIO` handling:

- this is the biggest remaining behavioral gap
- Antti's archived series does not carry the local `BIT(1)`-only `VSIO`
  workaround
- all local `exp13` through `exp17` runs intentionally kept the `exp10`
  regulator behavior:
  - keep `BIT(1)` in the early regulator path
  - do not assert early `BIT(0)` there
- `exp17` only re-tested a later GPIO-phase `BIT(0)` on top of that clean
  branch
- that means the cleanest untested Antti-parity discriminator is now:
  - standard `VSIO` enable on top of daisy-chain isolation

Regulator-set shape:

- Antti's posted board data is simpler than the local MSI candidate:
  - no `VCM`, `AUX1`, or `AUX2` regulator setup
  - `VIO` is not modeled as local `always_on`
- the local board-data patch still carries those extra supplies
- this is real drift from Antti's series, but it is lower-signal than the
  untested standard-`VSIO` difference because it changes several variables at
  once

## What `exp17` changed in this comparison

Before `exp17`, the simplest reading was:

- Antti's daisy-chain routing differs from the old local `GPIO1` / `GPIO2`
  model
- but the remaining PMIC behavior gap was still ambiguous

After `exp17`, the narrower reading is:

- the local branch now already matches Antti's broad GPIO routing shape much
  more closely:
  - `GPIO1` / `GPIO2` isolated for daisy-chain
  - remote activity visible on `GPIO9` and `GPIO7`
- the remaining important difference is no longer just the GPIO model
- the remaining important difference is that the local branch still depends on
  the `exp10` early `BIT(1)`-only `VSIO` workaround

That is why `exp17` should be read as:

- strong evidence that a later `BIT(0)` is not categorically toxic
- but not a faithful reproduction of Antti's PMIC behavior

## Recommended Next Comparison Step

If the goal is to compare the local A2VMG branch against Antti's approach more
faithfully, the next step should be narrow:

1. keep the clean daisy-chain-isolated branch
2. keep the currently observed remote-line branch on `GPIO9` / `GPIO7`
3. remove the local `BIT(1)`-only `VSIO` workaround
4. restore standard `VSIO` enable behavior

Why this is the highest-signal next test:

- it isolates the biggest remaining Antti-vs-local delta
- it does not bundle in the lower-signal endpoint-wait patch, which the local
  branch likely no longer needs
- it does not bundle in the broader regulator-set simplification, which would
  muddy interpretation
- it directly answers whether daisy-chain isolation changes the meaning of the
  old early `BIT(0)` wedge

So the next best experiment is not "copy all five Antti patches at once."

It is:

- standard `VSIO` enable plus clean daisy-chain isolation

If that still wedges immediately, the local `BIT(1)`-only workaround remains a
real board-specific requirement candidate. If it becomes safe or changes the
sensor failure shape, then the next branch can compare exact GPIO consumer
shape or regulator simplification on top of that result.

## How Sure We Are About `GPIO1` / `GPIO2` On This A2VMG

The confidence split is uneven:

- moderate confidence that `GPIO1` / `GPIO2` are involved in the relevant
  board-specific control path at all
- lower confidence that we know their exact semantic role
- still lower confidence that the current Linux timing / phase on those lines
  matches Windows

Why `GPIO1` / `GPIO2` are still the best current local candidate:

- Windows `WF` analysis clearly touches `GPCTL1A` and `GPCTL2A`
- the current local interpretation still matches the strongest Windows-side
  evidence

Why the semantic mapping is still uncertain:

- the Windows disassembly does not prove `GPIO1 = reset` and
  `GPIO2 = powerdown`
- earlier role-swap experiments were lower-signal than they first looked,
  because current Linux `ov5675` drives both lines in lockstep
- the latest late-hook experiment still leaves open:
  - wrong phase
  - wrong signal

So the current repo position should stay:

- `GPIO1` / `GPIO2` remain the leading local pair
- their exact job is still not fully proven
- the remaining problem is now more likely later PMIC behavior and exact
  waveform truth than another blind label swap

## Does The Thread Change The Current Blocker Assessment?

Not much.

The repo is already beyond:

- basic sensor enumeration
- missing endpoint creation
- missing first-pass board data

The current best checkpoint is still:

- `BIT(1)`-only `S_I2C_CTL`
- no old PMIC timeout storm
- sensor reaches chip-ID reads
- chip-ID reads fail with `-121`

So this thread does not replace the current leading interpretation that the
remaining blocker is late PMIC / sensor wake-up behavior.

What it does change is the confidence model around GPIOs:

- it makes it less safe to assume MSI reused one PMIC GPIO pattern across all
  similar models

## If We Want To Try The Daisy-Chain Approach Locally

### Mechanical Difficulty

The code change is relatively easy.

This repo already documents that the relevant files sit in the module-only
iteration path:

- `drivers/platform/x86/intel/int3472/`
- `drivers/gpio/gpio-tps68470.c`

That means a daisy-chain branch does not normally require a full kernel image
rebuild. It fits the same fast iteration path as the other camera-adjacent
module experiments.

### Hypothesis Difficulty

The hard part is not writing the patch. The hard part is deciding what a
credible local test actually is.

Why:

- the Antti thread uses `GPIO1` / `GPIO2` for daisy-chain mode
- the current A2VMG model uses `GPIO1` / `GPIO2` as direct camera-control lines

Those two models compete with each other.

So a faithful A2VMG daisy-chain test would need more than blindly copying the
Prestige 14 patch. It would need an explicit answer to at least one of these:

1. Are `GPIO1` / `GPIO2` really not sensor control lines on this board?
2. If `GPIO1` / `GPIO2` are for daisy-chain, where are the actual sensor
   control lines?
3. Does this board use daisy-chain without any Linux-visible second control
   line that we currently model as `powerdown`?

### Practical Local Experiment Shapes

#### Lowest-effort experiment

- add daisy-chain enable plumbing
- enable it for `MS-13Q3`
- keep everything else close to the current stack
- instrument whether later `ov5675` GPIO requests simply override the early
  daisy-chain configuration

Pros:

- easy to stage
- likely only a small patch touching `int3472` and `gpio-tps68470`

Cons:

- weak test
- may mostly prove that two incompatible models collide in Linux

#### Better experiment

- add daisy-chain enable plumbing
- create a dedicated `MS-13Q3` experiment branch that stops treating
  `GPIO1` / `GPIO2` as the primary sensor-control outputs
- observe whether the failure shape changes materially

Pros:

- tests the actual competing hypothesis

Cons:

- riskier and less constrained
- may remove control lines the current local branch still relies on

### Recommended Verdict On Ease

If the question is "can we code it quickly?", the answer is yes.

If the question is "can we run a clean, high-confidence daisy-chain test on
this A2VMG with very little ambiguity?", the answer is no.

The implementation work is easy.
The experimental interpretation is not.

## Suggested Local Rule If We Pursue It

If this branch is attempted, it should be treated as:

- a targeted hypothesis test
- module-only if possible
- clearly separate from the current `exp10` PMIC baseline

It should not replace the current baseline by default unless it produces one of
these concrete changes:

- a different `S_I2C_CTL` readback pattern
- a different GPIO request / reconfiguration pattern
- a better-than-`-121` sensor identify result
- a successful `ov5675` bind

The repo now stages that lowest-effort local version as `exp12`:

- keep the current `MS-13Q3` `GPIO1` / `GPIO2` lookup model
- enable Antti-inspired daisy-chain mode on those same pins
- log whether Linux later re-drives them out of input mode
- keep it clearly separate from the verified `exp10` baseline

The first local `exp12` run answered that narrow question directly:

- the daisy-chain input-mode setup landed on both lines
- Linux then immediately drove both lines back to output mode
- so this lowest-effort cross-check is negative as a fix, but confirms that
  the current `MS-13Q3` lookup model and the Antti daisy-chain model are
  directly competing

## Bottom Line

The Antti Prestige 14 thread is worth preserving because it adds a plausible
second MSI `TPS68470` wiring model:

- daisy-chain on `GPIO1` / `GPIO2`
- sensor GPIOs elsewhere

That is important context for this repo.

But it does not directly solve the current A2VMG blocker, and a local
daisy-chain trial is easy to implement only in the narrow mechanical sense.
The real challenge is that it competes with the current `GPIO1` / `GPIO2`
model rather than simply extending it.

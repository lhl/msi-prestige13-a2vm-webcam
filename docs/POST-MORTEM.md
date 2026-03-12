# Post-Mortem: What We Missed Before Antti's Working Path

Updated: 2026-03-12

This note captures the hindsight answer to the repo question:

- what did we miss by the March 9 checkpoint
- what did Antti Laakso's later working Prestige 14 path get right
- what did `exp12` through `exp18` prove on this `MS-13Q3` machine

It is a synthesis across:

- `docs/20260309-status-report.md`
- `docs/antti-prestige14-thread-review.md`
- `docs/pmic-followup-experiments.md`
- the recorded `exp12` through `exp18` run outputs

## Short Answer

By March 9, the repo had already solved the broad platform problems:

- `INT3472` / `TPS68470` board data
- `OVTI5675` discovery in `ipu-bridge`
- `ov5675` power-on ordering
- the narrow failure surface around `S_I2C_CTL` `0x43`

What it still had wrong was the board model behind that failure.

The key miss was treating PMIC regular `GPIO1` / `GPIO2` as the likely direct
sensor control lines. Antti's working path on the closely related Prestige 14
instead modeled:

- `GPIO1` / `GPIO2` as the TPS68470 I2C daisy-chain path
- remote sensor control on `GPIO9` / `GPIO7`

Once the local branch was changed to match that topology, the earlier
`S_I2C_CTL BIT(0)` story also changed shape:

- the bad early `BIT(0)` write on the old branch was not proof that `BIT(0)`
  is universally toxic
- it was evidence that Linux was asserting it in the wrong phase and on top of
  the wrong GPIO ownership model

`exp18` then proved the decisive point:

- standard regulator-side `VSIO` enable (`S_I2C_CTL = 0x03`) is safe on the
  clean daisy-chain branch
- the old timeout storm does not return
- `ov5675` binds into the media graph

So the main thing Antti got right was not a secret voltage value. It was the
board-level GPIO topology.

## What We Already Had Right By 2026-03-09

The repo should not under-credit the March 9 state. By that point it had
already proved:

- IPU7 support was present enough to enumerate hardware and load firmware
- `OVTI5675:00` was the correct sensor path
- MSI-specific `INT3472` / `TPS68470` board data was required
- `OVTI5675` support in `ipu-bridge` was required
- the old clean-boot `dvdd` timeout was gone after the serial power-on change
- the PMIC clock path was real, not a dummy-clock artifact
- the remaining failure had narrowed to sensor identification and PMIC
  behavior around `S_I2C_CTL`

That was real progress. The repo had already moved the problem from "Linux
does not know the hardware" to "Linux is still modeling some board-specific
behavior incorrectly."

## What Led Us Astray

The wrong turn was understandable. It did not come from inventing evidence out
of thin air. It came from over-committing to one interpretation of real
Windows-side evidence.

### 1. The Windows evidence really did point at `GPIO1` / `GPIO2`

The strongest pre-Antti Windows and ACPI evidence said:

- this machine's active path is `WF` / `LNK0`, not `UF` / `LNK1`
- `Tps68470VoltageWF::IoActive_GPIO` touches `GPCTL1A` `0x16` and `GPCTL2A`
  `0x18`
- those registers are Linux `GPIO1` and `GPIO2`

That made it rational to keep `WF` / `LNK0` as the primary model and to treat
`GPIO1` / `GPIO2` as important lines.

The overreach was the next step:

- we treated "Windows touches `GPIO1` / `GPIO2`" as close to
  "Linux should export those same two lines directly as sensor `reset` and
  `powerdown` outputs"

The Windows disassembly did not actually prove that second claim. It proved
involvement, not ownership semantics.

### 2. We optimized for the smallest experiments inside that model

Once `GPIO1` / `GPIO2` were treated as the leading direct-control pair, the
next experiments also stayed inside that model:

- role swap
- polarity variants
- staged GPIO release variations
- increasingly detailed `S_I2C_CTL` experiments on top of the same ownership
  assumption

That was a pragmatic choice at the time:

- the experiments were small
- they were cheap to stage
- they were easy to compare against a stable baseline
- they matched the strongest local evidence we had before the Antti thread

With hindsight, the real issue was not that we failed to run enough tests. It
was that the early test space stayed trapped inside one wrong board model.

### 3. Some of the early sweep space was lower-signal than we realized

The repo later proved that current `ov5675` drives its two logical GPIOs in
lockstep on the old branch.

That means several early experiments looked broader than they really were:

- a label-only role swap was close to an electrical no-op
- a one-line polarity tweak still left the same broad two-line ownership model
  in place
- extra attention on `S_I2C_CTL` could make the problem look like a register
  recipe issue even while the underlying line topology was still wrong

So the problem was not simply "we should have done a bigger sweep." The more
accurate hindsight is:

- we should have broken the model earlier
- specifically by testing whether Linux should stop owning `GPIO1` / `GPIO2`
  at all

### 4. Missing observability pushed us toward the wrong layer

Another bias was tooling.

Post-boot PMIC dumping was not usable, so the most reliable observations came
from:

- Windows disassembly
- kernel-side focused logging around `S_I2C_CTL`
- the Linux-visible GPIO paths we were already modeling

That made it easier to keep asking:

- "what exact PMIC write is missing?"

instead of asking the more disruptive question:

- "are we even driving the right lines?"

Antti's thread helped because it forced that second question back onto the
table.

### 5. `exp11` made the symptom story feel primary, and `exp12` was
under-weighted

The `exp11` result was dramatic:

- the later modeled `BIT(0)` event re-wedged PMIC access
- the timeout storm returned immediately

That made the PMIC symptom look like the main problem again, even after the
repo had already started suspecting a higher-level modeling gap.

Then `exp12` was run only as a low-effort Antti-style cross-check layered on
top of the existing `GPIO1` / `GPIO2` sensor lookup. As a direct fix, it was
negative. But that was not its most important result.

Its most important result was the collision:

- the daisy-chain configuration really landed on `GPIO1` / `GPIO2`
- Linux then immediately reclaimed those same lines as outputs

That should have immediately downgraded the incumbent "`GPIO1` / `GPIO2` are
direct sensor outputs" model from leading explanation to challenged
assumption.

Instead, the process still treated the old model as more presumptively correct
than it deserved. The key correction only came with the next reframing:

- stop asking whether the low-effort Antti patch "fixes the camera"
- ask whether Linux should stop owning `GPIO1` / `GPIO2` at all

That is why `exp13` matters more than `exp12` as a turning point:

- `exp12` exposed the board-model conflict
- `exp13` was the first experiment that actually tested the ownership question

## What We Missed

### 1. Wrong ownership model for `GPIO1` / `GPIO2`

The biggest miss was assuming that the current `MS-13Q3` Linux board data
should keep exporting PMIC regular `GPIO1` / `GPIO2` directly to the sensor as
`reset` and `powerdown`.

That assumption shaped several lower-level experiments:

- role swaps on the same two lines
- polarity tests on the same two lines
- staged `ov5675` release sequencing on the same two lines
- interpretation of later PMIC wedges as "register behavior" first

Antti's Prestige 14 series pointed at a different model:

- `GPIO1` / `GPIO2` belong to the TPS68470 daisy-chain setup
- Linux should expose remote sensor control elsewhere

`exp12` showed the conflict directly: the Antti-style daisy-chain setup landed,
but the current local sensor lookup immediately reclaimed the same lines as
outputs. That was the clearest proof that the old and new models were mutually
exclusive, not additive.

### 2. Wrong interpretation of `S_I2C_CTL BIT(0)`

By March 9 the repo had correctly identified that early `BIT(0)` assertion on
the old branch could wedge PMIC access.

The mistake was interpreting that too broadly.

The later clean-branch experiments showed the narrower truth:

- early `BIT(0)` on top of the old `GPIO1` / `GPIO2` model was bad
- later `BIT(0)` on the clean daisy-chain branch was safe
- full standard `VSIO` enable was also safe once the board topology was fixed

So the right lesson is not "never assert `BIT(0)`." The right lesson is
"`BIT(0)` was being exercised in the wrong board model and phase."

### 3. Some early GPIO experiments were lower-signal than they looked

The repo later documented that current `ov5675` drives `reset_gpio` and
`powerdown_gpio` in lockstep on the old branch. That means a pure role swap on
the same two physical lines is close to an electrical no-op unless polarity or
timing also changes.

With hindsight, that means some March 9 "negative" GPIO experiments answered
less than they first appeared to answer. They were still worth running, but
they were not testing an independent board-topology hypothesis.

## What Antti Effectively Got Right

Antti's thread should be read as strong evidence of a working nearby MSI
topology, not as a verbatim drop-in board-data template for this laptop.

The most important points it got right were:

- daisy-chain mode on `GPIO1` / `GPIO2`
- remote sensor control on `GPIO9` / `GPIO7`
- skepticism toward the assumption that nearby MSI models all share one
  universal `TPS68470` GPIO layout

The repo also learned an important limit from the same thread:

- Antti's posted dual-`reset` GPIO lookup could not be copied literally into
  current local `ov5675`, because that driver does not consume the descriptors
  the same way

So Antti's work gave the correct broad wiring model, but not a line-for-line
final patch to transplant unchanged.

## What We Got Right And Wrong

### What we got right

- We correctly kept `WF` / `LNK0` as the primary active-path model.
- We correctly identified `OVTI5675:00` and the MSI `INT3472` /
  `TPS68470` board-data gap.
- We correctly narrowed the remaining failure to PMIC behavior around
  `S_I2C_CTL` and sensor identification rather than broad IPU bring-up.
- We correctly treated the Windows driver as a real source of board-specific
  behavior, not as an irrelevant vendor blob.

### What we got wrong

- We promoted `GPIO1` / `GPIO2` from "important in Windows" to "must be the
  direct Linux sensor-control outputs" too quickly.
- We treated some low-delta `GPIO1` / `GPIO2` experiments as stronger
  discriminators than they really were.
- We over-read the first bad `BIT(0)` result as a property of the bit itself
  rather than of the surrounding branch conditions.
- We spent too much of the early sweep budget refining one model before doing a
  clean ownership-removal test.

## What `exp12` Through `exp18` Proved

### `exp12`

- the Antti-inspired daisy-chain setup really lands on `GPIO1` / `GPIO2`
- the old `MS-13Q3` sensor lookup immediately re-drives those same lines as
  outputs

Interpretation:

- the old local board-data model and the daisy-chain model are in direct
  conflict

### `exp13`

- once Linux stops exporting `GPIO1` / `GPIO2` to `OVTI5675:00`, they stay in
  daisy-chain input mode during the observed probe window

Interpretation:

- the clean daisy-chain branch is real, not just theoretical

### `exp14` to `exp16`

- `GPIO9` is an observed remote control line
- `GPIO7` is also an observed remote control line
- both can be active together on the clean daisy-chain branch

Interpretation:

- the remote-line half of the Antti model is materially present on this laptop

### `exp17`

- a later PMIC-side `BIT(0)` event on the clean remote-line branch reads back
  cleanly as `0x03`
- the old timeout storm does not return

Interpretation:

- `BIT(0)` is not categorically toxic
- the old wedge depended on the earlier wrong branch conditions

### `exp18`

- standard regulator-side `VSIO` enable reads back cleanly as `0x03`
- the old timeout storm still does not return
- `ov5675` binds into the media graph
- `/dev/v4l-subdev*` nodes appear

Interpretation:

- the main Antti-vs-local PMIC question is answered
- the decisive missing piece was the board topology, not a special local
  `BIT(1)`-only workaround

## What Antti's Path Did Not Explain By Itself

Antti's thread explains the kernel-side board model that got the local branch
to a bound sensor.

It did not, by itself, answer the later userspace integration problems:

- the IPU7 media graph still needed explicit `media-ctl` link enable and pad
  format alignment before raw capture worked
- direct plug-and-play `/dev/video0` usage still remains weaker than the
  `libcamera` / PipeWire path

That later capture work is a separate lesson from the GPIO/PMIC post-mortem.

## Process Lessons

### 1. Treat related upstream board series as wiring evidence

For this class of hardware, a nearby upstream board-enablement series is not
just "another patch to try." It is evidence about likely board topology and
line ownership.

### 2. Distinguish register symptoms from board-model causes

When a PMIC register write wedges the bus, the first question should be:

- is Linux exercising the right hardware path at all

and not only:

- what exact bit pattern should we try next

### 3. Prefer experiments that change ownership or topology before micro-tuning

Once the remaining uncertainty is "which lines actually belong to the sensor,"
micro-experiments on those lines can be misleading. The higher-value test is
often the one that removes Linux ownership from the candidate lines entirely
and watches what still moves.

### 4. Force a fresh-context challenge pass after a collision result

`exp12` should have been a stronger process trigger than it was.

Once the repo had direct evidence that:

- the daisy-chain input-mode setup really landed
- Linux immediately reclaimed the same lines as outputs

the incumbent "`GPIO1` / `GPIO2` are direct sensor GPIOs" model should have
been downgraded immediately.

Instead, the process still needed external reframing and a fresh review pass to
move decisively to `exp13`.

Next time, a result like `exp12` should automatically trigger:

- a fresh-context summary of what is proven, inferred, and merely assumed
- one explicit alternative model
- one model-breaking next experiment
- and, if available, a second-pass reviewer or model that did not build the
  original hypothesis

That is not redundancy for its own sake. It is protection against hypothesis
lock-in.

## What We Should Do Differently Next Time

### 1. Keep an explicit evidence / inference / assumption ledger

For reverse-engineering notes, each major claim should be labeled as one of:

- direct evidence
- inference from evidence
- working assumption

The key March 9 mistake was promoting:

- "Windows `WF::IoActive_GPIO` touches `GPCTL1A` / `GPCTL2A`"

from direct evidence into:

- "Linux should export `GPIO1` / `GPIO2` as direct sensor `reset` /
  `powerdown`"

which was only an inference.

### 2. Define the falsifier before spending more experiment budget

Every major branch should state up front:

- what specific result would falsify the current model
- what branch should follow if it is falsified

For the `GPIO1` / `GPIO2` model, the better falsifier would have been:

- "if an Antti-style daisy-chain setup lands on those lines and Linux then
  immediately reclaims them, test ownership removal next"

That would have shortened the path from `exp12` to `exp13`.

### 3. Treat "negative as a direct fix" separately from "informative about the
model"

`exp12` was negative as a direct fix, but highly positive as model evidence.

That distinction should be explicit in future experiment reviews:

- did the branch fail to solve the problem?
- did it still falsify or weaken the incumbent model?

If the answer to the second question is yes, the next step should follow the
new model evidence even if the branch did not fix the device.

### 4. Treat low-delta variants as budget-limited

Role swaps, one-line polarity tweaks, and similar within-model micro-variants
are useful, but they should have an explicit cap.

A better rule for this repo would be:

- after one or two low-delta negative variants, stop and run a model-breaking
  experiment instead of a third small variant

That would have reduced time spent inside the wrong `GPIO1` / `GPIO2`
ownership model.

### 5. Prefer ownership-removal tests when evidence shows involvement, not role

When reverse-engineering evidence proves that a line is involved but does not
prove how it is owned, one of the earliest tests should be:

- remove Linux ownership and observe what still moves

That is what `exp13` finally did, and it was more discriminating than several
earlier within-model tweaks.

### 6. Require a challenge pass when a hypothesis becomes sticky

If a branch remains the "leading model" mainly because it keeps getting
reinterpreted after negative results, force an explicit challenge pass.

For this repo, that should mean:

- summarize the current model in one short note
- summarize the strongest competing model
- ask what evidence would make the incumbent model collapse
- if available, get a second review from a fresh context or different model

This is the meta-fix for the `exp12` problem: once a model starts defending
itself by inertia, the process must inject outside pressure.

### 7. Record "what would change our mind?" in the plan itself

The active plan should not only list next steps. It should also record:

- what result would downgrade the current leading hypothesis
- what result would promote the alternate one

That makes it harder for a repo to quietly treat a working assumption as if it
were already proven fact.

## Bottom Line

The repo did not miss the broad Linux support story. It missed the correct
board-level camera-control topology.

In hindsight, the main error by March 9 was:

- assuming `GPIO1` / `GPIO2` were still the direct sensor control lines that
  Linux should export and drive

What Antti got right, and what `exp12` through `exp18` later confirmed, was:

- `GPIO1` / `GPIO2` should be left to the TPS68470 daisy-chain path
- the real Linux-visible control activity is on remote lines `GPIO9` / `GPIO7`
- once that model is in place, standard `VSIO` becomes safe and the sensor
  binds

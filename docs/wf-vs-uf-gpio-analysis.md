# `WF` vs `UF` GPIO Analysis

Updated: 2026-03-09

## Question

Does the Windows `iactrllogic64.sys` evidence justify pivoting away from the
current Linux `GPIO1` / `GPIO2` model toward a different PMIC line such as
Linux `gpio.4`?

## Short Answer

Not yet.

The Windows package clearly contains both `WF` and `UF` `TPS68470` helper
families, and the `UF` path does manipulate `GPDO` bit `0x10`, which would be
Linux `gpio.4`. But the local ACPI evidence still ties this machine's active
sensor path to `WFCS -> LNK0`, not `UFCS -> LNK1`. The best-supported next
Linux experiments are still:

- `GPIO1` / `GPIO2` role swap
- `GPIO1` / `GPIO2` polarity experiments
- remaining `WF`-side timing or sequencing detail

Blindly switching to a `gpio.4` design would be a hypothesis jump, not an
evidence-driven next step.

## Local ACPI Result

From `reference/acpi/20260308T004459-unknown-host/dsl/ssdt1.dsl`:

- `WFCS = "\\_SB.PC00.LNK0"`
- `UFCS = "\\_SB.PC00.LNK1"`

From `reference/acpi/20260308T004459-unknown-host/dsl/ssdt17.dsl`:

- when `C0TP > One`, the `LNK0` path depends on `\_SB.CLP0`

From the already-captured local Linux and ACPI evidence:

- the live sensor is `OVTI5675:00`
- the live active PMIC companion is `INT3472:06`
- the companion device is `CLP0`
- the active sensor path is `LNK0`

That keeps this laptop aligned with the `WF` / `LNK0` branch unless stronger
evidence later proves otherwise.

## Windows Driver Result

### `CrdG2TiSensor::SensorPowerOn`

From `disasm-sensor-g2ti-poweron.txt`:

- `SensorPowerOn` first calls `IoActive_IO` at `0x140013014`
- it then branches into either:
  - `0x140013868` => `Tps68470VoltageWF::PowerOn`
  - `0x14001357c` => `Tps68470VoltageUF::PowerOn`
- it later calls `IoActive_GPIO` at `0x140012dd4`

This means the Windows package supports at least two board-helper families for
similar camera designs.

### `WF` path evidence

From `disasm-voltage-wf-ioactive-gpio.txt`:

- `IoActive_GPIO` reads and writes registers `0x16` and `0x18`
- those map to Linux `GPCTL1A` and `GPCTL2A`
- the function clears mode bits with `and ... , 0xfc`, which matches Linux
  `TPS68470_GPIO_MODE_MASK`

That is strong evidence that the `WF` path uses PMIC regular GPIOs `1` and `2`
as camera-control outputs.

### `UF` path evidence

From `disasm-voltage-uf-setvactl.txt`:

- `SetVACtl` reads register `0x27`
- it conditionally sets or clears bit `0x10`
- it writes the result back to `0x27`

Linux maps register `0x27` to `GPDO`, and `BIT(4)` there is regular
`gpio.4`. So the Windows package really does contain a board/helper path that
uses a different PMIC GPIO line from the currently-modeled `GPIO1` / `GPIO2`
pair.

## Linux Correlation

From local `gpio-tps68470.c`:

- regular GPIO offsets `0..6` map to:
  - `gpio.0`
  - `gpio.1`
  - `gpio.2`
  - `gpio.3`
  - `gpio.4`
  - `gpio.5`
  - `gpio.6`
- `GPDO` uses `BIT(offset)` for those regular GPIOs

From the current local MSI test board data:

- `reset` => `gpio.1`, active low
- `powerdown` => `gpio.2`, active low

So the current Linux hypothesis still matches the strongest `WF`-side evidence,
but it remains only a first approximation of the Windows behavior.

## Practical Conclusion

The Windows package proves two important things:

1. there is more than one MSI / Intel `TPS68470` camera wiring pattern in play
2. our current Linux model is still simplified compared with Windows

But for this specific laptop, the current evidence still supports this order of
operations:

1. keep `WF` / `LNK0` as the primary model
2. test `GPIO1` / `GPIO2` role swap
3. test `GPIO1` / `GPIO2` polarity variants
4. if those fail, revisit whether this board is actually selecting a narrower
   `UF`-style helper path or needs an extra PMIC GPIO such as Linux `gpio.4`

## Current Next Step

Use the clean-boot identify-timeout result as the baseline:

- `chip id read attempt 1/5 failed: -110`
- `... 5/5 failed: -110`

Then prefer the next smallest Linux experiments in this order:

- board-data `reset` / `powerdown` role swap
- board-data polarity experiments
- remaining `WF`-side sequencing or delay detail

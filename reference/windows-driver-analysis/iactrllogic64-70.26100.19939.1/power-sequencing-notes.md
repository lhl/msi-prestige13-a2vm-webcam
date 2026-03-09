# iactrllogic64 Power Sequencing Notes

This note captures the concrete `TPS68470` power-path behavior recovered from
`iactrllogic64.sys` for the MSI `OV5675` package. It complements the raw
`disasm-*.txt` windows in this directory.

## Main Result

- The Windows driver contains more than simple PMIC rail enables for this board.
- The `WF` path carries a concrete five-voltage configuration tuple:
  - `VD` = `1050 mV`
  - `VA` = `2800 mV`
  - `VIO` = `1800 mV`
  - `VCM` = `2800 mV`
  - `VSIO` = `1800 mV`
- The `WF` initialize path programs PMIC value registers before the later
  enable/control helpers run.
- The `WF` `S_I2C_CTL` path is staged rather than a single generic enable write.
- `CrdG2TiSensor::SensorPowerOn` still layers `IoActive_IO`, a `WF`/`UF`
  power-on branch, and later `IoActive_GPIO`.
- The remaining Linux gap is therefore narrower and more concrete than before:
  value-register programming, `S_I2C_CTL` behavior, and exact GPIO semantics.

## Corrections

- The earlier extracted `poweron` / `poweroff` files were partly mislabeled.
- Regeneration on `2026-03-09` corrected the captured function windows to match
  method-string cross-references:
  - `disasm-voltage-uf-poweroff.txt` => `0x140013214`
  - `disasm-voltage-wf-poweroff.txt` => `0x1400133e8`
  - `disasm-voltage-uf-poweron.txt` => `0x14001357c`
  - `disasm-voltage-wf-poweron.txt` => `0x140013868`

## Files

- `disasm-voltage-wf-constructor.txt`
- `disasm-voltage-wf-initialize.txt`
- `disasm-voltage-wf-setconf.txt`
- `disasm-voltage-wf-poweron.txt`
- `disasm-voltage-wf-poweroff.txt`
- `disasm-voltage-wf-ioactive.txt`
- `disasm-voltage-wf-ioactive-io.txt`
- `disasm-voltage-wf-ioactive-gpio.txt`
- `disasm-voltage-wf-setvsioctl-gpio.txt`
- `disasm-voltage-wf-setvsioctl-io.txt`
- `disasm-sensor-g2ti-poweron.txt`
- `disasm-sensor-g2ti-poweroff.txt`
- `disasm-sensor-g2ti-setgpiooutput.txt`

## Concrete Behavior

### Function Mapping

Method-string cross-references now line up like this:

- `0x140013214` logs `Tps68470VoltageUF::PowerOff`
- `0x1400133e8` logs `Tps68470VoltageWF::PowerOff`
- `0x14001357c` logs `Tps68470VoltageUF::PowerOn`
- `0x140013868` logs `Tps68470VoltageWF::PowerOn`
- `0x140012de0` logs `Tps68470VoltageWF::IoActive_GPIO`
- `0x1400148e4` logs `Tps68470VoltageWF::SetVSIOCtl_GPIO`
- `0x140014a7c` logs `Tps68470VoltageWF::SetVSIOCtl_IO`

That matters because the `WF` path, not just the generic sensor wrapper, now has
source-backed board configuration details.

### `Tps68470VoltageWF` Constructor

Recovered from `disasm-voltage-wf-constructor.txt`:

- entry point: `0x140012764`
- zeroes the refcount/state field at `[this + 0x14]`
- seeds these 16-bit fields:
  - `[this + 0x08] = 0x041a` => `1050 mV`
  - `[this + 0x0a] = 0x0af0` => `2800 mV`
  - `[this + 0x0c] = 0x0708` => `1800 mV`
  - `[this + 0x0e] = 0x0af0` => `2800 mV`
  - `[this + 0x10] = 0x0708` => `1800 mV`

Interpretation:

- the `WF` helper object itself carries a default board voltage tuple
- Windows is not relying only on later boolean rail enables

### `Tps68470VoltageWF::SetConf`

Recovered from `disasm-voltage-wf-setconf.txt`:

- entry point: `0x140013ab8`
- copies five 16-bit values from the input config blob into the same object
  fields used by the constructor
- copy order:
  - input `+0x02` => object `+0x0a`
  - input `+0x06` => object `+0x0e`
  - input `+0x04` => object `+0x0c`
  - input `+0x08` => object `+0x10`
  - input `+0x00` => object `+0x08`

Implication:

- those object fields are live configuration values, not dead defaults or flags
- the same five-voltage tuple can be board-specific data supplied from a higher
  config layer

### `Tps68470VoltageWF::Initialize`

Recovered from `disasm-voltage-wf-initialize.txt`:

- entry point: `0x1400129d8`
- converts the stored millivolt fields into PMIC register values and writes them
  before later power-on helpers run
- register writes observed in order:
  - object `+0x0a` => register `0x41`
  - object `+0x10` => register `0x40`
  - object `+0x08` => register `0x42`
  - object `+0x0e` => register `0x3c`
  - object `+0x0c` => register `0x3f`

Linux correlation:

- `0x41` => `VAVAL`
- `0x40` => `VSIOVAL`
- `0x42` => `VDVAL`
- `0x3f` => `VIOVAL`
- `0x3c` is the value register used by the Windows `VCM` path

Implication:

- Windows programs at least `VA`, `VSIO`, `VD`, `VCM`, and `VIO` value registers
  explicitly on this path
- Linux currently models the MSI board mainly as regulator consumers and GPIOs;
  this initialization step is not represented as a board-specific source artifact

### `Tps68470VoltageWF::PowerOn`

Recovered from `disasm-voltage-wf-poweron.txt`:

- entry point: `0x140013868`
- first calls `0x1400129d8` (`WF` initialize)
- then calls:
  - `0x140013ce0`
  - `0x14001436c`
  - `0x140014030`
- logs steps `0x39`, `0x3a`, `0x3b`, and final status `0x3c`

Implication:

- the `WF` power-up path begins with the value-register programming step above
- this is stronger evidence than the earlier "some helper toggles exist" read

### `Tps68470VoltageWF::IoActive_GPIO`

Recovered from `disasm-voltage-wf-ioactive-gpio.txt`:

- entry point: `0x140012de0`
- reads and rewrites registers `0x16` and `0x18`
- both writes clear the low mode bits with `and ... , 0xfc`
- then reads register `0x43`
- if the expected bit is not already set, it calls `0x1400148e4`
  (`SetVSIOCtl_GPIO`)

Linux correlation:

- `0x16` / `0x18` are `GPCTL1A` / `GPCTL2A`
- this still supports the current view that the `WF` board path uses PMIC GPIOs
  `1` and `2` as camera-control outputs

### `Tps68470VoltageWF::SetVSIOCtl_GPIO`

Recovered from `disasm-voltage-wf-setvsioctl-gpio.txt`:

- entry point: `0x1400148e4`
- reads register `0x43`
- when enabled and when `[this + 0x10]` is nonzero, it writes back `0x43` with
  bit `0` set

Conservative takeaway:

- the GPIO helper does not treat `S_I2C_CTL` as a fire-and-forget static rail
- it makes the write conditional on both current register state and helper config

### `Tps68470VoltageWF::SetVSIOCtl_IO`

Recovered from `disasm-voltage-wf-setvsioctl-io.txt`:

- entry point: `0x140014a7c`
- reads register `0x43`
- computes two candidate values:
  - `old | 0x02`
  - `old & 0xfc`
- chooses between them based on the enable request and whether `[this + 0x10]`
  is nonzero
- writes the chosen value back to `0x43`

Implication:

- the IO-side `S_I2C_CTL` path is staged and mode-aware
- Linux's current generic `VSIO` enable handling may be too coarse for this board

### `CrdG2TiSensor::SensorPowerOn`

Recovered from `disasm-sensor-g2ti-poweron.txt`:

- `SensorPowerOn` first calls `IoActive_IO` at `0x140013014`
- it then branches into either:
  - `0x140013868` => `Tps68470VoltageWF::PowerOn`
  - `0x14001357c` => `Tps68470VoltageUF::PowerOn`
- it later calls `IoActive_GPIO` at `0x140012de0`

Implication:

- the Windows wrapper still layers IO-path activation around the regulator and
  GPIO work
- Linux has enough evidence now to say the remaining gap is PMIC-side behavior,
  not just sensor-driver ignorance of the hardware

## Linux-Oriented Takeaway

The strongest source-backed deltas between current Linux behavior and the
recovered Windows `WF` path are now:

- Windows has a five-value board voltage tuple; Linux currently exposes only the
  simpler consumer/lookup model
- Windows writes PMIC value registers before `WF::PowerOn`; Linux does not have
  a board-specific equivalent in the current MSI path
- Windows uses conditional, staged `S_I2C_CTL` writes; Linux currently treats
  `VSIO` more like a generic regulator enable
- Windows definitely touches PMIC GPIO control registers `GPCTL1A` and `GPCTL2A`,
  but exact `GPIO1` / `GPIO2` semantic mapping is still not proven from these
  windows alone

The remaining uncertainty is no longer whether the Windows driver programs the
PMIC. It does. The uncertainty is which subset of that behavior Linux must copy
for this exact board to wake `OVTI5675:00` far enough to answer chip-ID reads.

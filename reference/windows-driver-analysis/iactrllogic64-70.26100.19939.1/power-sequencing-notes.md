# iactrllogic64 Power Sequencing Notes

This note captures the concrete `TPS68470` power-path behavior recovered from
`iactrllogic64.sys` for the MSI `OV5675` package. It complements the raw
`disasm-*.txt` windows in this directory.

## Main Result

- The Windows driver contains real `TPS68470` sequencing logic for this board.
- `Tps68470VoltageWF::PowerOn` and `PowerOff` are orchestration functions, not
  simple one-register toggles.
- `Tps68470VoltageWF::IoActive` and `IoIdle` manage the `S_I2C_CTL` path with a
  refcount and separate IO-vs-GPIO helper branches.
- `CrdG2TiSensor::SensorPowerOn` and `SensorPowerOff` wrap those voltage and IO
  helpers, which means the Linux gap is likely in PMIC board data and GPIO
  policy rather than in the sensor driver itself.

## Files

- `disasm-voltage-wf-poweron.txt`
- `disasm-voltage-wf-poweroff.txt`
- `disasm-voltage-wf-ioactive.txt`
- `disasm-voltage-wf-ioactive-io.txt`
- `disasm-voltage-wf-ioactive-gpio.txt`
- `disasm-voltage-wf-ioidle.txt`
- `disasm-sensor-g2ti-poweron.txt`
- `disasm-sensor-g2ti-poweroff.txt`
- `disasm-sensor-g2ti-setgpiooutput.txt`

## Concrete Behavior

### `Tps68470VoltageWF::PowerOn`

Recovered from `disasm-voltage-wf-poweron.txt`:

- entry point: `0x140013214`
- logs step ids `0x20`, `0x21`, `0x22`, `0x23`, and final status `0x24`
- calls these helper functions in order:
  - `0x140013b38`
  - `0x1400141d8`
  - `0x140014500`
  - `0x140013e88`

Cross-references tie those helper regions to the named methods:

- `0x140013b38` => `Tps68470VoltageUF::SetVACtl`
- `0x1400141d8` => `Tps68470VoltageUF::SetVDCtl`
- `0x140014500` => `Tps68470VoltageUF::SetVSIOCtl`
- `0x140013e88` => `Tps68470VoltageUF::SetVCMCtl`

Implication:

- the power-up path enables at least VA, VD, VSIO, and VCM through explicit
  staged helper calls
- the helper names and recovered register accesses line up with Linux register
  definitions for `VACTL` `0x47`, `VDCTL` `0x48`, `S_I2C_CTL` `0x43`, and
  `VCMCTL` `0x44`

### `Tps68470VoltageWF::PowerOff`

Recovered from `disasm-voltage-wf-poweroff.txt`:

- entry point: `0x1400133e8`
- logs step ids `0x3d`, `0x3e`, `0x3f`, and final status `0x40`
- calls these helper functions in order:
  - `0x140013ce0`
  - `0x14001436c`
  - `0x140014030`

Cross-references tie those helper regions to the named methods:

- `0x140013ce0` => `Tps68470VoltageWF::SetVACtl`
- `0x14001436c` => `Tps68470VoltageWF::SetVDCtl`
- `0x140014030` => `Tps68470VoltageWF::SetVCMCtl`

Implication:

- the teardown path explicitly handles VA, VD, and VCM
- `VSIO` is not toggled in this function directly; it is managed through the
  separate `IoActive` / `IoIdle` path

### `Tps68470VoltageWF::IoActive` and `IoIdle`

Recovered from `disasm-voltage-wf-ioactive.txt`,
`disasm-voltage-wf-ioactive-io.txt`, and `disasm-voltage-wf-ioidle.txt`:

- `IoActive` entry point: `0x140012c90`
- `IoActive_IO` entry point: `0x140013014`
- `IoIdle` entry point: `0x140013158`
- both `IoActive` and `IoActive_IO` increment a refcount at `[this + 0x14]`
- `IoIdle` decrements the same refcount and only disables the path when the
  count drops to zero
- these methods read register `0x43` and use helper calls rooted around
  `0x1400146a8` and `0x140014a7c`

Linux correlation:

- register `0x43` is `TPS68470_REG_S_I2C_CTL`
- Linux models that register as the `VSIO` regulator enable path with a
  two-bit mask `TPS68470_S_I2C_CTL_EN_MASK`

Implication:

- the Windows driver is treating `VSIO` and the sensor-I2C daisy-chain path as
  coordinated state, not as an independent single-bit rail toggle

### `Tps68470VoltageWF::IoActive_GPIO`

Recovered from `disasm-voltage-wf-ioactive-gpio.txt`:

- entry point: `0x140012dd4`
- reads, masks, and writes registers `0x16` and `0x18`
- those are Linux `TPS68470_REG_GPCTL1A` and `TPS68470_REG_GPCTL2A`
- both writes clear the low mode bits with `and ... , 0xfc`, which matches
  Linux `TPS68470_GPIO_MODE_MASK`
- the same function also reads register `0x43` and may branch into the
  `S_I2C_CTL` helper path

Implication:

- this board likely uses PMIC regular GPIO 1 and GPIO 2 as camera-control
  outputs
- that is different from the Surface Go pattern, which uses the PMIC logical
  outputs `s_enable` and `s_resetn`

### `CrdG2TiSensor::SensorPowerOn` and `SensorPowerOff`

Recovered from `disasm-sensor-g2ti-poweron.txt` and
`disasm-sensor-g2ti-poweroff.txt`:

- `SensorPowerOn` entry point: `0x140011df0`
- `SensorPowerOff` entry point: `0x140011ae0`
- `SensorPowerOn` first calls `0x140013014` (`IoActive_IO`) on one internal
  subobject, then later calls `0x140012dd4` (`IoActive_GPIO`) on another
  subobject
- `SensorPowerOff` has one branch that calls `0x1400133e8`
  (`VoltageWF::PowerOff`) and then calls `0x140013158` (`IoIdle`)

Implication:

- the sensor wrapper class explicitly layers IO-path activation, GPIO
  activation, and regulator sequencing
- Linux likely needs both correct regulator consumers and correct GPIO lookup
  wiring for this board

## Linux-Oriented Takeaway

The strongest board-specific clues now are:

- `i2c-INT3472:06` is the active Windows-style PMIC companion
- `OVTI5675:00` is the active sensor
- `VACTL`, `VDCTL`, and `S_I2C_CTL` are definitely in use on this path
- `GPCTL1A` and `GPCTL2A` are definitely in use on this path

That makes the smallest plausible Linux support shape:

- `TPS68470_ANA` => `avdd` for `i2c-OVTI5675:00`
- `TPS68470_CORE` => `dvdd` for `i2c-OVTI5675:00`
- `TPS68470_VSIO` with `TPS68470_VIO` pinned to the same voltage
- two GPIO lookups on PMIC regular GPIOs `1` and `2`

The remaining uncertainty is semantic, not structural:

- which of GPIO1 or GPIO2 is `reset` vs `powerdown`
- whether `VCM`, `AUX1`, or `AUX2` need real consumers on this MSI board

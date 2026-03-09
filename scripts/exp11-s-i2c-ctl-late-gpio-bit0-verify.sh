#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp11"
EXPERIMENT_SLUG="s-i2c-ctl-late-gpio-bit0"
EXPERIMENT_TITLE="S_I2C_CTL late GPIO-phase BIT(0)"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/pmic-si2c-ctl-late-gpio-bit0-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp11-s-i2c-ctl-late-gpio-bit0-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='pmic_focus:|pmic_gpio:|controller timed out|failed to power on|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_verify_main "$@"

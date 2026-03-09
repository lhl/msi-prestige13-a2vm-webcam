#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp10"
EXPERIMENT_SLUG="s-i2c-ctl-bit1-only"
EXPERIMENT_TITLE="S_I2C_CTL BIT(1)-only VSIO"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/pmic-si2c-ctl-bit1-only-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp10-s-i2c-ctl-bit1-only-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='pmic_focus:|controller timed out|failed to power on|failed to find sensor|chip id read attempt'

experiment_verify_main "$@"

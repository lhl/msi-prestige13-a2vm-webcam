#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp9"
EXPERIMENT_SLUG="s-i2c-ctl-split-step-trace"
EXPERIMENT_TITLE="S_I2C_CTL split-step trace"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/pmic-si2c-ctl-split-step-trace-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp9-s-i2c-ctl-split-step-trace-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='pmic_focus:|pmic_split:|controller timed out|boot.mount|Emergency Mode|failed to find sensor|chip id read attempt'

experiment_verify_main "$@"

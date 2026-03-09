#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp2"
EXPERIMENT_SLUG="wf-s-i2c-ctl-staging"
EXPERIMENT_TITLE="WF S_I2C_CTL staging"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp2-wf-s-i2c-ctl-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='S_I2C_CTL|VSIO|0x43|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_verify_main "$@"

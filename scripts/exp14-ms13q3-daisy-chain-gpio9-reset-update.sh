#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp14"
EXPERIMENT_SLUG="ms13q3-daisy-chain-gpio9-reset"
EXPERIMENT_TITLE="MS-13Q3 daisy-chain plus GPIO9 reset"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-daisy-chain-gpio9-reset-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp14-ms13q3-daisy-chain-gpio9-reset-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='pmic_focus:|exp14_daisy:|controller timed out|failed to power on|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_update_main "$@"

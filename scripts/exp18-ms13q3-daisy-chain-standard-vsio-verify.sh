#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp18"
EXPERIMENT_SLUG="ms13q3-daisy-chain-standard-vsio"
EXPERIMENT_TITLE="MS-13Q3 daisy-chain standard VSIO re-test"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp18-ms13q3-daisy-chain-standard-vsio-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='pmic_focus:|exp18_daisy:|controller timed out|failed to power on|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_verify_main "$@"

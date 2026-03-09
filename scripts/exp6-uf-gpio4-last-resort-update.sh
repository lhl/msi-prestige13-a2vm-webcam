#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp6"
EXPERIMENT_SLUG="uf-gpio4-last-resort"
EXPERIMENT_TITLE="UF gpio.4 last resort"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp6-uf-gpio4-last-resort-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='gpio.4|GPDO|UF|LNK1|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_update_main "$@"

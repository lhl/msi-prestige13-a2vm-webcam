#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp7"
EXPERIMENT_SLUG="pmic-raw-regmap-trace"
EXPERIMENT_TITLE="PMIC raw regmap trace"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/pmic-raw-regmap-trace-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp7-pmic-raw-regmap-trace-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/clk"
  "drivers/regulator"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/clk/clk-tps68470.ko:kernel/drivers/clk/clk-tps68470.ko.zst"
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='pmic_raw:|failed to find sensor|chip id read attempt'

experiment_update_main "$@"

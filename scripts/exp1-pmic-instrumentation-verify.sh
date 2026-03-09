#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp1"
EXPERIMENT_SLUG="pmic-instrumentation"
EXPERIMENT_TITLE="PMIC path instrumentation"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/pmic-path-instrumentation-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp1-pmic-instrumentation-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/media/v4l2-core"
  "drivers/clk"
  "drivers/regulator"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/media/v4l2-core/videodev.ko:kernel/drivers/media/v4l2-core/videodev.ko.zst"
  "drivers/clk/clk-tps68470.ko:kernel/drivers/clk/clk-tps68470.ko.zst"
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='dummy fixed clock|fixed-clock|tps68470_clk_prepare|tps68470_clk_unprepare|S_I2C_CTL|xvclk|failed to find sensor|chip id read attempt'

experiment_verify_main "$@"

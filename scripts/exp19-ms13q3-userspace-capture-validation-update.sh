#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp19"
EXPERIMENT_SLUG="ms13q3-userspace-capture-validation"
EXPERIMENT_TITLE="MS-13Q3 userspace capture validation on exp18 branch"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-daisy-chain-standard-vsio-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp19-ms13q3-userspace-capture-validation-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/regulator"
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='Found supported sensor|Connected 1 cameras|sensor identified on attempt|failed to find sensor|probe with driver ov5675 failed|ov5675|intel-ipu7|v4l-subdev'

experiment_update_main "$@"

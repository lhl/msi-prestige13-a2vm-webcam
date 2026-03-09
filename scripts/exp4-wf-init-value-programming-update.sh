#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp4"
EXPERIMENT_SLUG="wf-init-value-programming"
EXPERIMENT_TITLE="WF init value programming"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-wf-init-value-programming-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp4-wf-init-value-programming-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/platform/x86/intel/int3472"
  "drivers/regulator"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko:kernel/drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko.zst"
  "drivers/regulator/tps68470-regulator.ko:kernel/drivers/regulator/tps68470-regulator.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='WF|Initialize|0x41|0x40|0x42|0x3c|0x3f|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_update_main "$@"

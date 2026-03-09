#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp3"
EXPERIMENT_SLUG="ms13q3-vd-1050mv"
EXPERIMENT_TITLE="MS-13Q3 VD 1050mV"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-vd-1050mv-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp3-ms13q3-vd-1050mv-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/platform/x86/intel/int3472"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko:kernel/drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='failed to find sensor|chip id read attempt|sensor identified on attempt|TPS68470 REVID'

experiment_verify_main "$@"

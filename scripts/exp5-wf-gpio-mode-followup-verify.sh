#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib-experiment-workflow.sh"

EXPERIMENT_ID="exp5"
EXPERIMENT_SLUG="wf-gpio-mode-followup"
EXPERIMENT_TITLE="WF GPIO mode follow-up"
EXPERIMENT_DOC="docs/pmic-followup-experiments.md"
EXPERIMENT_PATCH_DEFAULT="reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch"
EXPERIMENT_VERIFY_SCRIPT="exp5-wf-gpio-mode-followup-verify.sh"
EXPERIMENT_BUILD_DIRS=(
  "drivers/gpio"
)
EXPERIMENT_MODULE_MAP=(
  "drivers/gpio/gpio-tps68470.ko:kernel/drivers/gpio/gpio-tps68470.ko.zst"
)
EXPERIMENT_VERIFY_JOURNAL_PATTERN='GPCTL1A|GPCTL2A|gpio.1|gpio.2|failed to find sensor|chip id read attempt|sensor identified on attempt'

experiment_verify_main "$@"

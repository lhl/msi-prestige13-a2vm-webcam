#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)

KERNEL_TREE="${HOME}/.cache/paru/clone/linux-mainline/src/linux-mainline"
PROFILE="tested"
MODE="apply"

PATCH_LABELS=()
PATCH_FILES=()
PATCH_TIERS=()
STATUS_TREE=""

usage() {
  cat <<'EOF'
Usage:
  scripts/patch-kernel.sh [--kernel-tree DIR] [--profile tested|candidate] [--status]

Default behavior:
  Apply the selected patch stack to the kernel tree if a patch is not already
  applied. Already-applied patches are skipped.

Profiles:
  tested
      Apply only the patch stack that has already moved the webcam failure
      forward on clean-boot tests:
      - MSI INT3472/TPS68470 board-data
      - ipu-bridge OVTI5675 support
      - ov5675 serial power-on order

  candidate
      Apply the tested stack plus the current unvalidated follow-up:
      - MSI INT3472 OVTI5675 powerdown polarity follow-up

Options:
  --kernel-tree DIR
      Kernel source tree to patch.
      Default: ~/.cache/paru/clone/linux-mainline/src/linux-mainline

  --profile tested|candidate
      Select which patch stack to apply. Default: tested

  --status
      Do not apply anything. Print whether each patch is:
      - applicable
      - already applied
      - conflicted
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

append_patch() {
  PATCH_LABELS+=("$1")
  PATCH_FILES+=("${REPO_ROOT}/$2")
  PATCH_TIERS+=("$3")
}

load_profile() {
  PATCH_LABELS=()
  PATCH_FILES=()
  PATCH_TIERS=()

  append_patch \
    "ms13q3-board-data" \
    "reference/patches/ms13q3-int3472-tps68470-v1.patch" \
    "tested"
  append_patch \
    "ipu-bridge-ovti5675" \
    "reference/patches/ipu-bridge-ovti5675-v1.patch" \
    "tested"
  append_patch \
    "ov5675-serial-power-on" \
    "reference/patches/ov5675-serial-power-on-v1.patch" \
    "tested"

  case "${PROFILE}" in
    tested)
      ;;
    candidate)
      append_patch \
        "ms13q3-powerdown-active-high" \
        "reference/patches/ms13q3-int3472-powerdown-active-high-v1.patch" \
        "candidate"
      ;;
    *)
      die "unknown profile '${PROFILE}'"
      ;;
  esac
}

patch_state() {
  local tree="$1"
  local label="$2"
  local patch="$3"

  case "${label}" in
    ms13q3-board-data)
      if rg -q 'MS-13Q3' \
        "${tree}/drivers/platform/x86/intel/int3472/tps68470_board_data.c"; then
        printf 'applied'
        return 0
      fi
      ;;
    ipu-bridge-ovti5675)
      if rg -q '"OVTI5675"' \
        "${tree}/drivers/media/pci/intel/ipu-bridge.c"; then
        printf 'applied'
        return 0
      fi
      ;;
    ov5675-serial-power-on)
      if rg -q 'ov5675_power_on_order' \
        "${tree}/drivers/media/i2c/ov5675.c" && \
        rg -q 'ov5675_enable_supplies_serial' \
        "${tree}/drivers/media/i2c/ov5675.c"; then
        printf 'applied'
        return 0
      fi
      ;;
    ms13q3-gpio-swap)
      if rg -q 'GPIO_LOOKUP\\("tps68470-gpio", 1, "powerdown", GPIO_ACTIVE_LOW\\)' \
        "${tree}/drivers/platform/x86/intel/int3472/tps68470_board_data.c" && \
        rg -q 'GPIO_LOOKUP\\("tps68470-gpio", 2, "reset", GPIO_ACTIVE_LOW\\)' \
        "${tree}/drivers/platform/x86/intel/int3472/tps68470_board_data.c"; then
        printf 'applied'
        return 0
      fi
      ;;
    ms13q3-powerdown-active-high)
      if rg -q 'GPIO_LOOKUP\\("tps68470-gpio", 1, "reset", GPIO_ACTIVE_LOW\\)' \
        "${tree}/drivers/platform/x86/intel/int3472/tps68470_board_data.c" && \
        rg -q 'GPIO_LOOKUP\\("tps68470-gpio", 2, "powerdown", GPIO_ACTIVE_HIGH\\)' \
        "${tree}/drivers/platform/x86/intel/int3472/tps68470_board_data.c"; then
        printf 'applied'
        return 0
      fi
      ;;
  esac

  if git -C "${tree}" apply --reverse --check "${patch}" >/dev/null 2>&1; then
    printf 'applied'
    return 0
  fi

  if git -C "${tree}" apply --check "${patch}" >/dev/null 2>&1; then
    printf 'applicable'
    return 0
  fi

  printf 'conflict'
}

print_patch_table() {
  local i state

  printf 'Kernel tree: %s\n' "${KERNEL_TREE}"
  printf 'Profile: %s\n' "${PROFILE}"
  printf '\n'
  printf '%-12s %-28s %-10s %s\n' "STATE" "PATCH" "TIER" "FILE"

  for i in "${!PATCH_LABELS[@]}"; do
    state=$(patch_state "${STATUS_TREE}" "${PATCH_LABELS[$i]}" "${PATCH_FILES[$i]}")
    printf '%-12s %-28s %-10s %s\n' \
      "${state}" \
      "${PATCH_LABELS[$i]}" \
      "${PATCH_TIERS[$i]}" \
      "${PATCH_FILES[$i]}"

    if [[ "${state}" == "applicable" ]]; then
      git -C "${STATUS_TREE}" apply "${PATCH_FILES[$i]}"
    fi
  done
}

cleanup_status_tree() {
  if [[ -n "${STATUS_TREE}" && -d "${STATUS_TREE}" ]]; then
    rm -rf "${STATUS_TREE}"
  fi
}

create_status_tree() {
  local tmpdir diff_file

  tmpdir=$(mktemp -d /tmp/patch-kernel-status.XXXXXX)
  STATUS_TREE="${tmpdir}/tree"
  trap cleanup_status_tree EXIT

  git clone --shared --quiet "${KERNEL_TREE}" "${STATUS_TREE}" >/dev/null 2>&1

  if ! git -C "${KERNEL_TREE}" diff --quiet HEAD --; then
    diff_file="${tmpdir}/tree-state.patch"
    git -C "${KERNEL_TREE}" diff --binary HEAD -- > "${diff_file}"
    git -C "${STATUS_TREE}" apply "${diff_file}"
  fi

  normalize_tree_for_profile "${STATUS_TREE}" 1
}

normalize_tree_for_profile() {
  local tree="$1"
  local quiet="${2:-0}"
  local gpio_swap_patch="${REPO_ROOT}/reference/patches/ms13q3-int3472-gpio-swap-v1.patch"
  local state=""

  if [[ "${PROFILE}" != "candidate" ]]; then
    return 0
  fi

  state=$(patch_state "${tree}" "ms13q3-gpio-swap" "${gpio_swap_patch}")
  if [[ "${state}" != "applied" ]]; then
    return 0
  fi

  if (( ! quiet )); then
    printf '[normalize] reverse superseded follow-up: ms13q3-gpio-swap\n'
  fi

  git -C "${tree}" apply --reverse "${gpio_swap_patch}"
}

apply_patches() {
  local i state applied_count skipped_count conflict_count

  applied_count=0
  skipped_count=0
  conflict_count=0

  normalize_tree_for_profile "${KERNEL_TREE}"

  for i in "${!PATCH_LABELS[@]}"; do
    state=$(patch_state "${KERNEL_TREE}" "${PATCH_LABELS[$i]}" "${PATCH_FILES[$i]}")

    case "${state}" in
      applied)
        printf '[skip]  %s already applied\n' "${PATCH_LABELS[$i]}"
        skipped_count=$((skipped_count + 1))
        ;;
      applicable)
        printf '[apply] %s\n' "${PATCH_LABELS[$i]}"
        git -C "${KERNEL_TREE}" apply "${PATCH_FILES[$i]}"
        applied_count=$((applied_count + 1))
        ;;
      conflict)
        printf '[error] %s does not apply cleanly: %s\n' \
          "${PATCH_LABELS[$i]}" \
          "${PATCH_FILES[$i]}" >&2
        conflict_count=$((conflict_count + 1))
        ;;
    esac
  done

  printf '\nApplied: %d\n' "${applied_count}"
  printf 'Skipped: %d\n' "${skipped_count}"
  printf 'Conflicts: %d\n' "${conflict_count}"

  if (( conflict_count > 0 )); then
    exit 1
  fi
}

while (($# > 0)); do
  case "$1" in
    --kernel-tree)
      shift
      [[ $# -gt 0 ]] || die "--kernel-tree requires a value"
      KERNEL_TREE="$1"
      ;;
    --profile)
      shift
      [[ $# -gt 0 ]] || die "--profile requires a value"
      PROFILE="$1"
      ;;
    --status)
      MODE="status"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done

[[ -d "${KERNEL_TREE}" ]] || die "kernel tree not found: ${KERNEL_TREE}"
git -C "${KERNEL_TREE}" rev-parse --show-toplevel >/dev/null 2>&1 || \
  die "kernel tree is not a git working tree: ${KERNEL_TREE}"

load_profile

if [[ -n "$(git -C "${KERNEL_TREE}" status --short 2>/dev/null)" ]]; then
  printf 'note: kernel tree is already dirty; patch state will be checked file-by-file\n'
fi

case "${MODE}" in
  status)
    create_status_tree
    print_patch_table
    ;;
  apply)
    apply_patches
    ;;
  *)
    die "unknown mode '${MODE}'"
    ;;
esac

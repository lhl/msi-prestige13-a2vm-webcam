#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/.." && pwd)
DEFAULT_KERNEL_TREE="${HOME}/.cache/paru/clone/linux-mainline/src/linux-mainline"
DEFAULT_BASELINE_PROFILE="candidate"
DEFAULT_PMIC_BUS="13"
DEFAULT_PMIC_ADDR="0x48"
DEFAULT_TEMP_ROOT="${REPO_ROOT}/.tmp"
KNOWN_EXPERIMENT_PATCHES=(
  "reference/patches/pmic-path-instrumentation-v1-pre-regmap-include.patch"
  "reference/patches/pmic-path-instrumentation-v1.patch"
  "reference/patches/ms13q3-wf-s-i2c-ctl-staging-v1.patch"
  "reference/patches/ms13q3-vd-1050mv-v1.patch"
  "reference/patches/ms13q3-wf-init-value-programming-v1.patch"
  "reference/patches/ms13q3-wf-gpio-mode-followup-v1.patch"
  "reference/patches/ms13q3-uf-gpio4-last-resort-v1.patch"
)
BASE_BUILD_DIRS=(
  "drivers/platform/x86/intel/int3472"
  "drivers/media/pci/intel"
  "drivers/media/i2c"
)
BASE_MODULE_MAP=(
  "drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko:kernel/drivers/platform/x86/intel/int3472/intel_skl_int3472_tps68470.ko.zst"
  "drivers/media/pci/intel/ipu-bridge.ko:kernel/drivers/media/pci/intel/ipu-bridge.ko.zst"
  "drivers/media/i2c/ov5675.ko:kernel/drivers/media/i2c/ov5675.ko.zst"
)

ACTION_KIND=""
ACTION_LOG=""
ACTION_DIR=""
KERNEL_TREE="${DEFAULT_KERNEL_TREE}"
BASELINE_PROFILE="${DEFAULT_BASELINE_PROFILE}"
MODULE_RELEASE_OVERRIDE=""
PATCH_PATH=""
SKIP_REBOOT=0
YES_REBOOT=0
DRY_RUN=0
SKIP_PMIC_DUMP=0
RESET_EXPERIMENT_PATCHES=1
PMIC_BUS="${DEFAULT_PMIC_BUS}"
PMIC_ADDR="${DEFAULT_PMIC_ADDR}"
TEMP_ROOT="${TMPDIR:-${DEFAULT_TEMP_ROOT}}"
VERIFY_LABEL=""
VERIFY_NOTE=""
BUILD_JOBS=""

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  local line
  line="[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"
  printf '%s\n' "${line}"
  if [[ -n "${ACTION_LOG}" ]]; then
    printf '%s\n' "${line}" >> "${ACTION_LOG}"
  fi
}

require_file() {
  [[ -f "$1" ]] || die "missing file: $1"
}

prepare_temp_root() {
  mkdir -p "${TEMP_ROOT}"
  export TMPDIR="${TEMP_ROOT}"
}

as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_logged() {
  log "CMD: $*"
  if (( DRY_RUN )); then
    printf 'DRY_RUN: skipped\n' | tee -a "${ACTION_LOG}"
    return 0
  fi
  "$@" 2>&1 | tee -a "${ACTION_LOG}"
}

run_logged_shell() {
  log "CMD: $*"
  if (( DRY_RUN )); then
    printf 'DRY_RUN: skipped\n' | tee -a "${ACTION_LOG}"
    return 0
  fi
  bash -lc "$*" 2>&1 | tee -a "${ACTION_LOG}"
}

unique_items() {
  declare -A seen=()
  local item
  for item in "$@"; do
    if [[ -n "${item}" && -z "${seen[${item}]+x}" ]]; then
      printf '%s\n' "${item}"
      seen[${item}]=1
    fi
  done
}

module_name_from_map() {
  local map_entry="$1"
  local src_rel="${map_entry%%:*}"
  basename "${src_rel%.ko}" | tr '-' '_'
}

ownership_target() {
  if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    printf '%s:%s\n' "${SUDO_UID:-$(id -u "${SUDO_USER}")}" "${SUDO_GID:-$(id -g "${SUDO_USER}")}"
  else
    printf '%s:%s\n' "$(id -u)" "$(id -g)"
  fi
}

normalize_run_dir_owner() {
  local run_dir="$1"
  local owner_spec target_uid target_gid mismatch=""

  owner_spec=$(ownership_target)
  target_uid="${owner_spec%%:*}"
  target_gid="${owner_spec#*:}"

  mismatch=$(find "${run_dir}" \( ! -uid "${target_uid}" -o ! -gid "${target_gid}" \) -print -quit 2>/dev/null || true)
  if [[ -z "${mismatch}" ]]; then
    return 0
  fi

  if [[ "${EUID}" -eq 0 ]]; then
    chown -R "${target_uid}:${target_gid}" "${run_dir}"
  else
    sudo chown -R "${target_uid}:${target_gid}" "${run_dir}"
  fi
}

patch_state() {
  local tree="$1"
  local patch="$2"

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

apply_experiment_patch() {
  local state

  state=$(patch_state "${KERNEL_TREE}" "${PATCH_PATH}")
  case "${state}" in
    applied)
      log "experiment patch already applied: ${PATCH_PATH}"
      ;;
    applicable)
      run_logged git -C "${KERNEL_TREE}" apply "${PATCH_PATH}"
      ;;
    *)
      die "experiment patch conflicts with the current kernel tree: ${PATCH_PATH}"
      ;;
  esac
}

reverse_patch_if_applied() {
  local patch="$1"
  local state

  state=$(patch_state "${KERNEL_TREE}" "${patch}")
  case "${state}" in
    applied)
      log "reverse previously-applied experiment patch: ${patch}"
      run_logged git -C "${KERNEL_TREE}" apply --reverse "${patch}"
      ;;
    applicable)
      ;;
    *)
      die "cannot safely reset experiment patch from kernel tree: ${patch}"
      ;;
  esac
}

patch_touched_files() {
  local patch="$1"

  sed -n -e 's#^--- a/##p' -e 's#^+++ b/##p' "${patch}" | \
    rg -v '^/dev/null$' || true
}

collect_reset_paths() {
  local rel patch
  local -a files=()

  for rel in "${KNOWN_EXPERIMENT_PATCHES[@]}"; do
    patch="${REPO_ROOT}/${rel}"
    if [[ ! -f "${patch}" ]]; then
      continue
    fi
    while IFS= read -r file; do
      [[ -n "${file}" ]] && files+=("${file}")
    done < <(patch_touched_files "${patch}")
  done

  unique_items "${files[@]}"
}

reset_known_experiment_patches() {
  local -a files=()

  if (( ! RESET_EXPERIMENT_PATCHES )); then
    log "keeping current experiment-touched files without reset"
    return 0
  fi

  mapfile -t files < <(collect_reset_paths)
  if (( ${#files[@]} == 0 )); then
    log "no experiment-touched files found to reset"
    return 0
  fi

  log "resetting experiment-touched files back to kernel HEAD before baseline reapply"
  run_logged git -C "${KERNEL_TREE}" checkout -- "${files[@]}"
}

prepare_action_dir() {
  local stamp day slug

  stamp=$(date +%Y%m%dT%H%M%S)
  day=$(date +%Y-%m-%d)
  slug=$(printf '%s' "${EXPERIMENT_SLUG}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')
  ACTION_DIR="${REPO_ROOT}/runs/${day}/${stamp}-${slug}-${ACTION_KIND}"
  mkdir -p "${ACTION_DIR}"
  ACTION_LOG="${ACTION_DIR}/action.log"
  : > "${ACTION_LOG}"
}

write_update_metadata() {
  local module_release="$1"
  {
    printf 'action_kind=%s\n' "${ACTION_KIND}"
    printf 'experiment_id=%s\n' "${EXPERIMENT_ID}"
    printf 'experiment_slug=%s\n' "${EXPERIMENT_SLUG}"
    printf 'experiment_title=%s\n' "${EXPERIMENT_TITLE}"
    printf 'kernel_tree=%s\n' "${KERNEL_TREE}"
    printf 'baseline_profile=%s\n' "${BASELINE_PROFILE}"
    printf 'patch_path=%s\n' "${PATCH_PATH}"
    printf 'module_release=%s\n' "${module_release}"
    printf 'running_release=%s\n' "$(uname -r)"
    printf 'dry_run=%s\n' "${DRY_RUN}"
    printf 'repo_root=%s\n' "${REPO_ROOT}"
    printf 'doc_path=%s\n' "${EXPERIMENT_DOC:-}"
  } > "${ACTION_DIR}/metadata.env"
}

ensure_wrapper_vars() {
  [[ -n "${EXPERIMENT_ID:-}" ]] || die "wrapper did not set EXPERIMENT_ID"
  [[ -n "${EXPERIMENT_SLUG:-}" ]] || die "wrapper did not set EXPERIMENT_SLUG"
  [[ -n "${EXPERIMENT_TITLE:-}" ]] || die "wrapper did not set EXPERIMENT_TITLE"
  [[ -n "${EXPERIMENT_PATCH_DEFAULT:-}" ]] || die "wrapper did not set EXPERIMENT_PATCH_DEFAULT"
  [[ -n "${EXPERIMENT_VERIFY_JOURNAL_PATTERN:-}" ]] || die "wrapper did not set EXPERIMENT_VERIFY_JOURNAL_PATTERN"
  (( ${#EXPERIMENT_BUILD_DIRS[@]} > 0 )) || die "wrapper did not set EXPERIMENT_BUILD_DIRS"
  (( ${#EXPERIMENT_MODULE_MAP[@]} > 0 )) || die "wrapper did not set EXPERIMENT_MODULE_MAP"
}

resolve_patch_path() {
  if [[ -n "${PATCH_PATH}" ]]; then
    PATCH_PATH=$(cd -- "$(dirname -- "${PATCH_PATH}")" && pwd)/$(basename -- "${PATCH_PATH}")
  else
    PATCH_PATH="${REPO_ROOT}/${EXPERIMENT_PATCH_DEFAULT}"
  fi

  if [[ ! -f "${PATCH_PATH}" ]]; then
    die "experiment patch not found: ${PATCH_PATH}; create it first or override with --patch FILE"
  fi
}

resolve_build_jobs() {
  if [[ -n "${BUILD_JOBS}" ]]; then
    return 0
  fi

  if have_cmd nproc; then
    BUILD_JOBS=$(nproc)
  elif have_cmd getconf; then
    BUILD_JOBS=$(getconf _NPROCESSORS_ONLN)
  else
    BUILD_JOBS=1
  fi
}

compute_module_release() {
  local kernel_release

  require_file "${KERNEL_TREE}/Makefile"
  require_file "${KERNEL_TREE}/.config"

  kernel_release=$(make -s -C "${KERNEL_TREE}" kernelrelease)
  if [[ -n "${MODULE_RELEASE_OVERRIDE}" ]]; then
    printf '%s\n' "${MODULE_RELEASE_OVERRIDE}"
    return 0
  fi

  if [[ "${kernel_release}" != "$(uname -r)" ]]; then
    die "kernel tree release '${kernel_release}' does not match running kernel '$(uname -r)'; use --module-release if that is intentional"
  fi

  printf '%s\n' "${kernel_release}"
}

build_module_dirs() {
  local -a dirs=()
  local dir

  mapfile -t dirs < <(unique_items "${BASE_BUILD_DIRS[@]}" "${EXPERIMENT_BUILD_DIRS[@]}")
  for dir in "${dirs[@]}"; do
    run_logged make -C "${KERNEL_TREE}" -j "${BUILD_JOBS}" M="${dir}" modules
  done
}

install_module_map() {
  local module_release="$1"
  shift
  local map_entry src_rel dst_rel src_abs dst_abs tmp_file

  for map_entry in "$@"; do
    src_rel="${map_entry%%:*}"
    dst_rel="${map_entry#*:}"
    src_abs="${KERNEL_TREE}/${src_rel}"
    dst_abs="/usr/lib/modules/${module_release}/${dst_rel}"
    if [[ ! -f "${src_abs}" ]]; then
      if (( DRY_RUN )); then
        log "warning: expected built module is not present yet: ${src_abs}"
      else
        die "missing file: ${src_abs}"
      fi
    fi
    if (( DRY_RUN )); then
      tmp_file="${TMPDIR}/$(basename -- "${src_rel%.ko}").dry-run.ko.zst"
    else
      tmp_file=$(mktemp "${TMPDIR}/$(basename -- "${src_rel%.ko}").XXXXXX.ko.zst")
    fi
    run_logged zstd -T0 -f "${src_abs}" -o "${tmp_file}"
    run_logged as_root install -Dm644 "${tmp_file}" "${dst_abs}"
    if (( ! DRY_RUN )); then
      rm -f -- "${tmp_file}"
    fi
  done
}

install_modules() {
  local module_release="$1"
  local -a maps=()

  mapfile -t maps < <(unique_items "${BASE_MODULE_MAP[@]}" "${EXPERIMENT_MODULE_MAP[@]}")
  install_module_map "${module_release}" "${maps[@]}"
  run_logged as_root depmod -a "${module_release}"
}

print_update_summary() {
  local module_release="$1"
  local -a dirs=()
  local -a maps=()
  local dir map_entry

  mapfile -t dirs < <(unique_items "${BASE_BUILD_DIRS[@]}" "${EXPERIMENT_BUILD_DIRS[@]}")
  mapfile -t maps < <(unique_items "${BASE_MODULE_MAP[@]}" "${EXPERIMENT_MODULE_MAP[@]}")

  log "experiment: ${EXPERIMENT_ID} ${EXPERIMENT_TITLE}"
  log "doc: ${EXPERIMENT_DOC:-not-set}"
  log "kernel tree: ${KERNEL_TREE}"
  log "baseline profile: ${BASELINE_PROFILE}"
  log "patch: ${PATCH_PATH}"
  log "module release: ${module_release}"
  log "build jobs: ${BUILD_JOBS}"
  log "dry-run: ${DRY_RUN}"
  log "build directories:"
  for dir in "${dirs[@]}"; do
    log "  - ${dir}"
  done
  log "module installs:"
  for map_entry in "${maps[@]}"; do
    log "  - ${map_entry}"
  done
}

prompt_for_reboot() {
  if (( DRY_RUN )); then
    log "dry-run active; reboot skipped"
    return 0
  fi

  if (( SKIP_REBOOT )); then
    log "reboot skipped by --no-reboot"
    return 0
  fi

  if (( YES_REBOOT )); then
    log "rebooting now without prompt"
    as_root systemctl reboot
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log "non-interactive shell; skipping reboot. Re-run with --yes to reboot automatically."
    return 0
  fi

  printf 'Reboot now to validate %s? [y/N] ' "${EXPERIMENT_ID}"
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      log "reboot confirmed by user"
      as_root systemctl reboot
      ;;
    *)
      log "reboot skipped by user"
      ;;
  esac
}

append_experiment_summary() {
  local summary_path="$1"
  local journal_path="$2"
  local pmic_path="$3"

  {
    printf '\n'
    printf 'Experiment workflow:\n'
    printf 'id: %s\n' "${EXPERIMENT_ID}"
    printf 'title: %s\n' "${EXPERIMENT_TITLE}"
    printf 'doc: %s\n' "${EXPERIMENT_DOC:-}"
    printf 'default patch: %s\n' "${REPO_ROOT}/${EXPERIMENT_PATCH_DEFAULT}"
    printf '\n'
    printf 'Experiment-specific boot lines (%s):\n' "${EXPERIMENT_VERIFY_JOURNAL_PATTERN}"
    if [[ -s "${journal_path}" ]]; then
      cat "${journal_path}"
    else
      printf '(none matched)\n'
    fi
    printf '\n'
    printf 'PMIC dump:\n'
    if [[ -s "${pmic_path}" ]]; then
      printf '%s\n' "${pmic_path}"
    else
      printf '(not captured)\n'
    fi
  } >> "${summary_path}"
}

capture_module_info() {
  local run_dir="$1"
  local -a maps=()
  local map_entry modname

  mapfile -t maps < <(unique_items "${BASE_MODULE_MAP[@]}" "${EXPERIMENT_MODULE_MAP[@]}")
  for map_entry in "${maps[@]}"; do
    modname=$(module_name_from_map "${map_entry}")
    modinfo "${modname}" > "${run_dir}/module-${modname}.txt" 2>&1 || true
  done
}

verify_after_boot() {
  local snapshot_output run_dir summary_path journal_path pmic_path

  if (( DRY_RUN )); then
    log "dry-run verify for ${EXPERIMENT_ID}"
    log "CMD: ${REPO_ROOT}/scripts/01-clean-boot-check.sh --label ${VERIFY_LABEL@Q} --note ${VERIFY_NOTE@Q}"
    log "CMD: journalctl -b -k --no-pager | rg ${EXPERIMENT_VERIFY_JOURNAL_PATTERN@Q}"
    if (( SKIP_PMIC_DUMP )); then
      log "PMIC dump skipped by --skip-pmic-dump"
    else
      log "CMD: sudo ${REPO_ROOT}/scripts/pmic-reg-dump.sh ${PMIC_BUS@Q} ${PMIC_ADDR@Q}"
    fi
    log "dry-run verify completed without executing commands"
    return 0
  fi

  snapshot_output=$("${REPO_ROOT}/scripts/01-clean-boot-check.sh" --label "${VERIFY_LABEL}" --note "${VERIFY_NOTE}")
  printf '%s\n' "${snapshot_output}"

  run_dir=$(printf '%s\n' "${snapshot_output}" | sed -n 's/.*run directory: //p' | tail -n 1)
  [[ -n "${run_dir}" ]] || die "failed to determine run directory from clean-boot check"

  summary_path="${run_dir}/focused-summary.txt"
  journal_path="${run_dir}/experiment-journal.txt"
  pmic_path="${run_dir}/pmic-reg-dump.txt"

  journalctl -b -k --no-pager | rg "${EXPERIMENT_VERIFY_JOURNAL_PATTERN}" > "${journal_path}" || true

  if (( SKIP_PMIC_DUMP )); then
    : > "${pmic_path}"
  else
    if [[ "${EUID}" -eq 0 ]]; then
      "${REPO_ROOT}/scripts/pmic-reg-dump.sh" "${PMIC_BUS}" "${PMIC_ADDR}" > "${pmic_path}" 2>&1 || true
    else
      sudo "${REPO_ROOT}/scripts/pmic-reg-dump.sh" "${PMIC_BUS}" "${PMIC_ADDR}" > "${pmic_path}" 2>&1 || true
    fi
  fi

  capture_module_info "${run_dir}"
  normalize_run_dir_owner "${run_dir}"
  append_experiment_summary "${summary_path}" "${journal_path}" "${pmic_path}"

  printf 'Experiment journal: %s\n' "${journal_path}"
  printf 'PMIC dump: %s\n' "${pmic_path}"
  printf 'Updated summary: %s\n' "${summary_path}"
}

parse_update_args() {
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
        BASELINE_PROFILE="$1"
        ;;
      --patch)
        shift
        [[ $# -gt 0 ]] || die "--patch requires a value"
        PATCH_PATH="$1"
        ;;
      --module-release)
        shift
        [[ $# -gt 0 ]] || die "--module-release requires a value"
        MODULE_RELEASE_OVERRIDE="$1"
        ;;
      --build-jobs)
        shift
        [[ $# -gt 0 ]] || die "--build-jobs requires a value"
        BUILD_JOBS="$1"
        ;;
      --no-reboot)
        SKIP_REBOOT=1
        ;;
      --yes)
        YES_REBOOT=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      --keep-experiment-patches)
        RESET_EXPERIMENT_PATCHES=0
        ;;
      -h|--help)
        cat <<EOF_HELP
Usage:
  $(basename "$0") [options]

Options:
  --kernel-tree DIR      Kernel tree to patch and build.
  --profile NAME         Baseline patch profile for scripts/patch-kernel.sh.
  --patch FILE           Override the default experiment patch path.
  --module-release REL   Install modules into /usr/lib/modules/REL.
  --build-jobs N         Parallel jobs for make.
  --no-reboot            Skip reboot at the end.
  --yes                  Reboot without an interactive prompt.
  --keep-experiment-patches
                         Do not reverse previously-applied experiment patches
                         before applying the selected one.
  --dry-run              Validate inputs and print actions without patching,
                         building, installing modules, or rebooting.
EOF_HELP
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
    shift
  done
}

parse_verify_args() {
  while (($# > 0)); do
    case "$1" in
      --label)
        shift
        [[ $# -gt 0 ]] || die "--label requires a value"
        VERIFY_LABEL="$1"
        ;;
      --note)
        shift
        [[ $# -gt 0 ]] || die "--note requires a value"
        VERIFY_NOTE="$1"
        ;;
      --patch)
        shift
        [[ $# -gt 0 ]] || die "--patch requires a value"
        PATCH_PATH="$1"
        ;;
      --pmic-bus)
        shift
        [[ $# -gt 0 ]] || die "--pmic-bus requires a value"
        PMIC_BUS="$1"
        ;;
      --pmic-addr)
        shift
        [[ $# -gt 0 ]] || die "--pmic-addr requires a value"
        PMIC_ADDR="$1"
        ;;
      --skip-pmic-dump)
        SKIP_PMIC_DUMP=1
        ;;
      --dry-run)
        DRY_RUN=1
        ;;
      -h|--help)
        cat <<EOF_HELP
Usage:
  $(basename "$0") [options]

Options:
  --label NAME           Override the clean-boot run label.
  --note TEXT            Override the clean-boot run note.
  --patch FILE           Record an overridden experiment patch path in the summary.
  --pmic-bus N           Override the PMIC I2C bus for scripts/pmic-reg-dump.sh.
  --pmic-addr 0xNN       Override the PMIC I2C address for scripts/pmic-reg-dump.sh.
  --skip-pmic-dump       Skip the read-only PMIC dump step.
  --dry-run              Print the clean-boot check, journal grep, and PMIC
                         dump steps without executing them.
EOF_HELP
        exit 0
        ;;
      *)
        die "unknown argument: $1"
        ;;
    esac
    shift
  done
}

experiment_update_main() {
  local module_release

  ACTION_KIND="update"
  ensure_wrapper_vars
  parse_update_args "$@"
  resolve_build_jobs
  resolve_patch_path
  prepare_temp_root
  prepare_action_dir
  module_release=$(compute_module_release)
  write_update_metadata "${module_release}"
  print_update_summary "${module_release}"

  reset_known_experiment_patches
  run_logged git -C "${KERNEL_TREE}" status --short
  if ! run_logged "${REPO_ROOT}/scripts/patch-kernel.sh" --kernel-tree "${KERNEL_TREE}" --profile "${BASELINE_PROFILE}" --status; then
    log "warning: patch status check failed; continuing with baseline apply"
  fi
  run_logged "${REPO_ROOT}/scripts/patch-kernel.sh" --kernel-tree "${KERNEL_TREE}" --profile "${BASELINE_PROFILE}"
  apply_experiment_patch
  build_module_dirs
  install_modules "${module_release}"

  log "update log directory: ${ACTION_DIR}"
  log "next step after reboot: scripts/${EXPERIMENT_VERIFY_SCRIPT}"
  prompt_for_reboot
}

experiment_verify_main() {
  ACTION_KIND="verify"
  ensure_wrapper_vars
  parse_verify_args "$@"
  prepare_temp_root

  if [[ -z "${VERIFY_LABEL}" ]]; then
    VERIFY_LABEL="${EXPERIMENT_ID}-clean-boot"
  fi
  if [[ -z "${VERIFY_NOTE}" ]]; then
    VERIFY_NOTE="${EXPERIMENT_ID} clean-boot verification"
  fi
  if [[ -z "${PATCH_PATH}" ]]; then
    PATCH_PATH="${REPO_ROOT}/${EXPERIMENT_PATCH_DEFAULT}"
  fi

  verify_after_boot
}

# Patch Kernel Workflow

Updated: 2026-03-09

This repo now includes an idempotent patch applicator for the local
`linux-mainline` worktree:

- `scripts/patch-kernel.sh`

## Why it exists

The current bring-up path is no longer a single patch. We now have a small,
ordered stack:

- MSI `INT3472` / `TPS68470` board-data
- `ipu-bridge` `OVTI5675` support
- `ov5675` serial power-on order
- current follow-up candidate: MSI `INT3472` `GPIO1` active-high follow-up

Applying those by hand every time is error-prone, especially because some of
them are already present in a dirty kernel tree while others may still be
missing.

## Profiles

### `tested`

Applies only the patches that have already produced clean-boot progress:

- `ms13q3-int3472-tps68470-v1.patch`
- `ipu-bridge-ovti5675-v1.patch`
- `ov5675-serial-power-on-v1.patch`

### `candidate`

Applies the `tested` stack plus the current unvalidated follow-up:

- `ms13q3-int3472-gpio1-powerdown-active-high-v1.patch`

Use this when you want the repo’s current best branch, not just the last fully
validated stack.

## Idempotence behavior

For each patch, `scripts/patch-kernel.sh` checks whether it is:

- already applied
- applicable cleanly
- conflicted

That means repeated runs are safe:

- already-applied patches are skipped
- missing patches are applied
- conflicting patches stop the run with an error

`--status` evaluates the selected profile in order on a temporary clone of the
current kernel-tree state. That matters for dependent patches such as the
current polarity follow-up, which only becomes applicable after the tested
stack is present.

The script also knows how to normalize one older superseded follow-up:

- if the local kernel tree still has `ms13q3-int3472-gpio-swap-v1.patch`
  applied, `candidate` mode reverses that first
- if the local kernel tree still has
  `ms13q3-int3472-powerdown-active-high-v1.patch` applied, `candidate` mode
  also reverses that before applying the new follow-up

## Usage

Show the current state without changing anything:

```bash
scripts/patch-kernel.sh --status
```

Apply the validated stack to the default local `linux-mainline` tree:

```bash
scripts/patch-kernel.sh
```

Apply the current candidate stack:

```bash
scripts/patch-kernel.sh --profile candidate
```

Apply against a different kernel tree:

```bash
scripts/patch-kernel.sh --kernel-tree /path/to/linux --profile tested
```

## Intended workflow

1. Run `scripts/patch-kernel.sh --status`
2. Apply the desired profile
3. Build only the affected modules or rebuild the package as needed
4. Use the numbered test wrappers to capture the result:
   - `scripts/01-clean-boot-check.sh`
   - `scripts/02-ov5675-reload-check.sh`

## Current interpretation

For this repo today:

- `tested` is the last stack that clearly moved the clean-boot failure forward
  to sensor identification
- `candidate` is `tested` plus the current `INT3472` `GPIO1` active-high
  follow-up

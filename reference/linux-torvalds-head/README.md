# Linux Torvalds `HEAD` `int3472` Snapshot

Captured: 2026-03-07

This directory contains a local snapshot of `drivers/platform/x86/intel/int3472/` from Torvalds Linux `HEAD` as fetched on 2026-03-07.

## Source tree

- Remote: `https://github.com/torvalds/linux.git`
- Commit fetched for `HEAD`: `4ae12d8bd9a830799db335ee661d6cbc6597f838`

## Mirrored path

- `reference/linux-torvalds-head/drivers/platform/x86/intel/int3472/`

## Comparison against local `v6.19` snapshot

- Current Torvalds `HEAD` is not identical to the local `v6.19` snapshot.
- Direct subtree diff summary:
  - `discrete.c`: adds `INT3472_GPIO_TYPE_DOVDD` handling and switches one allocation site to `kzalloc_flex(...)`
  - `tps68470.c`: switches one allocation site to `kzalloc_objs(...)`
- No current `HEAD` change was observed in `tps68470_board_data.c`, so this snapshot does not show an upstream MSI board-data addition for this laptop.

## Why this snapshot exists

- It gives us a pinned upstream comparison point without depending on a live web view.
- It lets us diff local `v6.19`, current Torvalds `HEAD`, and any future patch drafts entirely inside the repo.

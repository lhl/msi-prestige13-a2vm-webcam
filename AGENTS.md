# msi-prestige13-a2vm-webcam — Agent Guide

See `README.md` for repo purpose and layout. See `docs/README.md` for the documentation index.

## What this repo is

This is a focused research and bring-up repo for Linux webcam support on the MSI Prestige 13 AI+ Evo A2VMG / related A2VM variants.

Primary artifacts:

- `README.md` — repo entrypoint; keep it accurate
- `PLAN.md` — active investigation plan and task queue
- `WORKLOG.md` — reverse-chronological record of work performed
- `state/CONTEXT.md` — short restart capsule for the next session
- `docs/` — synthesized project docs and current status notes
- `reference/` — captured external references and upstream evidence

## Before starting work

- Read `state/CONTEXT.md`, `PLAN.md`, `WORKLOG.md`, and `docs/webcam-status.md`.
- Check `git status -sb` before editing.
- Treat unrelated changes as out of scope unless the user explicitly asks.

## Documentation rules

- Keep `README.md` in sync with the actual doc structure.
- Add every meaningful work session to `WORKLOG.md` the same day it happens.
- Keep `PLAN.md` current when priorities, blockers, or next steps change.
- Refresh `state/CONTEXT.md` when direction changes or after a meaningful evidence batch.
- Put upstream sources in `reference/` with stable descriptive filenames.
- Separate upstream claims from our local verification.
- When a conclusion depends on exact machine evidence, record the exact identifiers or log lines that support it.

## Research hygiene

- Prefer precise hardware and software identifiers: model strings, PCI IDs, ACPI IDs, module names, kernel versions, firmware versions.
- Record command results when they materially change the current assessment.
- Do not run long experiment/probe batches without updating `WORKLOG.md` and, if needed, `state/CONTEXT.md`.
- If a probe could not be run, say so explicitly rather than implying a negative result.
- Do not invent board-data details, sensor wiring, or vendor behavior without evidence.

## Git hygiene

- Do not use `git add .`, `git add -A`, or `git commit -a`.
- Stage only the intended files explicitly.
- Keep commits atomic and scoped to one coherent work unit.
- Commit frequently on logical task completion; do not wait for a large batch to accumulate.
- For this repo, a good commit unit is one coherent evidence/doc/update bundle:
  - reference capture
  - status reassessment
  - plan update
  - hardware probe batch
  - patch attempt
- Before committing, make sure the related `WORKLOG.md` entry and any relevant `PLAN.md` / `state/CONTEXT.md` updates are already in place.
- Review staged files before every commit:
  - `git diff --staged --name-only`
  - `git diff --staged`
- Prefer simple commit prefixes that match the work: `docs:`, `research:`, `fix:`, `chore:`.
- No bylines, co-author footers, or AI attribution in commit messages.

## Meta

Update this file when a workflow pattern proves repeatedly useful or repeatedly causes confusion.

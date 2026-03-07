# MSI Prestige 13 AI+ Evo A2VMG Webcam Bring-Up

Research and bring-up notes for getting the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG / A2VM family.

## Current Status

- Current verdict: the webcam is still not working end to end.
- Latest technical assessment: `docs/webcam-status.md`
- Current leading blocker: missing MSI-specific `INT3472` / `TPS68470` board data or equivalent camera power-sequencing knowledge

Machine under test:

- Model: `Prestige 13 AI+ Evo A2VMG`
- Revision: `REV:1.0`
- Latest recorded kernel: `6.18.9-arch1-2` on 2026-03-07

## Start Here

- [`state/CONTEXT.md`](./state/CONTEXT.md) — short restart capsule with current objective and next actions
- [`PLAN.md`](./PLAN.md) — active investigation plan and task queue
- [`WORKLOG.md`](./WORKLOG.md) — reverse-chronological record of work performed
- [`docs/README.md`](./docs/README.md) — documentation index
- [`reference/README.md`](./reference/README.md) — captured upstream references

## Repo Layout

```text
msi-prestige13-a2vm-webcam/
├── README.md
├── AGENTS.md
├── PLAN.md
├── WORKLOG.md
├── state/
│   └── CONTEXT.md
├── docs/
│   ├── README.md
│   └── webcam-status.md
└── reference/
    ├── README.md
    ├── intel-ipu7-drivers-issue-17.md
    └── jeremy-grosser-prestige13-notes.md
```

## Working Conventions

- `README.md` stays accurate and points to the current doc structure.
- `PLAN.md` is the forward-looking source of truth for open questions and next steps.
- `WORKLOG.md` records every meaningful work session, including commands, evidence, and outcomes.
- `state/CONTEXT.md` is the one-screen restart capsule for the next session.
- `reference/` holds captured external sources with stable filenames, source URLs, and capture dates.
- `docs/` holds our synthesized conclusions and state-of-project documents.

## Current Focus

1. Confirm the exact upstream gap around `INT3472` / `TPS68470` board data.
2. Collect MSI-specific evidence from Linux logs, ACPI/device IDs, and Windows camera packages.
3. Narrow the smallest patch or configuration change needed to make the media graph come up cleanly.

## Related Docs

- [`docs/webcam-status.md`](./docs/webcam-status.md) — current Linux support assessment for this laptop
- [`reference/intel-ipu7-drivers-issue-17.md`](./reference/intel-ipu7-drivers-issue-17.md) — Intel upstream issue note
- [`reference/jeremy-grosser-prestige13-notes.md`](./reference/jeremy-grosser-prestige13-notes.md) — MSI-specific Debian/gist note

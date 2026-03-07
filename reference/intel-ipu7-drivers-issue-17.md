# Reference: intel/ipu7-drivers issue #17

- Source: https://github.com/intel/ipu7-drivers/issues/17
- Captured: 2026-03-07
- Title: `Can't make work on Lunar Lake 2024 MSI Prestige 13 AI+ Evo A2VM`
- State on capture: Open
- Opened: 2024-11-23 by `gregoiregentil`

## Why it matters

This issue is about the same laptop family as this machine and describes the same early IPU7 bring-up shape:

- the Lunar Lake IPU7 PCI device initializes
- firmware loads and authenticates
- `/dev/video*` nodes exist
- userspace still cannot use the webcam
- the kernel reports `no subdev found in graph`

## Key takeaways

- The IPU core can initialize without a working end-to-end camera pipeline.
- Having `/dev/video*` present is not enough to conclude that the webcam is usable.
- The open question in the report is the same one that still matters here: which sensor and board-specific plumbing are required for this MSI implementation.

## Most relevant details from the issue

- PCI device: Intel Lunar Lake IPU, device `0x645d`
- IPU firmware reported:
  - `psys` version `1.1.9.240627135220`
  - `isys` version `1.1.9.240627135318`
  - commit `d84f5c35`
- Failure signature:
  - IPU firmware boots
  - `intel-ipu7` reaches `CSE authenticate_run done`
  - the probe ends with `no subdev found in graph`
- Userspace symptom:
  - `/dev/video*` exists
  - `guvcview` still fails

## Current relevance on 2026-03-07

This issue is still open and has no assignee, labels, milestone, or linked fix. The core failure pattern in the issue matches the current local boot log on this machine.

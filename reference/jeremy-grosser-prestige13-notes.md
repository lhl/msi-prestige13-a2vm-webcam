# Reference: Jeremy Grosser MSI Prestige 13 notes gist

- Source: https://gist.github.com/JeremyGrosser/dff7991668d80220b4a3429590eb59a3
- Captured: 2026-03-07
- Title: `MSI Prestige 13 AI+ Evo A2VMG-029US Debian notes 2024-11-28`

## Why it matters

This is the best public reference found for the same MSI platform family outside the Intel IPU7 issue tracker. It points at the likely board-specific blocker rather than a generic IPU7 bring-up failure.

## Key takeaways

- The laptop exposes a `TPS68470` camera PMIC through `INT3472`.
- The author observed `error -ENODEV: No board-data found for this model`.
- The gist argues that camera power sequencing is probably board-specific and may be configured by MSI's Windows package component `iactrllogic64`.
- The same thread later connects the webcam failure to `ov5675` plus `TPS68470`, not to missing basic IPU7 support.

## Timeline extracted from the gist

### 2024-11-28

- The gist notes that `TPS68470` board data appears to exist only for other devices in the kernel path `drivers/platform/x86/intel/int3472/tps68470_board_data.c`.
- The working hypothesis is that this PMIC powers the camera module and flash, and that missing board data prevents safe regulator setup.

### 2024-12-19

- `gregoiregentil` linked `intel/ipu7-drivers#17` from the gist comments.
- Their hypothesis was that `ov5675` was not being registered correctly because of `TPS68470`.

### 2025-12-22

- Jeremy Grosser reported that he still had not seen new information or drivers that fixed the camera.
- Another commenter reported kernel `6.18` with IPU7 support enabled but still no visible camera device, concluding that a missing piece was still needed to actually switch the camera on.

## Current relevance on 2026-03-07

The local boot log on this machine shows the same `TPS68470` board-data failure that the gist called out in late 2024. That makes this gist a direct match for the current blocker.

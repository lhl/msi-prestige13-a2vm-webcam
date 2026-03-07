# Context

Updated: 2026-03-07

## Objective

Get the built-in webcam working on Linux on the MSI Prestige 13 AI+ Evo A2VMG, or reduce the remaining blocker to a specific upstream patch or vendor-only gap with strong evidence.

## Best Current Read

- IPU7 core support is present.
- `ov5675` is likely the correct sensor path.
- The strongest blocker is still MSI-specific `INT3472` / `TPS68470` board data or power sequencing.
- Local `linux-mainline` source path to reuse:
  - `~/.cache/paru/clone/linux-mainline/src/linux-mainline`
  - current inspected tag: `v6.19`

Most important current log lines:

- `int3472-tps68470 i2c-INT3472:06: error -ENODEV: No board-data found for this model`
- `intel-ipu7 0000:00:05.0: no subdev found in graph`

## Open Questions

- Is a missing DMI match the only blocker?
- What regulator or GPIO sequencing does MSI require for this camera path?
- Can we extract enough information from the Windows package to patch Linux support cleanly?

## Next Actions

1. Check whether this MSI DMI identity is supported under another variant string or in newer upstream changes beyond local `v6.19`.
2. Run direct `media-ctl` / `v4l2-ctl` probing with full device access.
3. Pull the MSI Windows camera package and look for `iactrllogic64`, INF, registry, or sequencing clues.

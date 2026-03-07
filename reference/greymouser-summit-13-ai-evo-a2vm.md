# greymouser Summit 13 AI+ Evo A2VM Repo Note

Captured: 2026-03-08

## Source

- Repo: `https://github.com/greymouser/Summit-13-AI-Evo-A2VM`

## What it is

- Public repo with Linux support notes, tools, and install helpers for the related `MSI Summit 13 AI+ Evo A2VMTG`
- Repo README describes two current focus areas:
  - IIO sensor support
  - audio mute / speaker LED control

## Why it may matter here

- It is a closely related MSI Lunar Lake platform:
  - Model: `MSI Summit 13 AI+ Evo A2VMTG`
  - Board: `MS-13P5`
  - Vendor: `Micro-Star International Co., Ltd.`
- Even though it is not directly about the webcam, it may contain:
  - additional MSI-specific low-level Linux integration clues
  - DMI matching patterns
  - firmware-fetch/install conventions
  - related ACPI, LED, or sensor handling that could be useful when comparing vendor platform behavior across nearby MSI models

## Current repo shape

- top-level folders:
  - `iio`
  - `leds`
- README states:
  - `iio` supports 6 IIO sensors and uses vendor firmware from MSI
  - `leds` connects ALSA audio controls to the kernel LED subsystem

## Current limitation

- No webcam-specific material is visible from the top-level README, so this is a future-comparison reference rather than a direct camera bring-up source.

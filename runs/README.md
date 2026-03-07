# Run Archive

This directory is where `scripts/webcam-run.sh` writes timestamped probe attempts and capture-only snapshots.

## Layout

- `runs/YYYY-MM-DD/YYYYMMDDTHHMMSS-<action>-<label>/`

Each run directory is intended to be self-contained evidence for one attempt, including:

- exact action order
- pre/post state capture
- kernel log excerpts
- media and V4L2 output
- relevant sysfs state

## Usage note

Runs are created as normal repo files so they can be selectively committed when they materially change the investigation. Do not stage large batches blindly; commit only the runs that matter together with the resulting notes and conclusions.

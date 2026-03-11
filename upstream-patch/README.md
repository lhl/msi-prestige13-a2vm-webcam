# Upstream Patch Series: MSI Prestige 13 AI+ Evo A2VMG Webcam

This directory contains the current upstream submission bundle for the
MSI Prestige 13 AI+ Evo A2VMG (`MS-13Q3`) built-in OV5675 webcam.

These files are now real `git format-patch` mailboxes, not hand-written
diffs. They can be applied directly with `git am`.

## Current Status

Local hardware proof remains the `exp18` bring-up branch plus explicit
userspace `media-ctl` setup:

- raw Bayer capture works at `2592x1944 @ 30 fps`
- the sensor binds into the media graph
- normal `/dev/video0` plug-and-play still is not the final app-facing path

This cleaned submission bundle was mechanically revalidated on
`2026-03-12` against the current local `torvalds/linux` `origin/master`
at:

- commit: `4ae12d8bd9a8`
- describe: `v7.0-rc2-467-g4ae12d8bd9a8`

Mechanical checks completed on that base:

- `checkpatch.pl --strict`: clean
- `git am`: replayed cleanly in a fresh clone

One thing is still worth doing before the first real mailing-list send:

- retest this exact 6-patch series on the laptop, not just the older
  `exp18` branch

## Patch Series

Apply in order against a clean `torvalds/linux` `master` worktree:

| # | File | Subsystem | Summary |
|---|------|-----------|---------|
| 1 | `0001-media-ipu-bridge-Add-OV5675-sensor-support.patch` | media | Add `OVTI5675` to `ipu-bridge` |
| 2 | `0002-platform-int3472-Add-TPS68470-GPIO-daisy-chain-property.patch` | platform/x86 | Pass a `daisy-chain-enable` software-node property to the TPS68470 GPIO cell |
| 3 | `0003-gpio-tps68470-Add-I2C-daisy-chain-support.patch` | gpio | Configure TPS68470 GPIO 1/2 as daisy-chain inputs |
| 4 | `0004-media-i2c-ov5675-Support-optional-powerdown-GPIO.patch` | media | Teach `ov5675` to consume an optional `powerdown` GPIO |
| 5 | `0005-media-i2c-ov5675-Reorder-supplies-for-power-sequencing.patch` | media | Reorder `ov5675` supplies to `avdd -> dvdd -> dovdd` |
| 6 | `0006-platform-int3472-Add-MSI-Prestige-13-AI-Evo-A2VMG-board-data.patch` | platform/x86 | Add `MS-13Q3` regulator, GPIO, daisy-chain, and DMI board data |

Treat this as one 6-patch series. Patch `6/6` depends on the earlier
driver changes.

## What Changed vs. the Earlier Draft

The first repo-local upstream draft was clean, but it still had two real
submission problems:

- it used new public TPS68470 `platform_data` even though Bartosz
  suggested a property / software-node approach in Antti's thread
- it mapped GPIO 7 as `powerdown` in board data without any final
  upstream `ov5675` consumer for that line

This refreshed series fixes both:

- the daisy-chain flag is now a `daisy-chain-enable` software-node
  property on the `tps68470-gpio` MFD cell
- `ov5675` now supports an optional `powerdown` GPIO, so the
  `GPIO9 reset + GPIO7 powerdown` board model is coherent

It also keeps the earlier cleanup wins:

- all experiment logging and PMIC instrumentation are gone
- all `tps68470-regulator.c` debug-only changes are gone
- the `ov5675` serial power helper was reduced to a supply-array reorder
- the board-data regulator set was reduced to `CORE`, `ANA`, `VIO`, and
  `VSIO`

## Relation to Antti Laakso's Prestige 14 Series

Antti Laakso posted a related MSI Prestige 14 series on
`2026-03-10`; see `reference/antti-patch/` and
`docs/antti-prestige14-thread-review.md`.

The overlap that matters:

- same `OVTI5675` `ipu-bridge` addition
- same TPS68470 I2C daisy-chain idea on GPIO 1/2
- same broad remote-control GPIO shape on GPIO 9 / GPIO 7

The deliberate differences here:

- this targets `Prestige 13 AI+ Evo A2VMG` / `MS-13Q3`, not Prestige 14
- the daisy-chain plumbing uses a software-node property instead of new
  public platform data
- `ov5675` gains explicit optional `powerdown` support so GPIO 7 is
  actually consumed
- this series carries the `ov5675` supply reorder, which Antti's `v1`
  did not
- the DMI match stays strict:
  - `DMI_SYS_VENDOR = Micro-Star International Co., Ltd.`
  - `DMI_PRODUCT_NAME = Prestige 13 AI+ Evo A2VMG`
  - `DMI_BOARD_NAME = MS-13Q3`

## Exact Submission Steps

This is the exact first-time-safe workflow to turn this directory into a
real mailing-list submission.

### 1. Start from a clean `torvalds/linux` tree

Use a fresh clone or a separate worktree. Do not start from the dirty
local experiment tree.

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux-submit
cd linux-submit
git fetch origin
git switch -c msi-ms13q3-ov5675 origin/master
```

If you already have a local clone, a separate worktree is better:

```bash
git -C /path/to/linux worktree add -b msi-ms13q3-ov5675 ../linux-submit origin/master
cd ../linux-submit
```

### 2. Apply this mailbox series

```bash
git am /home/lhl/github/lhl/msi-prestige13-a2vm-webcam/upstream-patch/000*.patch
```

If `git am` fails, stop and fix that first. Do not send a series that
does not apply cleanly to current `origin/master`.

### 3. Build and retest on the actual laptop

Minimum bar before sending:

- the kernel builds cleanly
- the camera still binds on the MSI laptop
- the earlier raw-capture path still works

For this repo, that means rerunning the equivalent of:

- `scripts/06-media-pipeline-setup.sh`
- and at least one app-facing check (`scripts/09-libcamera-loopback-check.sh`
  or your current preferred route)

### 4. Generate a fresh outgoing cover-letter series from your branch

Do not send the checked-in patch files directly. Regenerate from the
branch you just tested so the cover letter and `base-commit` metadata
match the exact branch you built.

```bash
mkdir -p outgoing
git format-patch --cover-letter --base=auto -o outgoing origin/master..HEAD
```

### 5. Re-run mechanical checks on the outgoing series

Run `checkpatch.pl` and `get_maintainer.pl` on the exact patch files you
are about to send:

```bash
perl scripts/checkpatch.pl --strict outgoing/000*.patch
perl scripts/get_maintainer.pl --nogit --nogit-fallback --norolestats \
  outgoing/000*.patch
```

Read the maintainer output before sending. This series crosses
subsystems, so do not guess a single tree or single list.

As of the `2026-03-12` validation pass, the combined recipient set from
`get_maintainer.pl` for this 6-patch series was:

- `linux-media@vger.kernel.org`
- `linux-gpio@vger.kernel.org`
- `platform-driver-x86@vger.kernel.org`
- `linux-kernel@vger.kernel.org`
- `sakari.ailus@linux.intel.com`
- `mchehab@kernel.org`
- `linusw@kernel.org`
- `brgl@kernel.org`
- `dan.scally@ideasonboard.com`
- `hansg@kernel.org`
- `ilpo.jarvinen@linux.intel.com`

Treat that as the expected `v1` recipient set, not a permanent truth.
Re-run `get_maintainer.pl` right before sending in case maintainer
ownership changes.

Edit `outgoing/0000-cover-letter.patch` and include:

- exact hardware:
  - `Prestige 13 AI+ Evo A2VMG`
  - `MS-13Q3`
  - `INT3472:06`
  - `OVTI5675`
  - `TPS68470`
- exact local result:
  - sensor binds
  - raw Bayer capture works after explicit `media-ctl` setup
- exact series shape:
  - software-node daisy-chain property
  - optional `powerdown` GPIO support
  - supply reorder
- caution about current scope:
  - do not claim full direct `/dev/video0` plug-and-play webcam support
  - this series is basic hardware enablement

### 6. Configure `git send-email`

Do this once if you have never used it before:

```bash
git config sendemail.from "Your Name <you@example.com>"
git config sendemail.smtpServer smtp.example.com
git config sendemail.smtpServerPort 587
git config sendemail.smtpEncryption tls
git config sendemail.smtpUser you@example.com
```

Set the password or token the way your mail provider expects. For many
providers that means an app password, not your normal login password.

### 7. Dry-run the send

Because this series touches `media`, `gpio`, and `platform/x86`, send
the cover letter to all three subsystem lists and let
`get_maintainer.pl` fill in the per-patch maintainers and reviewers.
Keep `linux-kernel@vger.kernel.org` in the explicit CC set too, because
the current maintainer output includes it.

```bash
git send-email \
  --dry-run \
  --annotate \
  --confirm=always \
  --to linux-media@vger.kernel.org \
  --cc linux-gpio@vger.kernel.org \
  --cc platform-driver-x86@vger.kernel.org \
  --cc linux-kernel@vger.kernel.org \
  --cc-cmd 'perl scripts/get_maintainer.pl --nogit --nogit-fallback --norolestats --nom' \
  outgoing/*.patch
```

Check:

- threading looks right
- the cover letter goes to the 4 expected lists
- each patch picked up the expected maintainers
- no obvious duplicate or missing recipients remain

### 8. Send the real `v1`

Run the same command again without `--dry-run`:

```bash
git send-email \
  --annotate \
  --confirm=always \
  --to linux-media@vger.kernel.org \
  --cc linux-gpio@vger.kernel.org \
  --cc platform-driver-x86@vger.kernel.org \
  --cc linux-kernel@vger.kernel.org \
  --cc-cmd 'perl scripts/get_maintainer.pl --nogit --nogit-fallback --norolestats --nom' \
  outgoing/*.patch
```

Save the `Message-ID` of the `0000` cover letter mail after sending.

## After Review

When feedback arrives:

1. update the same topic branch
2. regenerate with `-v2`
3. send `v2` as a reply to the `v1` cover letter

Exact commands:

```bash
git format-patch --cover-letter --base=auto -v2 -o outgoing-v2 origin/master..HEAD
git send-email \
  --annotate \
  --confirm=always \
  --in-reply-to '<message-id-of-v1-cover-letter>' \
  --to linux-media@vger.kernel.org \
  --cc linux-gpio@vger.kernel.org \
  --cc platform-driver-x86@vger.kernel.org \
  --cc linux-kernel@vger.kernel.org \
  --cc-cmd 'perl scripts/get_maintainer.pl --nogit --nogit-fallback --norolestats --nom' \
  outgoing-v2/*.patch
```

For `v2`, add a short changelog below the `---` line in the cover letter
and in any patch that changed materially.

## References

- Linux kernel patch submission guide:
  `https://docs.kernel.org/process/submitting-patches.html`
- Linux kernel patch submit checklist:
  `https://docs.kernel.org/process/submit-checklist.html`
- Antti thread review in this repo:
  `../docs/antti-prestige14-thread-review.md`

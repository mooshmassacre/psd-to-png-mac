# psd-to-png-mac

A macOS Finder Quick Action by **Moosh Massacre**. Export the stored merged image from one or more PSD/PSB documents to PNG, without Photoshop, Homebrew, or a separate runtime installation.

**Project/repository name:** `psd-to-png-mac` · **Finder Quick Action:** PSD to PNG

**Version:** 1.0.0 · **License:** MIT · **Contact:** gustavo@mooshmassacre.studio

## Install

Requires **macOS 14 Sonoma or later**. The installer includes a universal executable for Apple Silicon and Intel.

1. Download `PSD_to_PNG_Installer_v1.0.zip` from the [latest release](https://github.com/mooshmassacre/psd-to-png-mac/releases/latest) and extract it.
2. Open `Install PSD to PNG.command`, click **Continue**, then **Install** (or **Replace**) in the macOS **Quick Action Installer**. This final native step registers the workflow with Finder.
3. Select `.psd` or `.psb` files in Finder, then choose **Quick Actions → PSD to PNG**. The native Quick Action Installer registers the action for Finder. Close and reopen any menu that was already open during installation.

If the action is hidden, enable it under **System Settings → Keyboard → Keyboard Shortcuts → Services**. Menu locations can vary by macOS version. The workflow accepts files so PSB documents do not depend on Finder recognizing their image type; other file formats produce an error.

The package is locally ad-hoc signed, **not Developer ID signed or notarized**. macOS may block a downloaded installer. Use the system's Open Anyway option only after reviewing the source and trusting this package. No administrator password is needed. Installation is per user.

Installed files:

```text
~/Library/Application Support/PSD to PNG/
    PSD_to_PNG.command
    bin/psd-to-png
    LICENSE
    THIRD_PARTY_NOTICES.md
    ABOUT.txt
~/Library/Services/PSD to PNG.workflow/
```

Updates retain the previous converter in timestamped `.backup-*` folders. Workflow backups are kept separately under `~/Library/Application Support/PSD to PNG Backups/`, outside the Services discovery folder. Routine installation failures restore the previous installation automatically. If the process is forcibly terminated, backups remain available for manual recovery.

## Use

`image.psd` or `image.psb` becomes `image.png` in the same folder. The source document is opened read-only and is never rewritten. Files are processed sequentially, with no success dialog.

When a destination exists:

| Button | Result |
| --- | --- |
| Replace | Atomically replaces that PNG after conversion succeeds. |
| Save a Copy | Saves `image copy.png`, then `image copy 2.png`, and so on. |
| Cancel | Skips this document and continues with the next file. |

Failures are collected into an English dialog after the batch. Successful conversions remain saved. Output names are reserved exclusively to avoid overwriting a concurrently created file. Replacing a symlink replaces the link itself, not the file it points to.

## Compatibility

| Feature | v1.0 |
| --- | --- |
| PSD version 1 / PSB version 2 | Supported |
| RGB / grayscale, 8 / 16 bits per channel | Supported; output retains bit depth |
| Raw / PackBits RLE / ZIP / ZIP with prediction | Supported |
| Stored merged transparency | Supported; saved selection/spot channels are not exported |
| Embedded ICC profile | Preserved in the PNG |
| Layers, effects, text, smart objects | Their appearance is taken from the stored composite; they are not re-rendered |
| CMYK, Lab, indexed, bitmap, multichannel, duotone | Rejected |
| 32-bit HDR | Rejected; no automatic tone mapping |
| Missing compatibility composite | Rejected when declared missing or structurally absent |
| PSDC/cloud documents | Not supported |

The file must contain a valid full-resolution composite. For Photoshop-authored documents, enable **Maximize PSD and PSB File Compatibility** when saving. A third-party writer may store a placeholder without marking it as missing; the converter cannot determine whether such pixels match the intended design. It also cannot detect a stale composite.

Transparency declared by the negative layer count or merged-transparency tags is exported. RGB composites with transparency receive the white-matte correction required by Photoshop's composite representation. Ambiguous extra channels without a transparency declaration are treated as auxiliary channels.

V1.0 limits input files to **2 GiB** and decoded planar composite data to **512 MiB**. PSB support does not mean every very large PSB fits these limits. Peak memory is higher than the decoded size because PNG encoding uses additional buffers. Embedded ICC profiles retain the document's color interpretation; no sRGB conversion is applied. Untagged documents remain untagged. Other metadata, including EXIF/XMP, is not copied. This utility is not a metadata-scrubbing guarantee.

## Uninstall

Open `Uninstall PSD to PNG.command` and choose **Uninstall**. It removes only the application support folder and its Quick Action for the current user. Source images, exported PNGs, and previous installation backups remain.

## Build and test

Only contributors need Apple's Command Line Tools and Python 3 for tests:

```sh
./scripts/build.sh
python3 -m unittest discover -s tests -v
./scripts/package.sh
```

The build produces a universal executable targeting macOS 14. The installer archive is written to `dist/PSD_to_PNG_Installer_v1.0.zip`, with a checksum in `dist/SHA256SUMS`. The decoder and PNG writer are project code; the binary dynamically links macOS system frameworks, Swift runtime libraries, and the system zlib. No third-party converter is bundled.

For headless checks, the executable supports `--collision replace|copy|cancel` and `--version`. Without `--collision`, name conflicts and errors use native dialogs. Always quote paths:

```sh
./dist/bin/psd-to-png --collision copy '/path/to/example.psb'
```

See [validation](docs/VALIDATION.md), [dependency review](docs/DEPENDENCIES.md), and [roadmap](ROADMAP.md).

## Credits

Created by **Moosh Massacre** — **gustavo@mooshmassacre.studio**.
Independent project; not affiliated with Adobe or Apple. PSD/PSB format details are based on Adobe's published specification. See `THIRD_PARTY_NOTICES.md` for system dependencies and reference projects.

For isolated installer tests, `PSD_TO_PNG_USER_ROOT` selects a test account directory and `PSD_TO_PNG_QUIET=1` suppresses dialogs. Normal installation uses the current user account.

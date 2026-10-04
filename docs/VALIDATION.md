# Validation report — v1.0

Validation date: 2026-10-04. Host: Apple Silicon macOS.

## Automated checks

- Universal Mach-O binary contains arm64 and x86_64 slices. Both slices execute `--version` on the development host; the Intel slice runs through Rosetta. Native Intel hardware has not been tested.
- The binary links only operating-system libraries and frameworks; no Photoshop, Homebrew paths, Python runtime or external converter is linked.
- Unit checks cover a 96-case PSD/PSB matrix: RGB/grayscale, 8/16 bits, four compression types, opaque/transparent pixels and merged-transparency tags. PNG CRCs, exact decoded pixels, bit depth and unchanged source bytes are checked.
- Additional cases cover repeated RLE packets, auxiliary alpha channels, malformed/truncated inputs, missing declared composites, batch continuation, Replace/Save a Copy/Cancel, symlink replacement, ZIP corruption and concurrent copy reservations.
- Installer tests use a temporary user directory, checking initial installation, update backups, failed staging, workflow argument wiring and uninstallation while keeping unrelated files.

## External corpus

Downloaded the separately licensed psd-tools repository at commit `9e706d6ba3b5e5c91a1d0c423ff783ce3e9c363c`. No corpus files are redistributed here.

Of 266 RGB/grayscale, 8/16-bit PSD/PSB fixtures:

- **246 converted**. Every exported pixel matched an independently decoded stored composite using psd-tools 1.23.0 plus the specified white-matte correction. Comparison includes channel count and 16-bit precision. Embedded ICC profile bytes also matched in all 158 accepted fixtures containing a profile.
- **19 rejected** because their version resource declares no real compatibility composite.
- **1 rejected** because its stored image data is truncated; psd-tools also reports a decompressed length mismatch.
- **0 pixel mismatches** among accepted fixtures.

These tests establish compatibility with this corpus, not every document from every authoring tool. No Photoshop-rendered reference export comparison was performed. Synthetic pixel tests and the external corpus cover different failure modes.

Reproduce the optional external comparison in an isolated Python environment with psd-tools and numpy installed:

```sh
python scripts/validate_corpus.py /path/to/psd-tools/tests/psd_files --report /tmp/corpus-report.json
```

## Graphical integration status

On 2026-10-04, verified the actual Finder menu with PSD and PSB files selected. Ran the action from Finder on an 8-bit PSD and a 16-bit ZIP-predicted PSB; both PNG outputs were created. Source test documents were unchanged. No Photoshop was launched.

Copying the workflow directly into Services and refreshing caches did not reliably register the action. Saving through Automator and installing through the system's Quick Action Installer did. The release installer now installs the converter first, then opens Apple's Quick Action Installer; the user chooses Install or Replace to complete registration. This native installation path was checked with a PSB selected in Finder afterward, including a second full reinstall using the corrected script. The action remained visible. The installer supplies a staged copy because the macOS installer can move its input workflow; the release resources remain intact.

Workflow backups are stored outside `~/Library/Services`, avoiding duplicate service discovery. The isolated installer tests check that no workflow backups remain in the Services folder.

Clicking all native collision dialog buttons, native Intel hardware, macOS 14, Developer ID signing and notarization still require follow-up validation. Collision behavior is covered by headless tests. CI configuration is included but has not been run on GitHub.

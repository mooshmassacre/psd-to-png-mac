# Roadmap

## v1.0

- [x] Finder workflow, multiple PSD/PSB inputs, English dialogs.
- [x] Native stored-composite decoder; no Photoshop or Homebrew.
- [x] 8/16-bit RGB and grayscale; raw, RLE, ZIP and ZIP prediction.
- [x] Collision choices, exclusive copy naming and atomic replacement.
- [x] ICC preservation, read-only sources, installer and uninstaller.
- [x] Universal binary, MIT license, release archive and automated tests.
- [x] Validate Finder menu activation and PSD/PSB batch conversion on the development Mac.
- [ ] Complete collision-dialog checks on a second Mac and Intel hardware.
- [ ] Developer ID signing and notarization before public production release.

## v1.1

- CMYK/Lab conversion through ColorSync with explicit color-management tests.
- Streaming decoding and PNG encoding for larger PSB files.
- Progress/cancellation for large batches.
- Broader alpha-channel identification and fixtures from multiple authoring tools.

## Later

- Indexed/bitmap modes and a deliberate HDR tone-mapping workflow.
- Signed `.pkg` distribution and CI releases.
- Optional destination-folder choice and conversion summary.

Layer reconstruction is outside the current roadmap. The stored composite remains the preferred source of final appearance.

# Decoder and dependency review

Reviewed on 2026-10-04, before bundling a converter.

| Candidate | Verified capability / license | Decision |
| --- | --- | --- |
| ImageMagick | Official format table lists PSD and PSB read/write; ImageMagick License permits redistribution with notices and its conditions. PSD coder has explicit PSB handling. | Not bundled: packaging architecture-specific dependencies and policies adds distribution complexity. |
| Pillow | Official documentation describes limited PSD support; PSB is not documented as supported. Pillow uses the MIT-CMU License. | Not selected as the PSD/PSB backend. |
| psd-tools | MIT; supports PSD/PSB and stored image data. Requires Python and dependencies. | Used only as an external test oracle/reference; not part of the installer. |
| Native implementation | Own MIT code reads composite offsets from PSD/PSB headers and decodes supported compression. Uses AppKit/Foundation and the OS zlib. | Selected for v1.0, with a narrow documented compatibility matrix. |

No third-party decoder source or converter binary is embedded. zlib is dynamically linked from macOS; it is distributed under the zlib license. Apple's OS frameworks remain system dependencies. Swift's Apache 2.0 license has a Runtime Library Exception for compiled applications.

Primary references:

- [Adobe PSD/PSB format specification](https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/)
- [ImageMagick formats](https://imagemagick.org/formats/), [license](https://imagemagick.org/license/), [PSD coder](https://github.com/ImageMagick/ImageMagick/blob/main/coders/psd.c)
- [Pillow format documentation](https://pillow.readthedocs.io/en/stable/handbook/image-file-formats.html), [license](https://github.com/python-pillow/Pillow/blob/main/LICENSE)
- [psd-tools](https://github.com/psd-tools/psd-tools), [MIT license](https://github.com/psd-tools/psd-tools/blob/main/LICENSE)
- [Swift license and Runtime Library Exception](https://www.swift.org/legal/license.html)
- [zlib license](https://zlib.net/zlib_license.html)

The format specification is referenced, not redistributed. Support claims for the selected backend are backed by the project's own tests; another library's format list does not establish compatibility for this implementation.

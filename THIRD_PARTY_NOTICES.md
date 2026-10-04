# Third-party notices

PSD to PNG's application source is MIT licensed, copyright (c) 2026 Moosh Massacre, gustavo@mooshmassacre.studio.

The executable dynamically uses macOS AppKit/Foundation, Apple system libraries and Apple's supplied Swift runtime. It also dynamically uses the operating system's zlib, by Jean-loup Gailly and Mark Adler, under the [zlib license](https://zlib.net/zlib_license.html). No copy of these system libraries is included in the installer.

The Swift project uses [Apache 2.0 with a Runtime Library Exception](https://www.swift.org/legal/license.html). Adobe's [PSD/PSB specification](https://www.adobe.com/devnet-apps/photoshop/fileformatashtml/) was consulted and is not included in this distribution.

ImageMagick and psd-tools implementations were consulted to verify compression and transparency behavior. No source from either project is bundled. Optional validation uses a separately downloaded psd-tools test corpus and Python package, under its MIT license (copyright (c) 2019 Kota Yamaguchi). Those files are not in the release archive.

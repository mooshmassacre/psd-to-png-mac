#!/bin/bash
# Copyright (c) 2026 Moosh Massacre. SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -x dist/bin/psd-to-png ]]
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/psd-to-png-package.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
BUNDLE="$STAGE/PSD to PNG 1.0"
mkdir -p "$BUNDLE/dist/bin"
cp dist/bin/psd-to-png "$BUNDLE/dist/bin/"
cp -R Resources docs "$BUNDLE/"
cp *.command LICENSE ABOUT.txt README.md ROADMAP.md THIRD_PARTY_NOTICES.md "$BUNDLE/"
rm -f dist/PSD_to_PNG_Installer_v1.0.zip
/usr/bin/ditto -c -k --norsrc --noextattr --keepParent "$BUNDLE" dist/PSD_to_PNG_Installer_v1.0.zip
/usr/bin/shasum -a 256 dist/PSD_to_PNG_Installer_v1.0.zip > dist/SHA256SUMS

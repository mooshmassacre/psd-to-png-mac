#!/bin/bash
# Copyright (c) 2026 Moosh Massacre. SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist/bin
TASK_MODULE_CACHE="${TMPDIR:-/tmp}/psd-to-png-module-cache"
mkdir -p "$TASK_MODULE_CACHE"
for arch in arm64 x86_64; do
  xcrun swiftc -module-cache-path "$TASK_MODULE_CACHE" -O -target "$arch-apple-macosx14.0" -I Sources/CZlib Sources/main.swift -o "dist/bin/psd-to-png-$arch"
done
lipo -create dist/bin/psd-to-png-arm64 dist/bin/psd-to-png-x86_64 -output dist/bin/psd-to-png
rm dist/bin/psd-to-png-arm64 dist/bin/psd-to-png-x86_64
codesign --force --sign - dist/bin/psd-to-png

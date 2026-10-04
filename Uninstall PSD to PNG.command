#!/bin/bash
# Copyright (c) 2026 Moosh Massacre — gustavo@mooshmassacre.studio
# SPDX-License-Identifier: MIT
set -euo pipefail
USER_ROOT="${PSD_TO_PNG_USER_ROOT:-$HOME}"
QUIET="${PSD_TO_PNG_QUIET:-0}"
if [[ "$QUIET" != 1 ]]; then
ANSWER=$(/usr/bin/osascript -e 'button returned of (display dialog "Remove PSD to PNG from this user account? Your PSD, PSB and PNG files will be kept." buttons {"Cancel", "Uninstall"} default button "Cancel" with title "PSD to PNG")') || exit 0
[[ "$ANSWER" == "Uninstall" ]] || exit 0
fi
TARGET="$USER_ROOT/Library/Application Support/PSD to PNG"
SERVICE="$USER_ROOT/Library/Services/PSD to PNG.workflow"
# Only remove the exact paths owned by this application. Backups are retained.
rm -rf "$SERVICE" "$TARGET"
if [[ "$USER_ROOT" == "$HOME" ]]; then /System/Library/CoreServices/pbs -flush 2>/dev/null || true; fi
if [[ "$QUIET" != 1 ]]; then /usr/bin/osascript -e 'display dialog "PSD to PNG has been uninstalled. Any previous installation backups were kept." buttons {"OK"} default button "OK" with title "PSD to PNG"'
fi

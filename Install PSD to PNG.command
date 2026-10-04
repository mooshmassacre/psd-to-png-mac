#!/bin/bash
# Copyright (c) 2026 Moosh Massacre — gustavo@mooshmassacre.studio
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
USER_ROOT="${PSD_TO_PNG_USER_ROOT:-$HOME}"
QUIET="${PSD_TO_PNG_QUIET:-0}"
TARGET="$USER_ROOT/Library/Application Support/PSD to PNG"
SERVICE="$USER_ROOT/Library/Services/PSD to PNG.workflow"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"
TARGET_BACKUP="$TARGET.backup-$STAMP"
BACKUP_FOLDER="$USER_ROOT/Library/Application Support/PSD to PNG Backups"
SERVICE_BACKUP="$BACKUP_FOLDER/PSD to PNG-$STAMP.workflow"
STAGED_APP=""; STAGED_SERVICE=""; APP_MOVED=0; SERVICE_MOVED=0; APP_INSTALLED=0; SERVICE_INSTALLED=0
cleanup() {
  [[ -z "$STAGED_APP" ]] || rm -rf "$STAGED_APP"
  [[ -z "$STAGED_SERVICE" ]] || rm -rf "$STAGED_SERVICE"
}
rollback() {
  trap - ERR
  [[ "$SERVICE_INSTALLED" == 0 ]] || rm -rf "$SERVICE"
  [[ "$APP_INSTALLED" == 0 ]] || rm -rf "$TARGET"
  [[ "$APP_MOVED" == 0 ]] || mv "$TARGET_BACKUP" "$TARGET"
  [[ "$SERVICE_MOVED" == 0 ]] || mv "$SERVICE_BACKUP" "$SERVICE"
  echo "Installation failed. Previous installation restored." >&2
  if [[ "$QUIET" != 1 ]]; then /usr/bin/osascript -e 'display alert "PSD to PNG — Installation failed" message "Installation could not be completed. The previous installation was restored. See Terminal for details."' || true; fi
  exit 1
}
trap cleanup EXIT
trap rollback ERR
[[ -x "$ROOT/dist/bin/psd-to-png" ]]
"$ROOT/dist/bin/psd-to-png" --version
mkdir -p "$USER_ROOT/Library/Application Support" "$USER_ROOT/Library/Services"
STAGED_APP=$(mktemp -d "$USER_ROOT/Library/Application Support/.psd-to-png-install.XXXXXX")
STAGED_SERVICE=$(mktemp -d "$USER_ROOT/Library/Services/.psd-to-png-install.XXXXXX")
mkdir -p "$STAGED_APP/bin"
cp "$ROOT/dist/bin/psd-to-png" "$STAGED_APP/bin/"
cp "$ROOT/Resources/PSD_to_PNG.command" "$ROOT/LICENSE" "$ROOT/THIRD_PARTY_NOTICES.md" "$ROOT/ABOUT.txt" "$STAGED_APP/"
chmod 755 "$STAGED_APP/bin/psd-to-png" "$STAGED_APP/PSD_to_PNG.command"
cp -R "$ROOT/Resources/PSD to PNG.workflow" "$STAGED_SERVICE/workflow"
if [[ -e "$TARGET" || -L "$TARGET" ]]; then mv "$TARGET" "$TARGET_BACKUP"; APP_MOVED=1; fi
if [[ -e "$SERVICE" || -L "$SERVICE" ]]; then
  mkdir -p "$BACKUP_FOLDER"
  if [[ "$USER_ROOT" == "$HOME" ]]; then
    cp -R "$SERVICE" "$SERVICE_BACKUP"
  else
    mv "$SERVICE" "$SERVICE_BACKUP"; SERVICE_MOVED=1
  fi
fi
mv "$STAGED_APP" "$TARGET"; STAGED_APP=""; APP_INSTALLED=1
if [[ "$USER_ROOT" != "$HOME" ]]; then
  # Isolated test accounts cannot use the desktop installer.
  mv "$STAGED_SERVICE/workflow" "$SERVICE"; SERVICE_INSTALLED=1
fi
trap - ERR
if [[ "$USER_ROOT" == "$HOME" ]]; then
  if [[ "$QUIET" != 1 ]]; then
    /usr/bin/osascript -e 'display dialog "The PSD to PNG converter is ready. Click Continue, then choose Install or Replace in the macOS Quick Action Installer to finish.\n\nMoosh Massacre\ngustavo@mooshmassacre.studio" buttons {"Continue"} default button "Continue" with title "PSD to PNG"'
  fi
  # The native installer performs registration that copying alone does not guarantee.
  # Apple's installer may move its input bundle; provide a disposable staged copy.
  NATIVE_STAGE="$TARGET/Quick Action Installer"
  mkdir -p "$NATIVE_STAGE"
  mv "$STAGED_SERVICE/workflow" "$NATIVE_STAGE/PSD to PNG.workflow"
  /usr/bin/open -a "/System/Library/CoreServices/Automator Installer.app" "$NATIVE_STAGE/PSD to PNG.workflow"
  echo "Choose Install or Replace in Quick Action Installer to finish installation."
fi

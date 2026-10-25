#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Patrick Saade
# Renders the README images from the real views with made-up data. Debug build only.
set -eu
cd "$(dirname "$0")/.."
dd="${TMPDIR:-/tmp}/macpat-snapshots"
xcodegen generate --quiet
xcodebuild -project MacPat.xcodeproj -scheme MacPat -configuration Debug -derivedDataPath "$dd" -quiet build
"$dd/Build/Products/Debug/MacPat.app/Contents/MacOS/MacPat" -MacPatDemo "$PWD/docs/media"
ls -l docs/media

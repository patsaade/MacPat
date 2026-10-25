#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Patrick Saade
# Repo rules CI enforces: no rasters, no network code, SPDX headers, formatting.
set -eu
cd "$(dirname "$0")/.."
fail=0
files=$( (git ls-files; git ls-files --others --exclude-standard) | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done)

raster=$(echo "$files" | grep -iE '\.(png|jpe?g|gif|bmp|tiff?|heic|webp|icns)$' || true)
[ -z "$raster" ] || { echo "raster images are not allowed:"; echo "$raster"; fail=1; }

swift_files=$(echo "$files" | grep -E '\.swift$' || true)

net=$(echo "$swift_files" | xargs grep -nE 'URLSession|NWConnection|NWPathMonitor|CFNetwork|import Network|URLRequest|WKWebView|Process\(\)|/bin/sh|NSAppleScript' || true)
[ -z "$net" ] || { echo "network or shell code found:"; echo "$net"; fail=1; }

for f in $swift_files; do
  head -n 3 "$f" | grep -q 'SPDX-License-Identifier: MIT' || { echo "missing SPDX header: $f"; fail=1; }
done

swift format lint --strict --configuration .swift-format $swift_files >/dev/null 2>&1 || {
  echo "swift-format found issues. Run: swift format --in-place --configuration .swift-format <files>"; fail=1; }

[ "$fail" -eq 0 ] && echo "checks ok"
exit "$fail"

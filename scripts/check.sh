#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Patrick Saade
# Repo rules CI enforces: rasters only as generated README media, no network code,
# one file that may start processes, SPDX headers, formatting.
set -eu
cd "$(dirname "$0")/.."
fail=0
files=$( (git ls-files; git ls-files --others --exclude-standard) | sort -u | while read -r f; do [ -f "$f" ] && echo "$f"; done)

raster=$(echo "$files" | grep -iE '\.(png|jpe?g|gif|bmp|tiff?|heic|webp|icns)$' || true)
stray=$(echo "$raster" | grep -vE '^docs/media/[a-z-]+\.(png|gif)$' || true)
[ -z "$stray" ] || { echo "raster images are only allowed as generated media in docs/media:"; echo "$stray"; fail=1; }
for f in $(echo "$raster" | grep -E '^docs/media/' || true); do
  [ "$(wc -c < "$f")" -le 2097152 ] || { echo "over 2 MB: $f"; fail=1; }
done

icon=$(echo "$files" | grep -E '\.icon/' | grep -vE '\.(svg|json)$' || true)
[ -z "$icon" ] || { echo "the app icon may hold only SVG and JSON:"; echo "$icon"; fail=1; }

swift_files=$(echo "$files" | grep -E '\.swift$' || true)

net=$(echo "$swift_files" | xargs grep -nE 'URLSession|NWConnection|NWPathMonitor|CFNetwork|import Network|URLRequest|WKWebView|/bin/sh|NSAppleScript|NSTask|posix_spawn|execv|[^.A-Za-z]system\(' || true)
[ -z "$net" ] || { echo "network or shell code found:"; echo "$net"; fail=1; }

exec_file=Sources/MacPatCore/Exec.swift
spawn=$(echo "$swift_files" | grep -v "^$exec_file$" | xargs grep -nE 'Process\(|"/usr/bin/osascript"' || true)
[ -z "$spawn" ] || { echo "only $exec_file may start processes:"; echo "$spawn"; fail=1; }

for f in $swift_files; do
  head -n 3 "$f" | grep -q 'SPDX-License-Identifier: MIT' || { echo "missing SPDX header: $f"; fail=1; }
done

swift format lint --strict --configuration .swift-format $swift_files >/dev/null 2>&1 || {
  echo "swift-format found issues. Run: swift format --in-place --configuration .swift-format <files>"; fail=1; }

[ "$fail" -eq 0 ] && echo "checks ok"
exit "$fail"

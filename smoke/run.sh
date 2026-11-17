#!/usr/bin/env bash
# Build and run the video-hdr smoke probe (smoke/probe.swift) on this Mac.
#
#   smoke/run.sh <video-hdr tarball | extracted xcframeworks dir> [clip]
#
# With no clip, smoke/make-levels.sh generates levels_hdr10.mp4. Needs Xcode
# (swiftc), a GUI session and a Metal device. Exits with the probe's status.
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <video-hdr tarball | xcframeworks dir> [clip]" >&2
  exit 2
fi

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

input=$1
if [ -f "$input" ]; then
  tar -xzf "$input" -C "$work"
  xcframeworks=$(echo "$work"/*/)
else
  xcframeworks=$(cd "$input" && pwd)
fi

# One directory holding the macOS slice of every framework.
mkdir -p "$work/Frameworks"
for framework in "$xcframeworks"/*.xcframework/macos-*/*.framework; do
  cp -R "$framework" "$work/Frameworks/"
done
test -d "$work/Frameworks/Mpv.framework" || {
  echo "no Mpv.framework in $xcframeworks" >&2
  exit 1
}

if [ $# -eq 2 ]; then
  clip=$2
else
  "$here/make-levels.sh" "$work/clips"
  clip=$work/clips/levels_hdr10.mp4
fi

xcrun swiftc -O \
  -F "$work/Frameworks" -framework Mpv \
  -Xlinker -rpath -Xlinker "$work/Frameworks" \
  -o "$work/probe" "$here/probe.swift"

"$work/probe" "$clip"

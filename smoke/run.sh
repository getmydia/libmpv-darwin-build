#!/usr/bin/env bash
# Build and run the video-hdr smoke probe (smoke/probe.swift) on this Mac.
#
#   smoke/run.sh <video-hdr tarball | extracted xcframeworks dir> [clip]
#
# SMOKE_SLEEP_DISPLAYS=1 passes --sleep-displays to the probe (see probe.swift).
#
# With no clip, smoke/make-levels.sh generates levels_hdr10.mp4 (ffmpeg with
# zscale and libx265, or Nix). Needs Xcode (swiftc), a GUI session and a real
# Metal device. Exits with the probe's status.
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
  "$here/make-levels.sh" "$work/clips" --hdr10-only
  clip=$work/clips/levels_hdr10.mp4
fi

xcrun swiftc -O \
  -F "$work/Frameworks" -framework Mpv \
  -Xlinker -rpath -Xlinker "$work/Frameworks" \
  -o "$work/probe" "$here/probe.swift"

status=0
probe_args=("$clip")
[ -n "${SMOKE_SLEEP_DISPLAYS:-}" ] && probe_args+=(--sleep-displays)
"$work/probe" "${probe_args[@]}" || status=$?

# A crash (signal) leaves a report behind; print its faulting thread.
if [ "$status" -gt 128 ]; then
  reports=~/Library/Logs/DiagnosticReports
  for _ in $(seq 30); do
    report=$(ls -t "$reports"/probe-*.ips 2>/dev/null | head -1 || true)
    [ -n "$report" ] && [ "$report" -nt "$work/probe" ] && break
    report=
    sleep 1
  done
  if [ -n "$report" ]; then
    echo "== crash report $report"
    python3 -I - "$report" <<'PY'
import json, sys
text = open(sys.argv[1]).read()
body = json.loads(text[text.index("\n") + 1:])
images = body.get("usedImages", [])
print("exception:", json.dumps(body.get("exception")), json.dumps(body.get("termination", {}).get("indicator")))
for i, thread in enumerate(body.get("threads", [])):
    if not thread.get("triggered"):
        continue
    print(f"thread {i} {thread.get('name') or thread.get('queue') or ''}")
    for frame in thread.get("frames", [])[:40]:
        image = images[frame["imageIndex"]].get("name", "?") if frame.get("imageIndex", -1) < len(images) else "?"
        print(f"  {image:24} {frame.get('symbol', hex(frame.get('imageOffset', 0)))}+{frame.get('symbolLocation', '')}")
PY
  else
    echo "== no crash report found in $reports"
  fi
fi
exit "$status"

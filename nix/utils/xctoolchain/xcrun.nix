{
  pkgs ? import ../default/pkgs.nix,
}:

# A minimal `xcrun` for build systems that locate Xcode tools with it (mpv's
# Swift build does). The real one depends on `xcode-select` state, which the
# Nix sandbox does not have. Supports `-find <tool>` (alias `--find`),
# `--show-sdk-path` and `--show-sdk-version`, with an optional `--sdk macosx`.
let
  developer = "${pkgs.darwin.xcode}/Contents/Developer";
  xctoolchain = "${developer}/Toolchains/XcodeDefault.xctoolchain/usr/bin";
  sdk = "${developer}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
in

pkgs.writeShellScriptBin "xcrun" ''
  set -eu
  while [ $# -gt 0 ]; do
    case "$1" in
      --sdk | -sdk)
        if [ "$2" != macosx ]; then
          echo "xcrun: unsupported sdk $2" >&2
          exit 1
        fi
        shift 2
        ;;
      -find | --find)
        if [ -x "${xctoolchain}/$2" ]; then
          echo "${xctoolchain}/$2"
        elif [ -x "${developer}/usr/bin/$2" ]; then
          echo "${developer}/usr/bin/$2"
        else
          echo "xcrun: unable to find utility \"$2\"" >&2
          exit 1
        fi
        exit 0
        ;;
      --show-sdk-path)
        echo "${sdk}"
        exit 0
        ;;
      --show-sdk-version)
        ${pkgs.python3}/bin/python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["Version"])' \
          "${sdk}/SDKSettings.json"
        exit 0
        ;;
      *)
        echo "xcrun: unsupported arguments: $*" >&2
        exit 1
        ;;
    esac
  done
''

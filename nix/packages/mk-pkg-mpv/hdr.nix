# mpv for the `hdr` flavor (macOS, video): `video-default`'s mpv plus
# `vo=gpu-next` on Vulkan (`gpu-context=macvk`), rendered by libplacebo on
# MoltenVK, with VideoToolbox decoding into it (`videotoolbox-pl`).
#
# It builds a newer mpv than the other flavors (see packages.lock.nix), whose
# options differ, hence its own file. The OpenGL path of `video-default`
# (`gl-cocoa`, `videotoolbox-gl`, the render API) stays enabled.
{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
  variant ? import ../../utils/default/variant.nix,
}:

let
  name = "mpv";
  packageLock = (import ../../../packages.lock.nix).mpvHdr;
  inherit (packageLock) version;

  flavors = import ../../utils/constants/flavors.nix;
  variants = import ../../utils/constants/variants.nix;
  oses = import ../../utils/constants/oses.nix;
  archs = import ../../utils/constants/archs.nix;
  hdr = import ../../utils/constants/hdr.nix;
  flavor = flavors.hdr;
  callPackage = pkgs.lib.callPackageWith {
    inherit
      pkgs
      os
      arch
      variant
      flavor
      ;
  };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix {
    minVersion = hdr.macosMinVersion;
  };
  xctoolchainLipo = callPackage ../../utils/xctoolchain/lipo.nix { };
  xctoolchainInstallNameTool = callPackage ../../utils/xctoolchain/install-name-tool.nix { };
  xctoolchainOtool = callPackage ../../utils/xctoolchain/otool.nix { };
  xctoolchainXcrun = callPackage ../../utils/xctoolchain/xcrun.nix { };
  ffmpeg = callPackage ../mk-pkg-ffmpeg/default.nix { };
  uchardet = callPackage ../mk-pkg-uchardet/default.nix { };
  libass = callPackage ../mk-pkg-libass/default.nix { };
  libplacebo = callPackage ../mk-pkg-libplacebo/default.nix { };
  moltenvk = callPackage ../mk-pkg-moltenvk/default.nix { };
  shaderc = callPackage ../mk-pkg-shaderc/default.nix { };

  swiftTarget =
    (
      if arch == archs.arm64 then
        "arm64"
      else if arch == archs.amd64 then
        "x86_64"
      else
        abort "Arch ${arch} is not supported"
    )
    + "-apple-macos${hdr.macosMinVersion}";

  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
    xctoolchainLipo
    xctoolchainInstallNameTool
    xctoolchainOtool
    xctoolchainXcrun
  ];

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  fixedSource = callPackage ../../utils/patch-shebangs/default.nix {
    name = "${pname}-fixed-source-${variant}-${flavor}-${version}";
    inherit src;
    inherit nativeBuildInputs;
  };
in

assert pkgs.lib.assertMsg (
  os == oses.macos && variant == variants.video
) "the hdr flavor of mpv is macOS video only";

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${variant}-${flavor}-${version}";
  pname = pname;
  inherit version;
  src = fixedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  inherit nativeBuildInputs;
  buildInputs = [
    ffmpeg
    uchardet
    libass
    libplacebo
    moltenvk
    shaderc
  ];
  configurePhase = ''
    # swiftc writes its module cache under $HOME
    export HOME=$TMPDIR

    OPTIONS=(
      # every `auto` feature is disabled unless enabled below
      --auto-features=disabled

      # booleans
      -Dgpl=false # LGPL build, like video-default
      -Dcplayer=false # mpv CLI player
      -Dlibmpv=true # libmpv library
      -Dbuild-date=true # include compile timestamp in binary
      -Dtests=false
      -Dfuzzers=false

      # misc features
      -Dlua=disabled # Lua (a combo, not a feature)
      -Diconv=enabled # iconv
      -Duchardet=enabled # uchardet support
      -Dzlib=enabled # zlib

      # audio output features
      -Dcoreaudio=enabled # CoreAudio audio output

      # video output features
      -Dcocoa=enabled # Cocoa
      -Dgl=enabled # OpenGL context support
      -Dgl-cocoa=enabled # OpenGL Cocoa backend
      -Dplain-gl=enabled # OpenGL without platform-specific code (render API)
      -Dvulkan=enabled # Vulkan context support (macvk with Swift below)

      # hwaccel features
      -Dvideotoolbox-gl=enabled # Videotoolbox with OpenGL
      -Dvideotoolbox-pl=enabled # Videotoolbox with libplacebo

      # macOS features
      -Dmacos-10-15-4-features=enabled
      -Dmacos-11-features=enabled
      -Dmacos-11-3-features=enabled
      -Dmacos-12-features=enabled
      -Dswift-build=enabled # mac_common.swift, needed by gpu-context=macvk
      "-Dswift-flags=-target ${swiftTarget} -module-cache-path $TMPDIR/swift-module-cache"
    )

    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      "''${OPTIONS[@]}" |
      tee configure.log
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build

    # The Swift link flags add an rpath to the Swift libraries of the Xcode
    # that built it. At runtime the OS copy in /usr/lib/swift is used.
    for lib in $out/lib/libmpv.*.dylib; do
      if [ ! -L $lib ]; then
        otool -l $lib | sed -n 's|^ *path \(.*\) (offset.*|\1|p' | while read rpath; do
          if [ "$rpath" != /usr/lib/swift ]; then
            install_name_tool -delete_rpath "$rpath" $lib
          fi
        done
      fi
    done

    # copy configure.log
    mkdir -p $out/share/mpv
    cp configure.log $out/share/mpv/
  '';
}

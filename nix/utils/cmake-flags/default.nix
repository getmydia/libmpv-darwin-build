# CMake flags that cross-compile for `os`/`arch` with the toolchain of Xcode.app,
# the CMake counterpart of ../cross-file. macOS only for now: the packages
# built with CMake are those of the `hdr` flavor.
{
  pkgs ? import ../default/pkgs.nix,
  os ? import ../default/os.nix,
  arch ? pkgs.callPackage ../default/arch.nix { },
  minVersion,
}:

let
  oses = import ../constants/oses.nix;
  archs = import ../constants/archs.nix;
  xctoolchain = "${pkgs.darwin.xcode}/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin";
  sdk = "${pkgs.darwin.xcode}/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";
  cmakeArch =
    if arch == archs.arm64 then
      "arm64"
    else if arch == archs.amd64 then
      "x86_64"
    else
      abort "Arch ${arch} is not supported";
in

assert pkgs.lib.assertMsg (os == oses.macos) "cmake-flags: os ${os} is not supported";

[
  "-DCMAKE_BUILD_TYPE=Release"
  "-DCMAKE_OSX_ARCHITECTURES=${cmakeArch}"
  "-DCMAKE_OSX_SYSROOT=${sdk}"
  "-DCMAKE_OSX_DEPLOYMENT_TARGET=${minVersion}"
  "-DCMAKE_C_COMPILER=${xctoolchain}/clang"
  "-DCMAKE_CXX_COMPILER=${xctoolchain}/clang++"
  "-DCMAKE_OBJC_COMPILER=${xctoolchain}/clang"
  "-DCMAKE_OBJCXX_COMPILER=${xctoolchain}/clang++"
  "-DCMAKE_AR=${xctoolchain}/ar"
  "-DCMAKE_RANLIB=${xctoolchain}/ranlib"
  "-DCMAKE_NM=${xctoolchain}/nm"
  "-DCMAKE_STRIP=${xctoolchain}/strip"
  "-DCMAKE_LIPO=${xctoolchain}/lipo"
  "-DCMAKE_INSTALL_NAME_TOOL=${xctoolchain}/install_name_tool"
  "-DCMAKE_OTOOL=${xctoolchain}/otool"
  "-DCMAKE_INSTALL_LIBDIR=lib"
]

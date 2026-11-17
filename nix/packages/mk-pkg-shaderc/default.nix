# shaderc, the GLSL to SPIR-V compiler libplacebo uses to build its shaders at
# runtime. Only the static `libshaderc_combined` (shaderc, glslang and
# SPIRV-Tools in one archive) is installed: libplacebo links it in, so it does
# not ship as a framework of its own.
{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "shaderc";
  packagesLock = import ../../../packages.lock.nix;
  packageLock = packagesLock.${name};
  inherit (packageLock) version;
  hdr = import ../../utils/constants/hdr.nix;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  cmakeFlags = callPackage ../../utils/cmake-flags/default.nix {
    minVersion = hdr.macosMinVersion;
  };

  pname = import ../../utils/name/package.nix name;
  fetchSource =
    lockName:
    callPackage ../../utils/fetch-tarball/default.nix {
      name = "${pname}-${lockName}-source-${packagesLock.${lockName}.version}";
      inherit (packagesLock.${lockName}) url sha256;
    };
  src = fetchSource name;
  glslang = fetchSource "shadercGlslang";
  spirvTools = fetchSource "shadercSpirvTools";
  spirvHeaders = fetchSource "shadercSpirvHeaders";
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
    pkgs.python3
  ];
  configurePhase = ''
    cmake -S ${src} -B build -G Ninja \
      ${pkgs.lib.concatStringsSep " " cmakeFlags} \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DSHADERC_GLSLANG_DIR=${glslang} \
      -DSHADERC_SPIRV_TOOLS_DIR=${spirvTools} \
      -DSHADERC_SPIRV_HEADERS_DIR=${spirvHeaders} \
      -DSHADERC_SKIP_TESTS=ON \
      -DSHADERC_SKIP_EXAMPLES=ON \
      -DSHADERC_SKIP_EXECUTABLES=ON \
      -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
      -DSHADERC_ENABLE_WERROR_COMPILE=OFF \
      -DSHADERC_ENABLE_HLSL=OFF \
      -DSPIRV_SKIP_EXECUTABLES=ON \
      -DSPIRV_SKIP_TESTS=ON \
      -DSPIRV_WERROR=OFF \
      -DENABLE_GLSLANG_BINARIES=OFF \
      -DENABLE_HLSL=OFF \
      -DGLSLANG_TESTS=OFF \
      -DGLSLANG_ENABLE_INSTALL=OFF
  '';
  buildPhase = ''
    cmake --build build --target shaderc_combined
  '';
  installPhase = ''
    mkdir -p $out/lib/pkgconfig $out/include
    cp build/libshaderc/libshaderc_combined.a $out/lib/
    cp -r ${src}/libshaderc/include/shaderc $out/include/

    # shaderc's own .pc files call the library `shaderc_combined` and leave
    # out the C++ runtime; libplacebo asks for `shaderc`
    cat > $out/lib/pkgconfig/shaderc.pc <<EOF
    prefix=$out
    libdir=$out/lib
    includedir=$out/include

    Name: shaderc
    Description: GLSL to SPIR-V compiler (static, with glslang and SPIRV-Tools)
    Version: ${version}
    Libs: -L$out/lib -lshaderc_combined -lc++
    Cflags: -I$out/include
    EOF
  '';
}

# MoltenVK, the Vulkan implementation on Metal, built from source with its
# CMake build. It is the only Vulkan library in the `hdr` flavor: libplacebo
# and mpv link it directly, so no Vulkan loader or ICD manifest is involved.
#
# It is a shared library on purpose: libplacebo and mpv must share one
# instance of it, since mpv creates the Metal surface on the VkInstance
# libplacebo created.
#
# Besides MoltenVK itself, the output holds the Vulkan headers and registry it
# was built with, and a `vulkan.pc` naming MoltenVK as the Vulkan library, which
# libplacebo and mpv find through pkg-config.
{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "moltenvk";
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
  cereal = fetchSource "moltenvkCereal";
  spirvCross = fetchSource "moltenvkSpirvCross";
  vulkanHeaders = fetchSource "moltenvkVulkanHeaders";
  cpm = builtins.fetchurl {
    inherit (packagesLock.moltenvkCpm) url sha256;
  };
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
    pkgs.git
  ];
  configurePhase = ''
    # CPM (MoltenVK's dependency fetcher) uses the pinned sources below and
    # never touches the network
    export CPM_SOURCE_CACHE=$PWD/cpm-cache
    mkdir -p $CPM_SOURCE_CACHE/cpm
    cp ${cpm} $CPM_SOURCE_CACHE/cpm/CPM_${packagesLock.moltenvkCpm.version}.cmake

    cmake -S ${src} -B build -G Ninja \
      ${pkgs.lib.concatStringsSep " " cmakeFlags} \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DMVK_EXCLUDE_SPIRV_TOOLS=ON \
      -DMVK_USE_METAL_PRIVATE_API=OFF \
      -DMVK_BUILD_SHADER_CONVERTER_TOOL=OFF \
      -DMOLTEN_VK_WITH_CCACHE=OFF \
      -DCPM_cereal_SOURCE=${cereal} \
      -DCPM_SPIRV-Cross_SOURCE=${spirvCross} \
      -DCPM_Vulkan-Headers_SOURCE=${vulkanHeaders}
  '';
  buildPhase = ''
    cmake --build build --target MoltenVK
  '';
  installPhase = ''
    # manual install: MoltenVK's install rules also ship an ICD manifest,
    # which nothing here uses
    mkdir -p $out/lib/pkgconfig $out/include
    find build -maxdepth 2 -name 'libMoltenVK*.dylib' -exec cp -P {} $out/lib/ \;
    test -f $out/lib/libMoltenVK.dylib
    cp -r ${src}/MoltenVK/include/MoltenVK $out/include/

    # the Vulkan headers and registry MoltenVK was built against
    mkdir -p $out/include $out/share/vulkan
    cp -r ${vulkanHeaders}/include/vulkan ${vulkanHeaders}/include/vk_video $out/include/
    cp -r ${vulkanHeaders}/registry $out/share/vulkan/registry

    # MoltenVK stands in for the Vulkan loader
    cat > $out/lib/pkgconfig/vulkan.pc <<EOF
    prefix=$out
    libdir=$out/lib
    includedir=$out/include

    Name: vulkan
    Description: Vulkan implemented by MoltenVK ${version}
    Version: ${packagesLock.moltenvkVulkanHeaders.version}
    Libs: -L$out/lib -lMoltenVK
    Cflags: -I$out/include
    EOF
  '';
}

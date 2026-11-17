# libplacebo, the renderer behind mpv's `vo=gpu-next`. Vulkan only: it links
# MoltenVK directly (`vk-proc-addr`) and compiles its shaders with a static
# shaderc.
{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libplacebo";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;
  hdr = import ../../utils/constants/hdr.nix;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix {
    minVersion = hdr.macosMinVersion;
  };
  # meson runs `lipo` from $PATH on the libraries pkg-config names
  xctoolchainLipo = callPackage ../../utils/xctoolchain/lipo.nix { };
  moltenvk = callPackage ../mk-pkg-moltenvk/default.nix { };
  shaderc = callPackage ../mk-pkg-shaderc/default.nix { };

  # libplacebo generates code with jinja2 (its own copy is a git submodule,
  # missing from the release tarball)
  python = pkgs.python3.withPackages (ps: [ ps.jinja2 ]);

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  inherit src;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    python
    xctoolchainLipo
  ];
  buildInputs = [
    moltenvk
    shaderc
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out \
      --buildtype=release \
      -Ddefault_library=shared \
      -Dvulkan=enabled \
      -Dvk-proc-addr=enabled \
      -Dvulkan-registry=${moltenvk}/share/vulkan/registry/vk.xml \
      -Dshaderc=enabled \
      -Dglslang=disabled \
      -Dopengl=disabled \
      -Dd3d11=disabled \
      -Dlcms=disabled \
      -Ddovi=enabled \
      -Dlibdovi=disabled \
      -Dunwind=disabled \
      -Dxxhash=disabled \
      -Ddemos=false \
      -Dtests=false \
      -Dbench=false \
      -Dfuzz=false |
      tee configure.log
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build

    # copy configure.log
    mkdir -p $out/share/libplacebo
    cp configure.log $out/share/libplacebo/
  '';
}

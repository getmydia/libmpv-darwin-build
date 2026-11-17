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
  packagesLock = import ../../../packages.lock.nix;
  packageLock = packagesLock.${name};
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
  # missing from the release tarball). It goes on PYTHONPATH because meson
  # runs the bare interpreter, not a `withPackages` wrapper.
  python = pkgs.python3;
  pythonPath = python.pkgs.makePythonPath [ python.pkgs.jinja2 ];

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  fastFloat = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-fast-float-source-${packagesLock.libplaceboFastFloat.version}";
    inherit (packagesLock.libplaceboFastFloat) url sha256;
  };
  # put back the fast_float submodule, required on Apple (libc++ has no
  # floating point std::from_chars)
  patchedSource = pkgs.runCommand "${pname}-patched-source-${version}" { } ''
    cp -r ${src} src
    chmod -R u+w src
    rm -rf src/3rdparty/fast_float
    cp -r ${fastFloat} src/3rdparty/fast_float
    cp -r src $out
  '';
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = patchedSource;
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
    export PYTHONPATH=${pythonPath}

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

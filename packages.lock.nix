{
  dav1d = {
    version = "1.2.1";
    url = "https://code.videolan.org/videolan/dav1d/-/archive/1.2.1/dav1d-1.2.1.tar.bz2";
    sha256 = "a4003623cdc0109dec3aac8435520aa3fb12c4d69454fa227f2658cdb6dab5fa";
  };
  ffmpeg = {
    version = "6.0";
    url = "https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz";
    sha256 = "57be87c22d9b49c112b6d24bc67d42508660e6b718b3db89c44e47e289137082";
  };
  # The `hdr` flavor needs mpv 0.42, which requires FFmpeg >= 6.1.
  ffmpegHdr = {
    version = "8.0.3";
    url = "https://ffmpeg.org/releases/ffmpeg-8.0.3.tar.xz";
    sha256 = "6136812ea6d4e68bdba27e33c2a94382711cdf4f8602ffef056ff792bd6f9818";
  };
  fftools-ffi = {
    version = "9b0d4da0";
    url = "https://github.com/moffatman/fftools-ffi/archive/9b0d4da026d9c830702ec043c1f1f98d407025af.tar.gz";
    sha256 = "mgf3ddt3yjmYBd2D0WeEnhgxKNjrEbjYnDx2t4YCfU8=";
  };
  freetype = {
    version = "2.13.2";
    url = "https://downloads.sourceforge.net/project/freetype/freetype2/2.13.2/freetype-2.13.2.tar.xz";
    sha256 = "12991c4e55c506dd7f9b765933e62fd2be2e06d421505d7950a132e4f1bb484d";
  };
  fribidi = {
    version = "1.0.13";
    url = "https://github.com/fribidi/fribidi/releases/download/v1.0.13/fribidi-1.0.13.tar.xz";
    sha256 = "7fa16c80c81bd622f7b198d31356da139cc318a63fc7761217af4130903f54a2";
  };
  harfbuzz = {
    version = "8.1.1";
    url = "https://github.com/harfbuzz/harfbuzz/archive/8.1.1.tar.gz";
    sha256 = "b16e6bc0fc7e6a218583f40c7d201771f2e3072f85ef6e9217b36c1dc6b2aa25";
  };
  libass = {
    version = "0.17.1";
    url = "https://github.com/libass/libass/releases/download/0.17.1/libass-0.17.1.tar.xz";
    sha256 = "f0da0bbfba476c16ae3e1cfd862256d30915911f7abaa1b16ce62ee653192784";
  };
  libogg = {
    version = "1.3.5";
    url = "https://github.com/xiph/ogg/releases/download/v1.3.5/libogg-1.3.5.tar.gz";
    sha256 = "0eb4b4b9420a0f51db142ba3f9c64b333f826532dc0f48c6410ae51f4799b664";
  };
  libplacebo = {
    version = "7.387.0";
    url = "https://github.com/haasn/libplacebo/archive/refs/tags/v7.387.0.tar.gz";
    sha256 = "f9e62d3774a9c4cfd198ec3abaa88294aaade2e31c04d5ab02bcf4abc98b1df5";
  };
  # The fast_float submodule of libplacebo v7.387.0 (missing from its tarball)
  libplaceboFastFloat = {
    version = "8.2.2";
    url = "https://github.com/fastfloat/fast_float/archive/97b54ca9e75f5303507699d27c6b4f4efe4641a1.tar.gz";
    sha256 = "2b132274539286e41f37857cac22aa8441d21bd86d55de825a3342b149f66801";
  };
  libpng = {
    version = "1.6.40";
    url = "https://github.com/pnggroup/libpng/archive/v1.6.40.tar.gz";
    sha256 = "62d25af25e636454b005c93cae51ddcd5383c40fa14aa3dae8f6576feb5692c2";
  };
  libpngPatch = {
    version = "1.6.40-1";
    url = "https://wrapdb.mesonbuild.com/v2/libpng_1.6.40-1/get_patch";
    sha256 = "bad558070e0a82faa5c0ae553bcd12d49021fc4b628f232a8e58c3fbd281aae1";
  };
  libvorbis = {
    version = "1.3.7";
    url = "https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz";
    sha256 = "0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab";
  };
  libvpx = {
    version = "1.13.0+1";
    url = "https://gitlab.freedesktop.org/gstreamer/meson-ports/libvpx/-/archive/90d26fac0d895969a82cd873ad36e39737104c44/libvpx-v1.13.0.tar.gz";
    sha256 = "4f872ad2709d17b848b3588231495e432c42b9263731b9121fa210a3c5a893ff";
  };
  libx264 = {
    version = "a8b68ebf";
    url = "https://code.videolan.org/videolan/x264/-/archive/a8b68ebfaa68621b5ac8907610d3335971839d52/libx264-a8b68ebfaa68621b5ac8907610d3335971839d52.tar.gz";
    sha256 = "164688b63f11a6e4f6d945057fc5c57d5eefb97973d0029fb0303744e10839ff";
  };
  libxml2 = {
    version = "2.11.5";
    url = "https://download.gnome.org/sources/libxml2/2.11/libxml2-2.11.5.tar.xz";
    sha256 = "3727b078c360ec69fa869de14bd6f75d7ee8d36987b071e6928d4720a28df3a6";
  };
  mbedtls = {
    version = "3.4.1";
    url = "https://github.com/Mbed-TLS/mbedtls/archive/refs/tags/v3.4.1.tar.gz";
    sha256 = "a420fcf7103e54e775c383e3751729b8fb2dcd087f6165befd13f28315f754f5";
  };
  # MoltenVK and the dependencies its CMake build would otherwise fetch with
  # CPM. Revisions are the ones in MoltenVK's `ExternalRevisions/`.
  moltenvk = {
    version = "1.4.2";
    url = "https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v1.4.2.tar.gz";
    sha256 = "6864db532f1dbbdb621a8d0ec13f24edae318fd9269dd3dd0cdff791334bb1cb";
  };
  moltenvkCereal = {
    version = "a56bad8b";
    url = "https://github.com/USCiLab/cereal/archive/a56bad8bbb770ee266e930c95d37fff2a5be7fea.tar.gz";
    sha256 = "12e10fb541270632f6683286ce8c7e8c321fe4addb53fa91ed498b95c1758f93";
  };
  moltenvkCpm = {
    version = "0.40.8";
    url = "https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.8/CPM.cmake";
    sha256 = "78ba32abdf798bc616bab7c73aac32a17bbd7b06ad9e26a6add69de8f3ae4791";
  };
  moltenvkSpirvCross = {
    version = "6c09849f";
    url = "https://github.com/KhronosGroup/SPIRV-Cross/archive/6c09849fe88c48eaed08413aa022aaa136a3a057.tar.gz";
    sha256 = "b81b9956289950570953738e666a031ca32ff64e4fc925eba89f227c42109518";
  };
  # Vulkan 1.4.357. Also the headers and registry libplacebo and mpv build
  # against, so all three agree on one Vulkan API version.
  moltenvkVulkanHeaders = {
    version = "1.4.357";
    url = "https://github.com/KhronosGroup/Vulkan-Headers/archive/e3b1eec08173d6b825cd3ac88c885a63b621504a.tar.gz";
    sha256 = "f492279345cbc10708b64fcd432b3ff6c8246a5837c4db2b649abba00cf82208";
  };
  mpv = {
    version = "0.36.0";
    url = "https://github.com/mpv-player/mpv/archive/refs/tags/v0.36.0.tar.gz";
    sha256 = "29abc44f8ebee013bb2f9fe14d80b30db19b534c679056e4851ceadf5a5e8bf6";
  };
  # The `hdr` flavor: vo=gpu-next on macOS (Vulkan through MoltenVK) with
  # libplacebo 7.387 needs mpv >= 0.42.
  mpvHdr = {
    version = "0.42.0";
    url = "https://github.com/mpv-player/mpv/archive/refs/tags/v0.42.0.tar.gz";
    sha256 = "bcfebbfa2b65a6d88dc97ea18117831072373e38b5785a2afb874ed4df5070dd";
  };
  # shaderc and the dependencies listed in its `DEPS` file.
  shaderc = {
    version = "2026.4";
    url = "https://github.com/google/shaderc/archive/refs/tags/v2026.4.tar.gz";
    sha256 = "f06ce5bcca94e5df7f34e115743597d0ad2e13c5fe9213c67dc8c76031241947";
  };
  shadercGlslang = {
    version = "e1b562a8";
    url = "https://github.com/KhronosGroup/glslang/archive/e1b562a8bed273a02f30b59b66a5d499793cede5.tar.gz";
    sha256 = "907174a24713c6202c146f164bf81783f1fbc79c8cb821a30f18f159eb980312";
  };
  shadercSpirvHeaders = {
    version = "04fd3caa";
    url = "https://github.com/KhronosGroup/SPIRV-Headers/archive/04fd3caa1e8267e4d95c806cad901181728e1006.tar.gz";
    sha256 = "392f4801409aad9c4f1b77745f179952fd6264e4c8bd0fc1bc45dfa6807bf6d0";
  };
  shadercSpirvTools = {
    version = "ef96ed76";
    url = "https://github.com/KhronosGroup/SPIRV-Tools/archive/ef96ed763b43b59b33b31b362f09a02b729fa1c9.tar.gz";
    sha256 = "82c62146083fd558735a3171cf97cfc47903ca7d368482e87f94bd44883c0f00";
  };
  uchardet = {
    version = "0.0.8";
    url = "https://www.freedesktop.org/software/uchardet/releases/uchardet-0.0.8.tar.xz";
    sha256 = "e97a60cfc00a1c147a674b097bb1422abd9fa78a2d9ce3f3fdcc2e78a34ac5f0";
  };
}

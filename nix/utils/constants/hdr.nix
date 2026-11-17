{
  # Minimum macOS for the packages only the `hdr` flavor builds (MoltenVK,
  # shaderc, libplacebo and mpv). mpv's Vulkan context is written in Swift, and
  # 12.0 keeps Swift concurrency in the OS rather than back-deployed.
  macosMinVersion = "12.0";
}

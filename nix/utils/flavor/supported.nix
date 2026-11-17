# Whether a flavor is built for a given os and variant. Every flavor is built
# everywhere except `hdr`, which exists for macOS video only.
{
  os,
  variant,
  flavor,
}:

let
  flavors = import ../constants/flavors.nix;
  oses = import ../constants/oses.nix;
  variants = import ../constants/variants.nix;
in

flavor != flavors.hdr || (os == oses.macos && variant == variants.video)

{
  pkgs ? import ../default/pkgs.nix,
  os ? import ../default/os.nix,
  arch ? pkgs.callPackage ../default/arch.nix { },
  # Overrides the minimum OS version of the cross file, e.g. "12.0".
  minVersion ? null,
}:

pkgs.runCommand
  "mk-cross-file-${os}-${arch}${pkgs.lib.optionalString (minVersion != null) "-${minVersion}"}.ini"
  { }
  (
    ''
      cp ${../../../cross-files/${os}-${arch}.ini} cross-file.ini
      sed -i "s|/Applications/Xcode.app|${pkgs.darwin.xcode}|g" cross-file.ini
    ''
    + pkgs.lib.optionalString (minVersion != null) ''
      sed -i -E "s|(-m[a-z-]*-version-min=)[0-9.]+|\1${minVersion}|" cross-file.ini
      grep -q -- "-version-min=${minVersion}'" cross-file.ini
    ''
    + ''
      cp cross-file.ini $out
    ''
  )

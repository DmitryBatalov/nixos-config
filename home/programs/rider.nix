{
  inputs,
  osConfig,
  pkgs,
  ...
}: let
  proxy = osConfig.local.proxy;

  # Rider is pinned to a specific nixpkgs-unstable rev (see flake.nix) so it
  # reuses the build already in the store instead of re-downloading the tarball.
  # This one stays a direct import: it is a different nixpkgs rev from
  # pkgs.unstable, and it has exactly one consumer.
  riderUnstable = import inputs.nixpkgs-rider {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  riderPkgs = import ./rider-fhs.nix {
    inherit pkgs;
    unstable = riderUnstable;
    inherit (proxy) socksAddress socksPort;
  };
in {
  home.packages = [riderPkgs.fhs];

  # Rider lives inside an FHS env, so it ships no desktop entry of its own.
  xdg.desktopEntries.rider = {
    name = "Rider";
    exec = "rider";
    icon = "${riderPkgs.rider}/share/pixmaps/rider.svg";
    comment = "JetBrains Rider IDE";
    categories = ["Development" "IDE"];
    terminal = false;
  };
}

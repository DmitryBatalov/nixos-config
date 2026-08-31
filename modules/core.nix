{
  lib,
  pkgs,
  username,
  ...
}: {
  # Unconditional, because every host in this flake wants all of it. Anything a
  # host might reasonably not want lives in a feature module with an enable
  # flag instead.

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # Hard-link identical files in the store to save disk; complements the
    # weekly GC below.
    auto-optimise-store = true;
  };

  # mkDefault so a host can dial it back without mkForce.
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 7d";
  };

  nixpkgs.config.allowUnfree = true;

  # Just enough to log in and repair the machine. Everything else belongs to
  # whichever feature module actually needs it.
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
  ];

  # The account itself. Group memberships are added by the modules that need
  # them -- networking adds networkmanager, docker adds docker, and so on --
  # so enabling a feature carries its own access along with it.
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };
}

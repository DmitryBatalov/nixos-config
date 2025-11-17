{
  pkgs,
  nixpkgs-unstable,
  lib,
  ...
}: let
  unstable = import nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true; # Explicit config for unstable
  };
in {
  imports = [
    ../../home/core.nix

    ../../home/i3
    ../../home/rofi
  ];

  home.packages = [
    pkgs.flameshot
    pkgs.telegram-desktop
    pkgs.keepassxc
  ];

  programs = {
    git = {
      enable = true;
      userName = "dmitry.batalov";
      userEmail = "dmtiryabat@gmail.com";
      extraConfig = {
        init.defaultBranch = "main";
      };
    };

    bash = {
      enable = true;
      shellAliases = {
        lg = "lazygit";
      };
    };

    alacritty = {
      enable = true;
    };

    lazygit = {
      enable = true;
    };

    firefox = {
      enable = true;
    };

    btop = {
      enable = true;
    };
  };
}

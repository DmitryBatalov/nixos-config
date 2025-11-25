{
  pkgs,
  nixpkgs-unstable,
  config,
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
    pkgs.libreoffice-qt6-fresh
    unstable.jetbrains.rider
    unstable.freelens-bin
    pkgs.freecad
    pkgs.obsidian
    (pkgs.google-cloud-sdk.withExtraComponents [pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin])
    # pkgs.google-cloud-sdk
    pkgs.kubectl
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
        dcu = "docker compose up -d";
        dcd = "docker compose down";
        dcs = "docker compose stop";
        run-rider = "nix-shell ~/projects/nixos-config/home/programs/rider-fhs.nix";
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    ssh.enable = true;
    alacritty.enable = true;
    lazygit.enable = true;

    btop.enable = true;

    firefox.enable = true;
    chromium.enable = true;

    keepassxc.enable = true;
  # enable auto mount of USB disks
  services.udiskie = {
    enable = true;
    settings = {
      # workaround for
      # https://github.com/nix-community/home-manager/issues/632
      program_options = {
        # replace with your favorite file manager
        file_manager = "${pkgs.xfce.thunar}/bin/thunar";
      };
    };
  };
}

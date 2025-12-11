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
    ../../home/kube
  ];

  home.packages = [
    pkgs.flameshot
    pkgs.telegram-desktop
    pkgs.libreoffice-qt6-fresh
    unstable.jetbrains.rider
    pkgs.freecad
    pkgs.obsidian
    pkgs.vlc
  ];

  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = "dmitry.batalov";
          email = "dmtiryabat@gmail.com";
        };
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

    # enable ssh agent (i.e. access remote git repo with ssh key)
    ssh.enable = true;

    # terminal
    alacritty.enable = true;

    # TUI for git
    lazygit.enable = true;

    btop.enable = true;

    firefox.enable = true;
    chromium = {
      enable = true;
    };

    keepassxc = {
      enable = true;
      autostart = true;
      settings = {
        FdoSecrets.Enabled = true; # Enable Secret Service Integration
        GUI.LaunchAtStartup = true;
        # Browser = {
        #   Enabled = true;
        # };
      };
    };
  };

  xdg = {
    enable = true;
    autostart.enable = true; # Enable creation of XDG autostart entries.
    # configFile."mimeapps.list".force = true;
  };

  # enable auto mount of USB disks
  services.udiskie.enable = true;
}

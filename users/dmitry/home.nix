{
  pkgs,
  nixpkgs-unstable,
  nixvim-config,
  claude-config,
  config,
  lib,
  ...
}:
let
  unstable = import nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true; # Explicit config for unstable
  };
in
{
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
    (import ../../home/programs/rider-fhs.nix { inherit pkgs unstable; })
    pkgs.freecad
    pkgs.obsidian
    pkgs.vlc
    nixvim-config.packages.${pkgs.stdenv.hostPlatform.system}.default
    claude-config.packages.${pkgs.stdenv.hostPlatform.system}.default
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
      sessionVariables = {
        EDITOR = "nvim";
      };
      shellAliases = {
        lg = "lazygit";
        dcu = "docker compose up -d";
        dcd = "docker compose down";
        dcs = "docker compose stop";
        dcr = "docker compose stop && docker compose up -d";
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };

    # enable ssh agent (i.e. access remote git repo with ssh key)
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        addKeysToAgent = "yes";
      };
    };

    # terminal
    alacritty = {
      enable = true;
      settings.font.normal.family = "JetBrainsMono Nerd Font";
    };

    # TUI for git
    lazygit.enable = true;

    btop.enable = true;
    ripgrep.enable = true;

    firefox.enable = true;
    chromium = {
      enable = true;
      nativeMessagingHosts = [
        pkgs.keepassxc
      ];
      extensions = [
        { id = "oboonakemofpalcgghocfoadofidjkkk"; } # KeePassXC-Browser
      ];
    };

    keepassxc = {
      enable = true;
      autostart = true;
      settings = {
        FdoSecrets.Enabled = false;
        GUI = {
          CompactMode = true;
          MinimizeOnStartup = true;
          MinimizeOnClose = true;
          MinimizeToTray = true;
          ShowTrayIcon = true;
          TrayIconAppearance = "monochrome-light";
        };
        Browser = {
          Enabled = true;
          BrowserSupport = "chromium";
        };
      };
    };

    tmux = {
      enable = true;
      keyMode = "vi";
      baseIndex = 1;
      mouse = true;
      terminal = "tmux-256color";
      customPaneNavigationAndResize = true;
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = tokyo-night-tmux;
          extraConfig = ''
            set -g @tokyo-night-tmux_theme moon
          '';
        }
      ];
      extraConfig = ''
        set -ag terminal-overrides ",*:RGB"
      '';
    };

  };

  xdg = {
    enable = true;
    autostart.enable = true;
    desktopEntries.rider = {
      name = "Rider";
      exec = "rider";
      icon = "${unstable.jetbrains.rider}/share/pixmaps/rider.svg";
      comment = "JetBrains Rider IDE";
      categories = [ "Development" "IDE" ];
      terminal = false;
    };
  };

  # enable auto mount of USB disks
  services.udiskie.enable = true;
}

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
    ../../home/tmux
    ../../home/kube
  ];

  # KeePassXC native messaging manifest for Chromium
  # The nixpkgs keepassxc only ships a Firefox manifest (allowed_extensions).
  # Chromium requires allowed_origins with the extension's chrome-extension:// URL.
  home.file.".config/chromium/NativeMessagingHosts/org.keepassxc.keepassxc_browser.json" = {
    text = builtins.toJSON {
      name = "org.keepassxc.keepassxc_browser";
      description = "KeePassXC integration with native messaging support";
      path = "${pkgs.keepassxc}/bin/keepassxc-proxy";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
      ];
    };
    force = true;
  };

  home.packages = [
    pkgs.flameshot
    pkgs.telegram-desktop
    pkgs.libreoffice-qt6-fresh
    (import ../../home/programs/rider-fhs.nix { inherit pkgs unstable; })
    pkgs.freecad
    pkgs.bambu-studio
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
        TERMINAL = "alacritty";
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
    desktopEntries.chromium-proxy = {
      name = "Chromium (Proxy)";
      exec = "chromium --proxy-server=\"socks5://127.0.0.1:1081\" %U";
      icon = "chromium";
      comment = "Chromium Web Browser with SOCKS proxy via SSH tunnel";
      categories = [ "Network" "WebBrowser" ];
      terminal = false;
    };
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

{
  pkgs,
  nixpkgs-unstable,
  nixpkgs-rider,
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
  # Rider is pinned to a specific nixpkgs-unstable rev (see flake.nix) so it
  # reuses the build already in the store instead of re-downloading the tarball.
  riderUnstable = import nixpkgs-rider {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  riderPkgs = import ../../home/programs/rider-fhs.nix {
    inherit pkgs;
    unstable = riderUnstable;
  };

  # KeePassXC native messaging manifest for Chromium.
  # The nixpkgs keepassxc only ships a Firefox manifest (allowed_extensions);
  # Chromium requires allowed_origins with the extension's chrome-extension:// URL,
  # so we ship our own package consumed via programs.chromium.nativeMessagingHosts.
  keepassxcChromiumHost = pkgs.writeTextFile {
    name = "keepassxc-chromium-native-messaging-host";
    destination = "/etc/chromium/native-messaging-hosts/org.keepassxc.keepassxc_browser.json";
    text = builtins.toJSON {
      name = "org.keepassxc.keepassxc_browser";
      description = "KeePassXC integration with native messaging support";
      path = "${pkgs.keepassxc}/bin/keepassxc-proxy";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://oboonakemofpalcgghocfoadofidjkkk/"
      ];
    };
  };
in
{
  imports = [
    ../../home/core.nix

    ../../home/sway
    ../../home/rofi
    ../../home/tmux
    ../../home/kube
  ];

  home.packages = [
    pkgs.flameshot
    unstable.telegram-desktop
    pkgs.libreoffice-qt6-fresh
    riderPkgs.fhs
    pkgs.freecad
    pkgs.bambu-studio
    pkgs.obsidian
    pkgs.vlc
    pkgs.evince
    pkgs.xournalpp
    pkgs.typst
    pkgs.mongosh
    pkgs.mariadb.client
    nixvim-config.packages.${pkgs.stdenv.hostPlatform.system}.default
    claude-config.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.xdg-terminal-exec
  ];

  home.sessionVariables = {
    TERMINAL = "kitty";
  };

  programs = {
    git = {
      enable = true;
      ignores = [ ".claude/" ];
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
        BROWSER = "chromium";
      };
      shellAliases = {
        v = "nvim";
        lg = "lazygit";
        dcu = "docker compose up -d";
        dcd = "docker compose down";
        dcdv = "docker compose down -v";
        dcs = "docker compose stop";
        dcr = "docker compose stop && docker compose up -d";
      };
      initExtra = ''
        cdtmp() { cd "$(mktemp -d)"; }
      '';
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
      settings = {
        "*" = {
          AddKeysToAgent = "yes";
        };
        # ASUS RT-AC1200 running Padavan; dropbear v2017.75 only speaks
        # ssh-rsa (SHA-1) for both host and user key auth. Reached via
        # AC1200's WAN-side IP+port from Keenetic LAN (192.168.1.x).
        "ac1200" = {
          HostName = "192.168.1.142";
          Port = 10022;
          User = "admin";
          IdentityFile = "~/.ssh/id_rsa";
          IdentitiesOnly = "yes";
          PubkeyAcceptedAlgorithms = "+ssh-rsa";
          HostkeyAlgorithms = "+ssh-rsa,ecdsa-sha2-nistp521";
        };
      };
    };

    # terminal
    kitty = {
      enable = true;
      themeFile = "gruvbox-dark";
      font = {
        name = "JetBrainsMono NF Light";
        size = 13;
      };
    };

    # TUI for git
    lazygit.enable = true;

    btop.enable = true;
    ripgrep.enable = true;
    fzf.enable = true;

    firefox = {
      enable = true;
      # Silence 26.05 warning: keep legacy non-XDG path until we actually use Firefox.
      configPath = ".mozilla/firefox";
    };
    chromium = {
      enable = true;
      extensions = [
        { id = "oboonakemofpalcgghocfoadofidjkkk"; } # KeePassXC-Browser
      ];
      nativeMessagingHosts = [ keepassxcChromiumHost ];
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
          plugin = gruvbox;
          extraConfig = ''
            set -g @tmux-gruvbox 'dark'
          '';
        }
      ];
      extraConfig = ''
        set -ag terminal-overrides ",*:RGB"
        set -g allow-passthrough on
      '';
    };

  };

  xdg = {
    enable = true;
    autostart.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = "chromium-proxy.desktop";
        "x-scheme-handler/https" = "chromium-proxy.desktop";
        "text/html" = "chromium-proxy.desktop";
        "application/pdf" = "org.gnome.Evince.desktop";
      };
    };
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
      icon = "${riderPkgs.rider}/share/pixmaps/rider.svg";
      comment = "JetBrains Rider IDE";
      categories = [ "Development" "IDE" ];
      terminal = false;
    };
  };

  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    useGrimAdapter=true
    showDesktopNotification=false
    showAbortNotification=false
    showStartupLaunchMessage=false
  '';

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # enable auto mount of USB disks
  services.udiskie.enable = true;
  services.ssh-agent.enable = true;
}

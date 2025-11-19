{
  pkgs,
  lib,
  username,
  ...
}: {
  # ============================= User related =============================

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = ["networkmanager" "wheel"];
  };

  # customise /etc/nix/nix.conf declaratively via `nix.settings`
  nix.settings = {
    # enable flakes globally
    experimental-features = ["nix-command" "flakes"];
  };

  # do garbage collection weekly to keep disk usage low
  nix.gc = {
    automatic = lib.mkDefault true;
    dates = lib.mkDefault "weekly";
    options = lib.mkDefault "--delete-older-than 7d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Set your time zone.
  time.timeZone = "Europe/Samara";

  # Configure console keymap
  console.keyMap = "ru";

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";

    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "ru_RU.UTF-8/UTF-8"
    ];

    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "ru_RU.UTF-8";
    };
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
    ];

    # user defined fonts
    # the reason there's Noto Color Emoji everywhere is to override DejaVu's
    # B&W emojis that would sometimes show instead of some Color emojis
    fontconfig.defaultFonts = {
      monospace = ["JetBrainsMono Nerd Font"];
    };
  };

  programs = {
    dconf.enable = true;
    amnezia-vpn.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Enable the OpenSSH daemon.
  #services.openssh = {
  #  enable = true;
  #  settings = {
  #    X11Forwarding = true;
  #    PermitRootLogin = "no"; # disable root login
  #    PasswordAuthentication = false; # disable password login
  #  };
  #  openFirewall = true;
  #};

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    git
    tree
    sysstat
    lm_sensors # for `sensors` command

    # minimal screen capture tool, used by i3 blur lock to take a screenshot
    # print screen key is also bound to this tool in i3 config
    scrot
    neofetch
    xfce.thunar # xfce4's file manager
    pavucontrol
  ];

  # Enable sound with pipewire.
  # services.pulseaudio.enable = false;
  #services.power-profiles-daemon = {
  #  enable = true;
  #};
  #security.polkit.enable = true;

  hardware.bluetooth.enable = true;

  services = {
    pulseaudio.enable = false;

    dbus.packages = [pkgs.gcr];

    #geoclue2.enable = true;

    blueman.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      # jack.enable = true;

      extraConfig.pipewire."92-low-latency" = {
        context.properties = {
          default.clock.rate = 48000;
          default.clock.quantum = 32;
        };
      };

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    udev.packages = with pkgs; [gnome-settings-daemon];
  };
}

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
      settings = {
        default-cache-ttl-ssh = 86400;
        max-cache-ttl-ssh = 86400;
      };
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
    jq
    tree
    sysstat
    lm_sensors # for `sensors` command

    grim # screenshot tool for Wayland (sway)
    slurp # region selector for Wayland (sway)
    neofetch
    nautilus
    pavucontrol
    calc
    pam_u2f # FIDO2 PAM module + pamu2fcfg registration tool
    libfido2 # FIDO2 library and fido2-token utility
  ];

  # Enable sound with pipewire.
  # services.pulseaudio.enable = false;
  services.power-profiles-daemon = {
    enable = true;
  };
  # security.polkit.enable = true;

  hardware.bluetooth.enable = true;

  # FIDO2 authentication (PIN + touch) as alternative to password
  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      cue = true;
      timeout = 10;
    };
  };

  security.pam.services.login.u2fAuth = true;
  security.pam.services.sudo.u2fAuth = true;
  security.pam.services.xsecurelock.u2fAuth = true;
  security.pam.services.swaylock.u2fAuth = true;

  security.rtkit.enable = true;
  services = {
    pulseaudio.enable = false;

    blueman.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;

      extraConfig.pipewire."92-low-latency" = {
        context.properties = {
          default.clock.rate = 48000;
          default.clock.quantum = 32;
        };
      };

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;

      wireplumber.extraConfig = {
        # Boost Bluetooth sink priority so it's always preferred
        "10-bluetooth-priority" = {
          "monitor.bluez.rules" = [{
            matches = [{ "node.name" = "~bluez_output.*"; }];
            actions.update-props."priority.session" = 2000;
          }];
        };

        # Force Speaker profile instead of Headphones on the laptop sound card
        "10-laptop-speaker-profile" = {
          "monitor.alsa.rules" = [{
            matches = [{ "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; }];
            actions.update-props = {
              "api.alsa.use-acp" = true;
              "api.acp.auto-profile" = false;
              "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)";
            };
          }];
        };

        # Headphones (3.5mm jack) preferred over built-in speakers
        "10-laptop-headphones-defaults" = {
          "monitor.alsa.rules" = [{
            matches = [{ "node.name" = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink"; }];
            actions.update-props = {
              "priority.session" = 800;
            };
          }];
        };

        # Lower laptop speaker priority so BT, headphones, and dock are preferred
        "10-laptop-speaker-defaults" = {
          "monitor.alsa.rules" = [{
            matches = [{ "node.name" = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink"; }];
            actions.update-props = {
              "priority.session" = 500;
            };
          }];
        };
      };
    };

    udev.packages = with pkgs; [gnome-settings-daemon];
    udev.extraRules = ''
      # RUTOKEN MFA FIDO2 - grant access to logged-in users
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0a89", ATTRS{idProduct}=="0093", TAG+="uaccess"
      # Ergohaven HPD v2 - Vial keyboard configurator access
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="e126", ATTRS{idProduct}=="0051", TAG+="uaccess", MODE="0660", GROUP="users"
    '';

    # the automatic mount USB disks
    udisks2.enable = true;
  };
}

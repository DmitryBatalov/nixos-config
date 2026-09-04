{username, ...}: {
  imports = [
    ../../modules

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # ============================= What this machine is =============================

  local = {
    certs.russianTrusted.enable = true;
    overlays.unstable.enable = true;

    networking = {
      networkManager.enable = true;
      bambuDiscovery.enable = true;
      extraHosts = ''
        192.168.1.1 keenetic.local
      '';
    };

    # Change the tunnel endpoint here and nowhere else: the user service, the
    # chromium flag, Rider's proxychains config and the nix-daemon env all
    # derive from these.
    proxy = {
      nixDaemon.enable = true;
      remote = {
        # Load-bearing. This is the upstream end of the SOCKS5 tunnel, and it
        # is a separate concern from any host this repo deploys -- nothing here
        # manages this box. Everything that reaches the network through the
        # proxy depends on it: chromium, Rider, and every nix-daemon fetch
        # including cache.nixos.org, so builds stop working without it.
        host = "45.151.68.245";
        user = "dmitry";
        port = 443;
      };
    };

    desktop = {
      enable = true;
      sway.enable = true;
      audio.enable = true;
      fonts.enable = true;
    };

    # Privileged cluster access gated on the hardware token. What gets
    # encrypted is not an admin kubeconfig but that of a narrow minter
    # identity, whose only power is issuing short-lived tokens to the two
    # accounts named below. The cluster-side manifest lives with the cluster.
    k8s.access = {
      enable = true;
    };

    hardware = {
      bluetooth.enable = true;
      fido2.enable = true;
      laptop.enable = true;
      printers.enable = true;
      vialKeyboard.enable = true;
    };

    virtualisation = {
      docker = {
        # Retired, and the docker group went with it -- that was the whole point:
        # membership was root-equivalent with no password. Old images and volumes
        # stay in /var/lib/docker and come back if this is flipped, until that
        # directory is removed by hand.
        enable = false;

        # The only daemon now. Containers run as this user in a user namespace,
        # so "root" inside one is an unprivileged uid outside.
        rootless = true;
      };
      libvirt.enable = true;
    };
  };

  # ============================= Host specifics =============================

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  users.users.${username}.description = username;

  time.timeZone = "Europe/Samara";
  console.keyMap = "ru";

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

  system.stateVersion = "25.11";
}

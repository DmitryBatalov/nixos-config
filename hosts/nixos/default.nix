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
        # The box serving the tunnel. It used to be managed from this repo as
        # the `vega` host; that config is gone, the endpoint is unchanged.
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

    hardware = {
      bluetooth.enable = true;
      fido2.enable = true;
      laptop.enable = true;
      printers.enable = true;
      vialKeyboard.enable = true;
    };

    virtualisation = {
      docker.enable = true;
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

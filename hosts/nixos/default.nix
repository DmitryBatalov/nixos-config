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

    proxy.nixDaemon.enable = true;

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

  # Hard-link identical files in the store to save disk. Worth it here because
  # this machine carries a large store; vega could adopt it with one line.
  nix.settings.auto-optimise-store = true;

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

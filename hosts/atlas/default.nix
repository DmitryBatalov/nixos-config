{
  inputs,
  pkgs,
  username,
  ...
}: {
  imports = [
    ../../modules
    inputs.disko.nixosModules.disko

    ./disk.nix
    # Written by nixos-anywhere --generate-hardware-config on install.
    ./hardware-configuration.nix
  ];

  # ============================= What this machine is =============================

  # A spare laptop as a headless box for containers and long Claude sessions,
  # reached from the workstation over SSH. Deliberately holds no credentials:
  # see local.server in modules/server.nix.

  local = {
    certs.russianTrusted.enable = true;

    networking.networkManager.enable = true;

    # No tunnel of its own -- that would put a key to the tunnel host on a box
    # where agents run unattended. The router already serves the same tunnel
    # to the whole LAN.
    proxy = {
      socksAddress = "192.168.1.142";
      nixDaemon.enable = true;
    };

    server = {
      enable = true;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDaci07bJRxAFOdZIX+INNbEVmXhERlKShpfVoGRPga/"
      ];
      # The workstation's store key (hosts/nixos: nix.settings.secret-key-files).
      trustedSigningKeys = [
        "workstation-1:LXkkvCKzKQeq6Cp7baJJJfA1d+ALK1TO8UrJZwg1DqM="
      ];
    };

    virtualisation.docker.rootless = true;
  };

  # ============================= Host specifics =============================

  environment.systemPackages = [
    pkgs.tmux
    inputs.claude-config.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # The built-in Ethernet is dead (nothing behind its PCIe port), so the box
  # lives on WiFi until a USB adapter arrives -- NetworkManager prefers the
  # cable on its own once there is one. SSID and passphrase are machine
  # details and stay out of this public repository: WIFI_SSID and WIFI_PSK come
  # from a root-only file, delivered on install with --extra-files.
  networking.networkmanager.ensureProfiles = {
    environmentFiles = ["/etc/secrets/wifi.env"];
    profiles.home-wifi = {
      connection = {
        id = "home-wifi";
        type = "wifi";
        autoconnect = true;
      };
      wifi = {
        ssid = "$WIFI_SSID";
        mode = "infrastructure";
      };
      wifi-security = {
        key-mgmt = "wpa-psk";
        psk = "$WIFI_PSK";
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
  };

  # Read by the claude wrapper: route its HTTP->SOCKS5 bridge to the router.
  environment.sessionVariables.CLAUDE_SOCKS_UPSTREAM = "192.168.1.142:1081";

  # Plugged in around the clock: holding a ThinkPad battery at 100% wears it
  # out within a year or two. thinkpad_acpi exposes the thresholds.
  #
  # Not a tmpfiles rule: tmpfiles runs ~2 s before BAT0 appears, and a `w` to a
  # missing path is skipped without a word -- the first boot came up at 80/75.
  # The end is widened to 100 first, so neither write can be refused as a start
  # at or above the end, whatever the controller held before.
  systemd.services.battery-charge-thresholds = {
    description = "Hold the battery between 75% and 80%";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      b=/sys/class/power_supply/BAT0
      for _ in $(seq 30); do
        [ -e "$b/charge_control_end_threshold" ] && break
        sleep 1
      done
      echo 100 > "$b/charge_control_end_threshold"
      echo 75 > "$b/charge_control_start_threshold"
      echo 80 > "$b/charge_control_end_threshold"
    '';
  };

  # Firmware updates from LVFS (`fwupdmgr get-updates`). The BIOS shipped at
  # 1.09 (2020-01), with years of security fixes missing.
  services.fwupd.enable = true;

  # 15 GiB of RAM and no swap partition: compressed swap in memory absorbs the
  # peaks of a few containers plus several agent sessions.
  zramSwap.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "atlas";

  users.users.${username}.description = username;

  time.timeZone = "Europe/Samara";
  i18n.defaultLocale = "en_US.UTF-8";

  system.stateVersion = "26.05";
}

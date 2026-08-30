{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.local.networking;
in {
  options.local.networking = {
    networkManager.enable =
      lib.mkEnableOption "NetworkManager, plus the WiFi/ethernet arbitration below";

    bambuDiscovery.enable =
      lib.mkEnableOption "inbound UDP for Bambu Lab printer discovery";

    extraHosts = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra entries for /etc/hosts.";
    };
  };

  config = lib.mkMerge [
    {
      networking.extraHosts = cfg.extraHosts;
    }

    (lib.mkIf cfg.networkManager.enable {
      networking.networkmanager.enable = true;

      # The feature carries its own access: enabling NetworkManager is what
      # earns the user the networkmanager group, rather than core.nix having to
      # know that this host happens to use it.
      users.users.${username}.extraGroups = ["networkmanager"];

      networking.networkmanager.dispatcherScripts = [
        {
          # Disable WiFi when ethernet is connected with working gateway, re-enable when disconnected
          source = pkgs.writeShellScript "wifi-toggle" ''
            IFACE="$1"
            ACTION="$2"
            NMCLI="${pkgs.networkmanager}/bin/nmcli"
            DEVICE_TYPE="$($NMCLI -t -f GENERAL.TYPE dev show "$IFACE" 2>/dev/null | head -1)"

            if [ "$DEVICE_TYPE" != "GENERAL.TYPE:ethernet" ]; then
              exit 0
            fi

            if [ "$ACTION" = "up" ]; then
              GATEWAY="$($NMCLI -t -f IP4.GATEWAY dev show "$IFACE" 2>/dev/null | head -1 | cut -d: -f2)"
              if [ -n "$GATEWAY" ]; then
                $NMCLI radio wifi off
              fi
            elif [ "$ACTION" = "down" ]; then
              $NMCLI radio wifi on
            fi
          '';
          type = "basic";
        }
      ];
    })

    (lib.mkIf cfg.bambuDiscovery.enable {
      networking.firewall.allowedUDPPorts = [
        1900 # SSDP (printer discovery)
        2021 # Bambu Lab printer discovery
      ];
    })
  ];
}

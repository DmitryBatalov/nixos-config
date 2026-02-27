{
  pkgs,
  lib,
  username,
  ...
}:
{
  networking = {
    extraHosts = ''
      192.168.1.1 keenetic.local
    '';

    # Allow Bambu Lab printer discovery (SSDP) and communication
    firewall.allowedUDPPorts = [
      1900 # SSDP (printer discovery)
      2021 # Bambu Lab printer discovery
    ];

    networkmanager.dispatcherScripts = [
      {
        # Disable WiFi when ethernet is connected with working gateway, re-enable when disconnected
        source = pkgs.writeText "wifi-toggle" ''
          #!/usr/bin/env sh
          IFACE="$1"
          ACTION="$2"
          NMCLI="${pkgs.networkmanager}/bin/nmcli"
          DEVICE_TYPE="$($NMCLI -t -f GENERAL.TYPE dev show "$IFACE" 2>/dev/null | head -1)"

          if [ "$DEVICE_TYPE" != "GENERAL.TYPE:ethernet" ]; then
            exit 0
          fi

          if [ "$ACTION" = "up" ]; then
            GATEWAY="$($NMCLI -t -f IP4.GATEWAY dev show "$IFACE" 2>/dev/null | head -1 | cut -d: -f2)"
            if [ -n "$GATEWAY" ] && ${pkgs.iputils}/bin/ping -c 1 -W 2 -I "$IFACE" "$GATEWAY" > /dev/null 2>&1; then
              $NMCLI radio wifi off
            fi
          elif [ "$ACTION" = "down" ]; then
            $NMCLI radio wifi on
          fi
        '';
        type = "basic";
      }
    ];
  };
}

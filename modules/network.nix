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
  };
}

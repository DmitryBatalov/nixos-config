{
  pkgs,
  lib,
  username,
  ...
}: {
  networking = {
    extraHosts = ''
      192.168.1.1 keenetic.local
    '';
  };
}

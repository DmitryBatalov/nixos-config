{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.local.virtualisation.docker;
in {
  options.local.virtualisation.docker.enable =
    lib.mkEnableOption "Docker, with an address pool that avoids the LAN";

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      # setup address pool
      daemon.settings = {
        default-address-pools = [
          {
            base = "10.10.0.0/16";
            size = 24;
          }
        ];
      };
    };

    users.users.${username}.extraGroups = ["docker"];

    environment.systemPackages = with pkgs; [
      docker-compose
    ];
  };
}

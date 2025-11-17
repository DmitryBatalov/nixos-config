{
  pkgs,
  username,
  ...
}: {
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
}

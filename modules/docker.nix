{
  pkgs,
  username,
  ...
}: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  users.users.${username}.extraGroups = ["docker"];

  environment.systemPackages = with pkgs; [
    docker-compose
  ];
}

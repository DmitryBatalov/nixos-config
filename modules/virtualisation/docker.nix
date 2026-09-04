{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.local.virtualisation.docker;
in {
  options.local.virtualisation.docker = {
    enable = lib.mkEnableOption ''
      the rootful Docker daemon, with an address pool that avoids the LAN.

      This also puts the user in the `docker` group, and that group is
      root-equivalent with no password: the daemon runs as root, and anyone who
      can reach its socket can ask for a container that bind-mounts the host
      filesystem. Documented Docker behaviour, not a flaw -- but it means file
      permissions on this machine cannot keep anything from a process running
      as the user. Turning this off is the point of the `rootless` option
    '';

    rootless = lib.mkEnableOption ''
      a rootless daemon, which can run alongside the rootful one.

      It runs as the user in a user namespace, so "root" inside a container
      maps to an unprivileged uid outside and no group is needed. Storage and
      socket are its own, so both daemons can coexist while projects move over
      a few at a time -- DOCKER_HOST decides which one a shell talks to.

      Enabling this alone changes nothing about the exposure: it only provides
      somewhere to move to. The gain arrives when `enable` goes off, taking the
      group with it
    '';
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable || cfg.rootless) {
      environment.systemPackages = with pkgs; [docker-compose];
    })

    (lib.mkIf cfg.enable {
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

      # Tied to the rootful daemon deliberately: the group is the exposure, and
      # it should disappear at the same moment the thing needing it does.
      users.users.${username}.extraGroups = ["docker"];
    })

    (lib.mkIf cfg.rootless {
      virtualisation.docker.rootless = {
        enable = true;
        # Once the rootful daemon is gone there is nothing left to be ambiguous
        # about, so point every shell at the rootless socket. While both exist
        # this stays off: setting it globally would also move tools that open
        # the socket directly rather than going through the CLI.
        setSocketVariable = !cfg.enable;
      };

      # kind needs the cpuset controller delegated to the user slice to run
      # under a rootless daemon; systemd's default is "pids memory cpu".
      # Harmless for everything else.
      systemd.services."user@".serviceConfig.Delegate = "pids memory cpu cpuset io";
    })
  ];
}

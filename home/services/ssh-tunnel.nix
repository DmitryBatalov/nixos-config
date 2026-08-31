{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  proxy = osConfig.local.proxy;
in {
  # These used to live in home/sway/, which had nothing to do with them beyond
  # both being things the graphical session starts.

  systemd.user.services.ssh-add-keys = {
    Unit = {
      Description = "Unlock SSH keys via askpass";
      After = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "SSH_AUTH_SOCK=%t/ssh-agent"
        "SSH_ASKPASS=${pkgs.lxqt.lxqt-openssh-askpass}/bin/lxqt-openssh-askpass"
        "SSH_ASKPASS_REQUIRE=prefer"
      ];
      ExecStart = "${pkgs.openssh}/bin/ssh-add %h/.ssh/id_ed25519";
    };
    Install.WantedBy = ["graphical-session.target"];
  };

  systemd.user.services.ssh-tunnel = {
    Unit = {
      Description = "SSH SOCKS5 proxy tunnel";
      After = ["ssh-add-keys.service"];
      Requires = ["ssh-add-keys.service"];
    };
    Service = {
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent";
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.openssh}/bin/ssh"
        "-D ${toString proxy.socksPort}"
        "-N"
        "-C"
        "-p ${toString proxy.remote.port}"
        "-o ServerAliveInterval=30"
        "-o ServerAliveCountMax=3"
        "-o ExitOnForwardFailure=yes"
        "${proxy.remote.user}@${proxy.remote.host}"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}

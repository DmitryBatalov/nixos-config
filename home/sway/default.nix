{
  pkgs,
  config,
  ...
}: {
  systemd.user.services.ssh-add-keys = {
    Unit = {
      Description = "Unlock SSH keys via askpass";
      After = [ "graphical-session.target" ];
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
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.ssh-tunnel = {
    Unit = {
      Description = "SSH SOCKS5 proxy tunnel";
      After = [ "ssh-add-keys.service" ];
      Requires = [ "ssh-add-keys.service" ];
    };
    Service = {
      Environment = "SSH_AUTH_SOCK=%t/ssh-agent";
      ExecStart = "${pkgs.openssh}/bin/ssh -D 1081 -N -C -p 443 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes dmitry@45.151.68.245";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };

  home.file = {
    ".config/sway/wallpaper.png".source = "${pkgs.nixos-artwork.wallpapers.simple-dark-gray-bottom.src}";
    ".config/sway/config".source = ./config;
    ".config/sway/scripts/lock" = { source = ./scripts/lock; executable = true; };
    ".config/sway/scripts/empty_workspace" = { source = ./scripts/empty_workspace; executable = true; };
    ".config/sway/scripts/keyhint-2" = { source = ./scripts/keyhint-2; executable = true; };
    ".config/sway/scripts/power-profiles" = { source = ./scripts/power-profiles; executable = true; };
    ".config/sway/scripts/powermenu" = { source = ./scripts/powermenu; executable = true; };
    ".config/sway/scripts/register-fido2" = { source = ./scripts/register-fido2; executable = true; };
    ".config/sway/scripts/ssh-tunnel-toggle" = { source = ./scripts/ssh-tunnel-toggle; executable = true; };
    ".config/sway/scripts/ssh-tunnel-waybar" = { source = ./scripts/ssh-tunnel-waybar; executable = true; };
    ".config/waybar/config.jsonc".source = ./waybar/config.jsonc;
    ".config/waybar/style.css".source = ./waybar/style.css;
  };
}

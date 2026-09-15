{
  # Everything is a plain import: unlike modules/, there is one user on one
  # machine here, so enable flags would be ceremony with nothing to switch.
  imports = [
    ../../home/core.nix
    ../../home/packages.nix

    ../../home/desktop
    ../../home/kube
    ../../home/rofi
    ../../home/sway
    ../../home/tmux

    ../../home/programs/browsers.nix
    ../../home/programs/git.nix
    ../../home/programs/kitty.nix
    ../../home/programs/rider.nix
    ../../home/programs/shell.nix
    ../../home/programs/ssh.nix

    ../../home/services/backup-notify.nix
    ../../home/services/ssh-tunnel.nix
  ];
}

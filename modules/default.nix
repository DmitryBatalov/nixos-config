{
  # Importing this brings every feature module into scope. Nothing here turns
  # itself on except core.nix -- hosts opt in through the `local.*` options, so
  # hosts/<name>/default.nix reads as a list of what the machine is.
  imports = [
    ./core.nix

    ./certs.nix
    ./networking.nix
    ./overlays.nix
    ./proxy.nix

    ./desktop
    ./desktop/audio.nix
    ./desktop/fonts.nix
    ./desktop/sway.nix

    ./k8s/access.nix

    ./hardware/bluetooth.nix
    ./hardware/fido2.nix
    ./hardware/keyboard.nix
    ./hardware/laptop.nix
    ./hardware/printers.nix

    ./virtualisation/docker.nix
    ./virtualisation/libvirt.nix
  ];
}

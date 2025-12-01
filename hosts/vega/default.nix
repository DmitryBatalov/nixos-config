# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/system.nix
    ../../modules/i3.nix
    ../../modules/docker.nix

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  fileSystems."/mnt/shared" = {
    device = "shared";
    fsType = "virtiofs";
    options = ["defaults"];
  };

  # Use the GRUB 2 boot loader.
  boot = {
    loader = {
      grub = {
        enable = true;
        device = "/dev/vda";
        # efiSupport = true;
        # efiInstallAsRemovable = true;
      };
    };
  };

  # Define on which hard drive you want to install Grub.
  boot.initrd.kernelModules = ["virtiofs"];

  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  networking.hostName = "nixos"; # Define your hostname.

  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  system.stateVersion = "25.11";
}

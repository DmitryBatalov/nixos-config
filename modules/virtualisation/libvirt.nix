{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.local.virtualisation.libvirt;
in {
  options.local.virtualisation.libvirt.enable =
    lib.mkEnableOption "libvirtd and virt-manager for QEMU/KVM guests";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;

    # if you use libvirtd on a desktop environment
    programs.virt-manager.enable = true; # can be used to manage non-local hosts as well

    users.users.${username}.extraGroups = ["libvirtd" "kvm" "plugdev"];

    environment.systemPackages = with pkgs; [
      spice-gtk
    ];
  };
}

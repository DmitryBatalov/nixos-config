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

    # No libvirtd: membership in that group is root-equivalent with no password --
    # polkit grants org.libvirt.unix.manage to it with Result.YES, and a domain
    # definition can attach any host block device. Domains live in qemu:///session
    # instead, where they run as the user and need no privileged daemon.
    # kvm is only /dev/kvm for hardware acceleration; plugdev is USB. Neither
    # grants anything the user could not already reach.
    users.users.${username}.extraGroups = ["kvm" "plugdev"];

    # A qemu:///session domain runs as the user, so USB passthrough needs the
    # user to own the device node -- libvirtd is not there to open it as root.
    # This is the smart card passed into the Debian guest. The FIDO2 token used
    # for login has its own rule in hardware/fido2.nix and matches hidraw, not
    # usb, so the two do not overlap.
    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0a89", ATTRS{idProduct}=="0025", TAG+="uaccess"
    '';

    environment.systemPackages = with pkgs; [
      # passt backs user-mode networking for qemu:///session domains: it does
      # port forwarding declaratively in the domain XML and handles IPv6,
      # where the QEMU built-in slirp does neither well.
      passt
      spice-gtk
    ];
  };
}

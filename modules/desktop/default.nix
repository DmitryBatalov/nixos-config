{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.desktop;
in {
  options.local.desktop.enable =
    lib.mkEnableOption "the pieces every graphical session here wants, independent of compositor";

  config = lib.mkIf cfg.enable {
    programs = {
      dconf.enable = true;
      gnupg.agent.enable = true;
    };

    services = {
      # Auto-mount USB disks.
      udisks2.enable = true;
      udev.packages = with pkgs; [gnome-settings-daemon];
    };

    environment.systemPackages = with pkgs; [
      # Workstation conveniences -- deliberately not on servers.
      jq
      tree
      fastfetch

      nautilus
      pavucontrol
      calc
    ];
  };
}

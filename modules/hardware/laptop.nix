{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.hardware.laptop;
in {
  options.local.hardware.laptop = {
    enable =
      lib.mkEnableOption "lid handling, display auto-detection and power profiles";

    conservationToggle.enable = lib.mkEnableOption ''
      letting the `users` group switch IdeaPad/ThinkBook conservation mode
      (firmware stops charging at ~60%), so the waybar module can toggle it
      without sudo. The worst a process can do with it is change the charge cap
    '';
  };

  config = lib.mkIf cfg.enable {
    # The attribute exists once ideapad_acpi binds; coldplug replays `add`
    # with the driver already set, a late module load sends `bind`.
    services.udev.extraRules = lib.mkIf cfg.conservationToggle.enable ''
      ACTION=="add|bind", SUBSYSTEM=="platform", DRIVER=="ideapad_acpi", RUN+="${pkgs.coreutils}/bin/chgrp users /sys%p/conservation_mode", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/conservation_mode"
    '';

    environment.systemPackages = with pkgs; [
      lm_sensors # for `sensors` command
    ];

    services = {
      # Auto-detect connected displays and apply saved xrandr profiles
      autorandr.enable = true;

      power-profiles-daemon.enable = true;

      logind = {
        settings = {
          Login = {
            HandleLidSwitchDocked = "ignore"; # External monitor connected → stay on
            HandleLidSwitchExternalPower = "ignore"; # Power → stay on (logind doesn't detect dock via DP hub)
            HandleLidSwitch = "hibernate"; # No power → hibernate
          };
        };
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.hardware.laptop;
in {
  options.local.hardware.laptop.enable =
    lib.mkEnableOption "lid handling, display auto-detection and power profiles";

  config = lib.mkIf cfg.enable {
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

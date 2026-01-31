{pkgs, ...}: {
  services = {
    # Auto-detect connected displays and apply saved xrandr profiles
    autorandr.enable = true;

    logind = {
      settings = {
        Login = {
          HandleLidSwitchDocked = "ignore";          # External monitor connected → stay on
          HandleLidSwitchExternalPower = "ignore";   # Power → stay on (logind doesn't detect dock via DP hub)
          HandleLidSwitch = "hibernate";             # No power → hibernate
        };
      };
    };
  };
}

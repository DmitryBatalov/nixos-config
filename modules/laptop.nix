{pkgs, ...}: {
  # One of "ignore", "poweroff", "reboot", "halt", "kexec", "suspend", "hibernate", "hybrid-sleep",
  # "suspend-then-hibernate", "lock"

  # These three options can be used to configure how a laptop should behave when the lid is closed.

  # In this example, it normally shuts down.
  # If power is connected, only the screen is locked.
  # If another screen is connected instead, nothing happens.

  # services = {
  #   logind = {
  #     settings = {
  #       Login = {
  #         HandleLidSwitchDocked = "ignore";
  #         HandleLidSwitchExternalPower = "lock";
  #         HandleLidSwitch = "poweroff";
  #       };
  #     };
  #   };

  services = {
    logind = {
      settings = {
        Login = {
          HandleLidSwitchDocked = "ignore";
          HandleLidSwitchExternalPower = "lock";
          HandleLidSwitch = "poweroff";
        };
      };
    };
  };
}

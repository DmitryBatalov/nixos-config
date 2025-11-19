{pkgs, ...}: {
  # One of "ignore", "poweroff", "reboot", "halt", "kexec", "suspend", "hibernate", "hybrid-sleep",
  # "suspend-then-hibernate", "lock"

  # These three options can be used to configure how a laptop should behave when the lid is closed.

  # In this example, it normally shuts down.
  # If power is connected, only the screen is locked.
  # If another screen is connected instead, nothing happens.

  # services = {
  #   logind = {
  #     lidSwitch = "poweroff";
  #     lidSwitchExternalPower = "lock";
  #     lidSwitchDocked = "ignore";
  #   };
  # };

  services = {
    logind = {
      lidSwitch = "poweroff";
      lidSwitchExternalPower = "lock";
      lidSwitchDocked = "ignore";
    };
  };
}

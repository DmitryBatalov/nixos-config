{
  config,
  lib,
  ...
}: let
  cfg = config.local.hardware.vialKeyboard;
in {
  options.local.hardware.vialKeyboard.enable =
    lib.mkEnableOption "hidraw access for the Ergohaven HPD v2, so Vial can talk to it";

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = ''
      # Ergohaven HPD v2 - Vial keyboard configurator access
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="e126", ATTRS{idProduct}=="0051", TAG+="uaccess", MODE="0660", GROUP="users"
    '';
  };
}

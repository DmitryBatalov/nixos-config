{
  config,
  lib,
  ...
}: let
  cfg = config.local.hardware.bluetooth;
in {
  options.local.hardware.bluetooth.enable =
    lib.mkEnableOption "Bluetooth and the Blueman applet";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}

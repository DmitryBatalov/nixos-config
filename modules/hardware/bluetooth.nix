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

    # btusb suspends the controller after two idle seconds, and SCO does not
    # survive it: the kernel forgets the link while the controller keeps sending
    # packets for it ("SCO packet for unknown connection handle" in dmesg), so a
    # headset microphone dies mid-call and takes the A2DP stream with it when
    # the profile switches back. SCO carries every headset microphone, so this
    # is not specific to one pair of headphones.
    #
    # The cost is a controller that never sleeps, which on a laptop is a little
    # idle power. Remove this line to go back to the kernel default.
    boot.extraModprobeConfig = "options btusb enable_autosuspend=0";
  };
}

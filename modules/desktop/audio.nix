{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.desktop.audio;
in {
  options.local.desktop.audio.enable =
    lib.mkEnableOption "PipeWire, plus the WirePlumber routing rules for this laptop";

  config = lib.mkIf cfg.enable {
    security.rtkit.enable = true;

    environment.systemPackages = with pkgs; [
      sox # audio recording (used by Claude Code /voice)
    ];

    services = {
      pulseaudio.enable = false;

      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;

        # No quantum override here. There used to be one asking for 32 frames,
        # and it never took effect: written as nested Nix attributes it became
        # nested JSON, while PipeWire wants the flat key "default.clock.quantum".
        # The graph ran at the upstream default of 1024 the whole time. Quoting
        # the keys would have "fixed" it into a graph that wakes up every 0.67 ms
        # -- which is the opposite of what Bluetooth headsets need, and nothing
        # here asks for low latency.

        wireplumber.extraConfig = {
          # Boost Bluetooth sink priority so it's always preferred
          "10-bluetooth-priority" = {
            "monitor.bluez.rules" = [
              {
                matches = [{"node.name" = "~bluez_output.*";}];
                actions.update-props = {
                  "priority.session" = 2000;
                  "priority.driver" = 2000;
                };
              }
            ];
          };

          # Force Speaker profile instead of Headphones on the laptop sound card
          "10-laptop-speaker-profile" = {
            "monitor.alsa.rules" = [
              {
                matches = [{"device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic";}];
                actions.update-props = {
                  "api.alsa.use-acp" = true;
                  "api.acp.auto-profile" = false;
                  "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)";
                };
              }
            ];
          };

          # Headphones (3.5mm jack) preferred over built-in speakers
          "10-laptop-headphones-defaults" = {
            "monitor.alsa.rules" = [
              {
                matches = [{"node.name" = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink";}];
                actions.update-props = {
                  "priority.session" = 800;
                };
              }
            ];
          };

          # Lower laptop speaker priority so BT, headphones, and dock are preferred
          "10-laptop-speaker-defaults" = {
            "monitor.alsa.rules" = [
              {
                matches = [{"node.name" = "~alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Speaker__sink";}];
                actions.update-props = {
                  "priority.session" = 500;
                };
              }
            ];
          };
        };
      };
    };
  };
}

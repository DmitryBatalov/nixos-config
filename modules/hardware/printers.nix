{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.local.hardware.printers;
in {
  options.local.hardware.printers.enable =
    lib.mkEnableOption "CUPS and SANE for the Brother DCP-7057WR on the LAN";

  config = lib.mkIf cfg.enable {
    users.users.${username}.extraGroups = ["lp" "scanner"];

    services.printing = {
      enable = true;
      drivers = [pkgs.brlaser];
      webInterface = true;
    };

    hardware = {
      sane = {
        # Enable SANE for scanning
        enable = true;

        # Add Brother printer drivers
        brscan4 = {
          enable = true;
          netDevices = {
            home = {
              model = "Brother_DCP7057WR";
              ip = "192.168.1.57";
            };
          };
        };
      };

      printers = {
        ensureDefaultPrinter = "Brother_DCP7057WR";
        ensurePrinters = [
          {
            deviceUri = "lpd://192.168.1.57/queue";
            location = "Home";
            name = "Brother_DCP7057WR";
            model = "drv:///brlaser.drv/br7055w.ppd";
            # Or use generic if specific PPD not available:
            ppdOptions = {
              PageSize = "A4";
              Duplex = "None";
              Resolution = "600x600dpi";
            };
          }
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      # GUI tools for printer management
      system-config-printer
      simple-scan
    ];
  };
}

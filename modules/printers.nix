{
  pkgs,
  lib,
  username,
  ...
}: {
  # ============================= User related =============================

  # Add user to groups
  users.users.${username} = {
    extraGroups = ["lp" "scanner"];
  };

  # Enable CUPS to print documents.
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

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    # GUI tools for printer management
    system-config-printer
    simple-scan
  ];
}

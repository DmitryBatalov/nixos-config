{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.hardware.fido2;
in {
  options.local.hardware.fido2.enable =
    lib.mkEnableOption "FIDO2 authentication (PIN + touch) as an alternative to the password";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pam_u2f # FIDO2 PAM module + pamu2fcfg registration tool
      libfido2 # FIDO2 library and fido2-token utility
    ];

    security.pam = {
      u2f = {
        enable = true;
        control = "sufficient";
        settings = {
          cue = true;
          timeout = 10;
        };
      };

      services = {
        login.u2fAuth = true;
        sudo.u2fAuth = true;
        xsecurelock.u2fAuth = true;
        swaylock.u2fAuth = true;
      };
    };

    services.udev.extraRules = ''
      # RUTOKEN MFA FIDO2 - grant access to logged-in users
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0a89", ATTRS{idProduct}=="0093", TAG+="uaccess"
    '';
  };
}

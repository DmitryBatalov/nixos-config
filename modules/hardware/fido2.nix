{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.hardware.fido2;
in {
  options.local.hardware.fido2 = {
    enable =
      lib.mkEnableOption "FIDO2 authentication (PIN + touch) as an alternative to the password";

    authFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/u2f/mappings";
      description = ''
        pam_u2f authfile: the credentials allowed to authenticate, one line per
        user.

        Deliberately outside $HOME, so a process running as the user cannot
        append a credential of its own to the list of accepted ones, and
        outside this repository, because it is per-machine hardware
        registration state -- the same class of thing as a host SSH key. Only
        the path here is declarative; the contents are local to the machine.

        Populate it once, as your normal user -- not from a root shell, where
        `~` resolves to /root:

          sudo install -d -m 0755 -o root -g root /var/lib/u2f
          sudo install -m 0444 -o root -g root \
            ~/.config/Yubico/u2f_keys /var/lib/u2f/mappings

        If the file is missing, pam_u2f fails and `control = "sufficient"` falls
        through to the password with nothing logged, so FIDO2 reads as enabled
        while doing nothing. Nix cannot assert the file exists -- it is runtime
        state -- so check after a rebuild that the argument actually landed:

          grep -o 'authfile=[^ ]*' /etc/pam.d/sudo
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pam_u2f # FIDO2 PAM module + pamu2fcfg registration tool
      libfido2 # FIDO2 library and fido2-token utility
    ];

    systemd.tmpfiles.rules = [
      "d ${dirOf cfg.authFile} 0755 root root -"
      "z ${cfg.authFile} 0444 root root -" # re-assert the mode if the file exists
    ];

    security.pam = {
      u2f = {
        enable = true;
        control = "sufficient"; # keeps the password as a fallback -- do not tighten
        settings = {
          # Lowercase: this is a pam_u2f argument name, not a NixOS option name.
          # `settings` is freeform, so `authFile` would be accepted silently and
          # handed to pam_u2f as an unknown argument, leaving it reading
          # ~/.config/Yubico/u2f_keys as if nothing had changed.
          authfile = cfg.authFile;
          cue = true;
          timeout = 10;
        };
      };

      services = {
        # These do not switch u2f on. security.pam.u2f.enable above already
        # defaults it on for *every* PAM service -- su, polkit-1 and passwd
        # included. swaylock is named because nothing else in this config
        # defines that service and it needs one to authenticate at all; login
        # and sudo are named to say out loud where this is meant to be used.
        login.u2fAuth = true;
        sudo.u2fAuth = true;
        swaylock.u2fAuth = true;

        # The one place the token is deliberately not accepted. greetd would
        # otherwise inherit it from that global default, and the boot prompt is
        # the worst place to find out how a 10s touch cue renders in a text
        # greeter. Graphical login stays password-only.
        greetd.u2f.enable = false;
      };
    };

    services.udev.extraRules = ''
      # RUTOKEN MFA FIDO2 - grant access to logged-in users
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0a89", ATTRS{idProduct}=="0093", TAG+="uaccess"
    '';
  };
}

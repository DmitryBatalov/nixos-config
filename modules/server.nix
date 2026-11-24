{
  config,
  lib,
  username,
  ...
}: let
  cfg = config.local.server;
in {
  options.local.server = {
    enable = lib.mkEnableOption ''
      running this machine as an always-on, headless box reached over SSH.

      It is meant for unattended work (containers, long agent sessions), so it
      holds no credentials worth stealing: no hardware token, no cluster or
      cloud access, no backup keys. sudo keeps asking for the password, and the
      user is not a trusted nix user -- either would make every process running
      as the user root, which is exactly what an unattended agent must not be
    '';

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys allowed to log in as the user.";
    };

    hashedPasswordFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/secrets/${username}.hash";
      description = ''
        The user's password hash (mkpasswd -m yescrypt), which sudo asks for.

        Root-owned and outside this repository, which is public. Delivered on
        install with nixos-anywhere --extra-files; never put the hash here.
      '';
    };

    trustedSigningKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Public keys whose signatures this store accepts, on top of
        cache.nixos.org.

        This is how a deploy lands without the user being a trusted nix user:
        the machine that builds the closure signs it, and the store here
        imports signed paths from anyone.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [username];
      };
    };

    users.users.${username} = {
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
      inherit (cfg) hashedPasswordFile;
      # Keeps the user's systemd instance -- the rootless docker daemon, tmux
      # sessions -- alive with nobody logged in.
      linger = true;
    };

    # extra-: assigning trusted-public-keys itself would replace the default
    # list and drop the cache.nixos.org key along with it.
    nix.settings.extra-trusted-public-keys = cfg.trustedSigningKeys;

    # A laptop running as a server: the lid stays shut and nothing may suspend
    # it, whatever the power source.
    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
      IdleAction = "ignore";
    };

    systemd.targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.gcp.access;

  # Everything the wrapper itself shells out to, enumerated rather than borrowed
  # from the system profile, as for k8s: it runs as root.
  wrapperTools = with pkgs; [
    age
    age-plugin-fido2-hmac
    jq
    curl
    openssl
    coreutils
    gnugrep
    diffutils # cmp, for the install round trip
  ];

  # gcloud alone. The token it runs with is the admin's, so nothing else is on
  # its PATH.
  runTools = [pkgs.google-cloud-sdk];

  settings = {
    # /run/wrappers/bin for the setuid sudo that drops to the user; the
    # package's own binary refuses to run without the setuid bit.
    GCP_TOOL_PATH = lib.makeBinPath wrapperTools + ":/run/wrappers/bin";
    GCP_RUN_PATH = lib.makeBinPath runTools;
    GCP_AGE_IDENTITY = cfg.identityFile;
    GCP_DIR = cfg.dir;
  };

  wrapper = pkgs.writeShellApplication {
    name = "gcp";
    runtimeInputs = wrapperTools ++ runTools;
    text =
      lib.concatLines (lib.mapAttrsToList lib.strings.toShellVar settings)
      + builtins.readFile ../google-token.sh
      + builtins.readFile ./gcp.sh;
  };
in {
  options.local.gcp.access = {
    enable = lib.mkEnableOption ''
      `sudo gcp`: gcloud as an administrator service account whose key is
      age-encrypted to the hardware token, so administering Google Cloud costs
      the token's PIN and a touch per command. The everyday Google account can
      then keep read-only roles, and its token and browser session stop being
      worth stealing.
    '';

    identityFile = lib.mkOption {
      type = lib.types.str;
      default = config.local.k8s.access.identityFile;
      defaultText = lib.literalExpression "config.local.k8s.access.identityFile";
      description = ''
        The age identity on the hardware token. Shared with k8s by default:
        one credential on the token, one PIN.
      '';
    };

    dir = lib.mkOption {
      type = lib.types.str;
      default = "/etc/gcp";
      description = ''
        Root-only. Holds what `sudo gcp install <key.json>` writes:

          admin.gsa.age   the admin service account's JSON key, encrypted
          settings        `project = ID`, the default project

        Neither the account nor the project is declared here: the project names
        a customer, and this repository is public.

        Treat admin.gsa.age as what it is: an owner credential that happens to
        be locked. It does not expire unless the organisation sets a policy;
        revoke it by deleting the key in GCP.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [wrapper];

    systemd.tmpfiles.rules = [
      "d ${cfg.dir} 0700 root root -"
      "z ${cfg.dir}/admin.gsa.age 0400 root root -"
      "z ${cfg.dir}/settings 0400 root root -"
    ];

    # As for k8s: secure_path (set by the k8s module) keeps sudo from resolving
    # `gcp` through the caller's PATH, and no cached ticket lets an unattended
    # process call it with only the touch left to wait for.
    security.sudo.extraConfig = ''
      Cmnd_Alias GCP_ACCESS = /run/current-system/sw/bin/gcp, /nix/store/*/bin/gcp
      Defaults!GCP_ACCESS timestamp_timeout=0
    '';
  };
}

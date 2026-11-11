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
    findutils # xargs, for the terminal check
    diffutils # cmp, for the install round trip
    util-linux # setpriv, to drop to runUser
  ];

  # gcloud, and the coreutils its launcher script calls (dirname, realpath);
  # bash and jq for the policy rewrite of a timed grant. The token it runs
  # with is the admin's, so nothing else is on its PATH.
  runTools = with pkgs; [google-cloud-sdk coreutils bash jq];

  # shell is a person at a prompt: a multiplexer, a pager, the usual text
  # tools, clear and reset. Still nothing of the system profile, and no
  # kubectl -- owner on the project is admin on its clusters, around
  # sudo k8s --breakglass.
  # bashInteractive first: plain bash has no readline, so no history or arrows.
  shellTools = [pkgs.bashInteractive] ++ runTools ++ (with pkgs; [tmux less gnugrep gnused findutils diffutils ncurses]);

  settings = {
    # /run/wrappers/bin for the setuid sudo that drops to the user; the
    # package's own binary refuses to run without the setuid bit.
    GCP_TOOL_PATH = lib.makeBinPath wrapperTools + ":/run/wrappers/bin";
    GCP_RUN_PATH = lib.makeBinPath runTools;
    GCP_AGE_IDENTITY = cfg.identityFile;
    GCP_DIR = cfg.dir;
    GCP_RUN_USER = cfg.runUser;
    GCP_GRANT_JQ = "${./grant.jq}";
    GCP_SHELL_PATH = lib.makeBinPath shellTools;
    # tmux runs commands through the account's login shell, and runUser has none.
    GCP_SHELL_BASH = "${pkgs.bashInteractive}/bin/bash";
    GCP_GCLOUD_COMPLETION = "${pkgs.google-cloud-sdk}/share/bash-completion/completions/gcloud";
    GCP_TERMINALS = lib.concatStringsSep " " config.local.k8s.access.terminals;
  };

  wrapper = pkgs.writeShellApplication {
    name = "gcp";
    runtimeInputs = wrapperTools ++ shellTools;
    text =
      lib.concatLines (lib.mapAttrsToList lib.strings.toShellVar settings)
      + builtins.readFile ../google-token.sh
      + builtins.readFile ../terminal-holder.sh
      + builtins.readFile ./gcp.sh;
  };

  # `gcp <Tab>`, and `sudo gcp <Tab>` through bash-completion's sudo handling.
  completion = pkgs.runCommand "gcp-completion" {} ''
    install -Dm644 ${pkgs.replaceVars ./completion.bash {gcloud = pkgs.google-cloud-sdk;}} \
      $out/share/bash-completion/completions/gcp
  '';

  package = pkgs.symlinkJoin {
    name = "gcp";
    paths = [wrapper completion];
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

    runUser = lib.mkOption {
      type = lib.types.str;
      default = "gcp-run";
      description = ''
        System account gcloud runs as. Not root: nothing gcloud does needs it,
        only the token is privileged, and as root every path on its command
        line -- an output file, --flags-file, a directory to upload -- would be
        opened with root's rights in a directory the user controls.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # secure_path lives in the k8s module. Without it sudo resolves `gcp`
    # through the caller's PATH, and a planted one collects the touch.
    assertions = [
      {
        assertion = config.local.k8s.access.enable;
        message = "local.gcp.access needs local.k8s.access, which sets sudo's secure_path";
      }
    ];

    environment.systemPackages = [package];

    users.groups.${cfg.runUser} = {};
    users.users.${cfg.runUser} = {
      isSystemUser = true;
      group = cfg.runUser;
      description = "Runs gcloud for sudo gcp";
      home = "/var/empty";
      createHome = false;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dir} 0700 root root -"
      "z ${cfg.dir}/admin.gsa.age 0400 root root -"
      "z ${cfg.dir}/settings 0400 root root -"
      # A SIGKILL skips the trap and would leave a token -- or, mid-install, the
      # plaintext key -- in /run until reboot.
      "e /run/gcp.* - - - 1h"
    ];

    # As for k8s: no cached ticket lets an unattended process call it with only
    # the touch left to wait for.
    security.sudo.extraConfig = ''
      Cmnd_Alias GCP_ACCESS = /run/current-system/sw/bin/gcp, /nix/store/*/bin/gcp
      Defaults!GCP_ACCESS timestamp_timeout=0
    '';
  };
}

{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.local.k8s.access;

  # Names in allowedTools and shellTools are resolved here. An unknown name fails
  # at evaluation rather than at 2am with a token in hand.
  toolPackages = {
    kubectl = pkgs.kubectl;
    helm = pkgs.kubernetes-helm;
    kustomize = pkgs.kustomize;
    k9s = pkgs.k9s;
  };

  resolve = option:
    map (
      t:
        toolPackages.${t}
          or (throw "local.k8s.access.${option}: no package is mapped for \"${t}\"; add one to toolPackages in modules/k8s/access.nix")
    );

  # The wrapper's own tools. kubectl is here rather than borrowed from
  # allowedTools because minting is the wrapper's job, not the caller's: dropping
  # kubectl from allowedTools must not stop the thing from working.
  # Everything the wrapper itself shells out to. Enumerated rather than
  # borrowed from the system profile: run mode inherits nothing it does not
  # need, so the profile must not be on this PATH at all.
  wrapperTools = with pkgs; [
    age
    age-plugin-fido2-hmac
    jq
    kubectl
    tmux
    bash
    coreutils
    gnugrep
    gnused
    getent # a package of its own; glibc.bin does not carry it
  ];

  runTools = resolve "allowedTools" cfg.allowedTools;
  shellExtraTools = resolve "shellTools" cfg.shellTools;

  tools = lib.unique (wrapperTools ++ runTools ++ shellExtraTools);

  # Three PATHs, because the two modes want different things and sharing one
  # forced a second mechanism to take it back. Run mode execs a named tool as
  # root with a break-glass token: its PATH is exactly what may be run, so the
  # restriction is the PATH itself rather than a list of strings compared against
  # it. The session is a person at a prompt who needs an editor and a pager, so
  # it gets the system profile -- which is precisely what run mode must not have.
  # /run/wrappers/bin carries the setuid sudo; the package's own binary refuses to
  # run without the setuid bit even as root. The directory is root-owned.
  wrapperPath = lib.makeBinPath wrapperTools + ":/run/wrappers/bin";
  runPath = lib.makeBinPath runTools;
  shellPath =
    lib.makeBinPath (lib.unique (runTools ++ shellExtraTools ++ [pkgs.tmux]))
    + ":/run/current-system/sw/bin";

  # Settings and tool paths are pinned here, at build time, and that is the
  # point: the wrapper runs as root, so it must not pick up binaries from a
  # directory the user can write to, and sudo's env_reset would strip these if
  # they arrived as environment variables. toShellVar quotes the values, so a
  # path with a space or a `$` cannot break out into executing code as root.
  settings = {
    K8S_TOOL_PATH = wrapperPath;
    K8S_RUN_PATH = runPath;
    K8S_SHELL_PATH = shellPath;
    K8S_MINTER_AGE = cfg.cipherFile;
    K8S_AGE_IDENTITY = cfg.identityFile;
    K8S_SA_NAMESPACE = cfg.serviceAccountNamespace;
    K8S_SA_RO = cfg.readOnlyServiceAccount;
    K8S_SA_BREAKGLASS = cfg.breakGlassServiceAccount;
    K8S_TTL = cfg.ttl;
    K8S_SESSION_TTL = cfg.sessionTtl;
    K8S_SESSION_FILE = cfg.sessionFile;
    K8S_OPS_USER = cfg.opsUser;
    K8S_SHELL_TTL = cfg.shellTtl;
    K8S_TERMINALS = lib.concatStringsSep " " cfg.terminals;
    # Only when k9s is actually in shellTools: otherwise this would drag the
    # package into the closure of a wrapper that never runs it.
    K8S_K9S_SKIN =
      if lib.elem "k9s" cfg.shellTools
      then "${pkgs.k9s}/share/k9s/skins/transparent.yaml"
      else "";
  };

  wrapper = pkgs.writeShellApplication {
    name = "k8s";
    # The script overwrites PATH with K8S_TOOL_PATH, so this has no runtime
    # effect; it stays so the derivation still declares what it depends on.
    runtimeInputs = tools;
    text =
      lib.concatLines (lib.mapAttrsToList lib.strings.toShellVar settings)
      + builtins.readFile ./k8s.sh;
  };

  duration = lib.types.strMatching "[0-9]+[smh]";
in {
  options.local.k8s.access = {
    enable =
      lib.mkEnableOption "hardware-gated Kubernetes access with short-lived tokens";

    cipherFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/k8s/minter.conf.age";
      description = ''
        A kubeconfig for the minting ServiceAccount, age-encrypted to a FIDO2
        credential on a hardware token.

        The account it authenticates holds one verb: create a token for the two
        ServiceAccounts below. It cannot read a Secret, list a Pod, create a
        binding, or mint for itself.

        Do not read that as "this file is harmless". One of the two accounts is
        cluster-admin, so whoever holds the *decrypted* contents is cluster-admin
        one API call away. What the indirection buys is that the call is recorded
        by the apiserver instead of being a silent read of a stored admin token,
        and that getting there costs a PIN and a touch -- factors a process
        running as the user cannot supply. The file alone, without the token, is
        inert. Treat it as a locked admin credential, not a low-value one.

        Which cluster is reached comes from this kubeconfig's own
        current-context, since the wrapper renders the session with --minify.

        Deliberately not declarative and not in this repository: it is
        per-machine credential state, and this repository is public. Create it
        with:
          age -R <recipient> -o /etc/k8s/minter.conf.age <plaintext kubeconfig>
      '';
    };

    identityFile = lib.mkOption {
      type = lib.types.str;
      default = "/etc/k8s/identity.txt";
      description = ''
        Output of `age-plugin-fido2-hmac -g`. Not a secret -- it holds a
        credential ID and salt, useless without the token -- but it *is*
        required: the credential is non-resident, so the token itself stores
        nothing and cannot decrypt without this file. Back it up wherever the
        token's replacement plan lives.
      '';
    };

    sessionFile = lib.mkOption {
      type = lib.types.str;
      default = ".kube/k8s-session";
      description = ''
        Where `k8s login` writes the session, relative to the user's home.
        Deliberately NOT ~/.kube/config: gcloud owns that file for the GKE
        contexts, and overwriting it would delete them. Point KUBECONFIG at
        both so the clusters coexist:
          export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/k8s-session
      '';
    };

    serviceAccountNamespace = lib.mkOption {
      type = lib.types.str;
      default = "team-access";
      description = ''
        Namespace holding the three identities this wrapper depends on: the
        minter whose kubeconfig is encrypted on disk, and the read-only and
        break-glass accounts it issues tokens for.

        This is a control point, not just an address. Anyone who can create
        or edit ServiceAccounts and RoleBindings here decides who may mint
        break-glass tokens, so write access to it should be no wider than
        cluster-admin itself. Keep workloads out: a namespace that also runs
        applications accumulates people and controllers with reasons to write
        to it, and each one silently becomes a way to grant cluster access.

        Prefer one such namespace per cluster rather than several. "Who can
        reach this cluster" should be answerable by reading a single place;
        splitting identities across namespaces doubles both the audit surface
        and the set of people who can extend access.

        The default names a namespace to create for the purpose. Where a
        cluster already has one that holds identities and nothing else, point
        this at that instead of standing up a second one beside it -- that
        would be exactly the split warned about above. Which namespace a
        given cluster uses is deployment state, configured per host and not
        recorded here: this repository is public.
      '';
    };

    readOnlyServiceAccount = lib.mkOption {
      type = lib.types.str;
      default = "ops-ro";
      description = "ServiceAccount minted for `login` and for the default profile.";
    };

    breakGlassServiceAccount = lib.mkOption {
      type = lib.types.str;
      default = "breakglass";
      description = ''
        ServiceAccount assumed by `--breakglass`. Expected to be cluster-admin.

        Named after the identity rather than after a permission level, and the
        flag follows: an earlier draft called this readWriteServiceAccount and
        the flag --rw, which understated it badly. Someone reading the config
        would conclude the flag grants write access to objects, when it grants
        everything. An option name should warn, not reassure.

        Break-glass is the established term for pre-arranged emergency access
        -- AWS and Microsoft both document it -- so it carries its own warning
        to anyone reading an audit log, which is where this name surfaces.

        It is cluster-admin rather than a curated write role on purpose. Such
        a role ages badly, and its contents cannot be guessed correctly before
        there is evidence: live on the read-only session for a while, log
        every escalation, and let that log say what a narrower tier should
        contain. When it exists, add it as a separate option and flag -- the
        name --rw is then free to mean what it says.

        Until then, accept the cost: a typo in an escalated command carries
        cluster-admin blast radius. That is the price of not inventing the
        middle tier blind, and the reason escalation is gated per call rather
        than held open for a session.
      '';
    };

    allowedTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["kubectl" "helm"];
      description = ''
        Tools `k8s <tool>` will run. This list *is* run mode's PATH, so it is a
        boundary and not merely a check: a program that is not here cannot be found
        by name at all. Each entry must have a package mapped in toolPackages above,
        or the build fails with that name. k9s is deliberately absent:
        run mode execs as root, and a long-lived TUI in the user's terminal is
        drivable by anything running as that user. It belongs in `shellTools`.
      '';
    };

    shellTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["k9s"];
      description = ''
        Extra tools on the PATH of `k8s shell`, without being runnable as
        `k8s <tool>`. The distinction is the point rather than bookkeeping: a
        tool refused in run mode is refused because it would be a root process
        in a terminal your own uid can drive. Inside a session that objection
        disappears -- the tmux server and the pty belong to the ops account --
        so the same tool is safe there and unsafe here.

        Names are resolved through the same toolPackages table as allowedTools.
      '';
    };

    sudoSecurePath = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/run/wrappers/bin" "/run/current-system/sw/bin"];
      description = ''
        The PATH sudo resolves command names through, replacing the caller's.
        Without it, a process running as the invoking user can prepend a
        directory of its own and own the name `k8s`; the operator then
        authenticates that program into root while believing they ran this one.

        Every entry must be one the invoking user cannot rewrite -- including the
        symlinks along the way, not just the final directory. The default is the
        conservative pair. On a machine where the admin's own tools live in a
        per-user profile, adding `/etc/profiles/per-user/<user>/bin` is safe and
        keeps `sudo <tool>` working: that path is a root-owned store directory
        reached through a symlink in /etc. Its near-twin `~/.nix-profile/bin` is
        not safe and must never be added -- that symlink lives in $HOME.

        This applies to every sudo call on the machine, not only to this wrapper,
        and it also becomes the PATH inside the command sudo runs.
      '';
    };

    terminals = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["*kitty*" "*foot*" "*alacritty*" "*wezterm*" "*ghostty*" "xterm*" "st"];
      description = ''
        Glob patterns matching the `comm` of processes trusted to hold the master
        end of a terminal `k8s shell` may run in.

        An allowlist, because the danger is not tmux specifically. Whoever holds
        the master types into the terminal; a multiplexer does it on request from
        anything with the user's uid, and a process that merely created a pty for
        its own purposes does it directly. Measured on this machine, the coding
        agent held the master of four ptys -- a session opened on one of those
        would need no send-keys at all.

        So anything unrecognised is refused and named. A terminal missing from
        this list produces a loud, fixable refusal; the opposite default would
        produce a silent hole.
      '';
    };

    ttl = lib.mkOption {
      type = duration;
      default = "15m";
      description = "Token lifetime for a single privileged command.";
    };

    sessionTtl = lib.mkOption {
      type = duration;
      default = "8h";
      description = ''
        Token lifetime for `k8s login`. This is the window during which anything
        running as the user -- the coding agent included -- has the read-only
        identity. Shorten it if that matters more than not re-authenticating.
        The apiserver may cap it lower; the real expiry is printed and recorded
        in the generated kubeconfig.
      '';
    };

    opsUser = lib.mkOption {
      type = lib.types.str;
      default = "k8s-ops";
      description = ''
        The account `k8s shell` drops into. It exists for one reason: inside a
        single uid there is nowhere to keep a long-lived token. A file cannot be
        hidden from a process with the same uid, `/proc/PID/environ` is readable
        across processes, and a file held only by a descriptor can be reopened
        through `/proc/PID/fd`. A different uid is the only container the kernel
        actually offers, so the session gets one.

        Deliberately not in `wheel`, with no home to speak of. It holds a
        kubeconfig for the length of a shell and nothing else.
      '';
    };

    shellTtl = lib.mkOption {
      type = duration;
      default = "1h";
      description = ''
        Token lifetime for `k8s shell` when --ttl is not given. Unlike a login
        session this one is not readable by the user, so the risk it carries is
        not "the agent reads the file" but "the terminal stays unattended".
        An hour is a working window; the token expires on its own and the shell
        simply stops working.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [wrapper];

    # The identity `k8s shell` runs as. No password, no wheel, no shell for
    # anything but this: it is a container for a kubeconfig, not an account
    # anyone logs into. `dmitry` cannot read its files, its environment or its
    # memory, which is the entire point.
    users.groups.${cfg.opsUser} = {};
    users.users.${cfg.opsUser} = {
      isSystemUser = true;
      group = cfg.opsUser;
      description = "Holds a short-lived Kubernetes session for k8s shell";
      home = "/var/empty";
      createHome = false;
      shell = pkgs.bashInteractive;
    };

    systemd.tmpfiles.rules =
      map (d: "d ${d} 0700 root root -")
      (lib.unique [(dirOf cfg.cipherFile) (dirOf cfg.identityFile)])
      ++ [
        "z ${cfg.cipherFile} 0400 root root -"
        "z ${cfg.identityFile} 0400 root root -"
      ];

    # Without secure_path, sudo resolves a bare command name through the
    # *caller's* PATH. Anything running as that user can prepend a directory of
    # its own -- one line in ~/.bashrc -- and own the name `k8s`. The operator
    # then types the command they meant, sees the PIN and touch prompt they
    # expected, and authenticates a different program into root. The hardware
    # factor is not forged in that attack, it is redirected.
    #
    # The list is every PATH entry on this machine that the user cannot rewrite.
    # `/etc/profiles/per-user/<user>/bin` is included deliberately: it is a
    # root-owned store path whose symlink lives in /etc, so home-manager can only
    # change it through a root activation, and leaving it out would break `sudo`
    # for the ~100 programs that exist only there. Its near-twin
    # `~/.nix-profile/bin` is excluded for the opposite reason -- that symlink
    # sits in $HOME, where a process running as the user repoints it at will.
    # Do not "complete" this list with it.
    #
    # TMUX used to be kept through env_reset so the wrapper could see it. It no
    # longer is: reading that variable was the weak check, and the wrapper now asks
    # the kernel which process holds the master end of its terminal instead. One
    # fewer attacker-controlled variable reaching a root process.
    #
    # This closes the file-planting route for every sudo call on the machine. It
    # does not close a shell alias or function: `alias sudo='sudo '` makes bash
    # expand the next word too, and that happens before sudo exists. The answer
    # to that one is to start privileged work from the session picker rather than
    # by typing into a shell whose rc files the agent can write.
    #
    # A cached sudo ticket would let anything running as the user call the
    # wrapper without a PIN for the next 15 minutes, leaving only the touch --
    # exactly the factor an unattended process can sit and wait for. Both paths
    # are listed because sudo matches the command as resolved, and the store
    # path is reachable directly. This is defence in depth: the hardware gate is
    # what actually holds, since age demands PIN and touch either way.
    security.sudo.extraConfig = ''
      Defaults secure_path="${lib.concatStringsSep ":" cfg.sudoSecurePath}"

      Cmnd_Alias K8S_ACCESS = /run/current-system/sw/bin/k8s, /nix/store/*/bin/k8s
      Defaults!K8S_ACCESS timestamp_timeout=0
    '';
  };
}

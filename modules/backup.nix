{
  config,
  lib,
  username,
  ...
}: let
  cfg = config.local.backup;
  home = config.users.users.${username}.home;

  # Outside the repository, which is public. The password and rclone.conf are
  # created by hand.
  secretsDir = "/var/lib/restic";

  # Extra excludes, kept outside this repository. restic syntax, one pattern per
  # line, absolute paths ($HOME is /root in the service). Root-owned like the
  # token: whoever can write it decides what gets backed up, and an empty
  # snapshot fails as quietly as a deleted one.
  excludeFile = "${secretsDir}/exclude";
in {
  options.local.backup.enable =
    lib.mkEnableOption "daily restic backups of the home directory to Yandex Disk";

  config = lib.mkIf cfg.enable {
    # Runs as root with root-only secrets, and that is the point: the rclone token
    # can delete the repository, so nothing running as the user -- an agent
    # included -- may read it. A backup that the thing it guards against can
    # erase is not a backup.
    #
    # The timer is the module default, daily with Persistent, which catches up
    # on the next boot or resume when the laptop was asleep at midnight.
    # inhibitsSleep stays off: closing the lid on battery hibernates
    # (hardware/laptop.nix), and a backup holding that off would cook the machine
    # in a bag.
    services.restic.backups.yandex = {
      # restic has no Yandex backend of its own; rclone's talks to the Disk REST
      # API. The restic package already carries rclone on its PATH.
      repository = "rclone:yandex:restic/${config.networking.hostName}";
      # No `initialize`: the repository is created once by hand, with
      # `restic-yandex init`. With it, a repository deleted from the Disk is
      # silently replaced by an empty one on the next run -- the backup reports
      # success, the history is gone, and the recovery key opens nothing.

      # Without this password the repository is noise. It must also live
      # somewhere that is not this disk, or a dead disk takes the backup with it.
      passwordFile = "${secretsDir}/password";

      # Must stay writable by the service: rclone saves the refreshed OAuth token
      # back into it.
      rcloneConfigFile = "${secretsDir}/rclone.conf";
      # Otherwise every pack `prune` deletes lands in the Yandex trash and keeps
      # counting against the quota.
      rcloneConfig.hard_delete = true;

      paths = [home];

      extraBackupArgs = [
        "--exclude-caches" # directories carrying a CACHEDIR.TAG
        "--one-file-system" # not into whatever gets mounted under $HOME
        "--exclude-file=${excludeFile}"
      ];

      exclude = [
        # Regenerable: caches, package stores, containers, downloads.
        "${home}/.cache"
        "${home}/.local/share/Trash"
        "${home}/.local/share/docker" # rootless Docker images and volumes
        "${home}/.local/share/libvirt" # VM disks, re-uploaded in large deltas
        "${home}/.local/share/NuGet"
        "${home}/.local/share/Nuget"
        "${home}/.nuget"
        "${home}/.npm"
        "${home}/.dotnet"
        "${home}/.ollama"
        "${home}/.juicefs"
        "${home}/.config/*/Cache" # Electron apps
        "${home}/.config/*/Code Cache"
        "${home}/.config/*/GPUCache"
        "${home}/.config/*/*/Service Worker" # per-profile CacheStorage
        "${home}/.mozilla/firefox/*/storage" # site storage, refetched on demand
        "${home}/Downloads"

        # Build output, at any depth. Not a bare `bin`: that would take
        # ~/.local/bin and every hand-written script directory with it. Nor
        # `packages`: restored NuGet in a Paket repository, source in a JS
        # monorepo.
        #
        # The configuration is not always called Debug or Release -- a solution
        # is free to name its own, and those were being backed up in full. So
        # match the framework directory as well, which .NET always creates and
        # nothing hand-written is named after; `**` also reaches the deeper
        # bin/<configuration>/Debug/net10.0 layout.
        "node_modules"
        "fable_modules"
        "obj"
        "bin/Debug" # netcoreapp*, and anything dropped beside the framework dir
        "bin/Release"
        "bin/**/net[0-9]*"
        "bin/**/netstandard[0-9]*"

        # Agent working state. The scratch directory fills up with logs and
        # dumps pulled out of running systems, and a worktree is a checkout the
        # repository's own .git -- which is backed up -- can produce again, so
        # only uncommitted changes in one would be lost.
        ".claude/jobs/*/tmp"
        ".claude/worktrees"
        ".claude/file-history"
      ];

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];

      # Verify a little every night rather than everything once a year. Setting
      # checkOpts is what turns the check on at all (runCheck defaults to
      # whether this list is empty).
      #
      # `--read-data` would re-download the whole repository, so instead each run
      # takes a couple of percent of the packs and actually reads them: the whole
      # repository is covered in about two months, and silent corruption at the
      # far end surfaces on its own instead of waiting for a restore. A failure
      # here fails the service, which is what the notification and the waybar
      # indicator already watch.
      checkOpts = [
        "--with-cache" # reuse the cached metadata instead of fetching it again
        "--read-data-subset=2%"
      ];

      # Without a terminal restic reports no progress at all, so a multi-hour
      # first upload would say nothing in the journal until it ended. One line a
      # minute.
      progressFps = 1.0 / 60;

      # The outcome of every run, for the desktop session to pick up
      # (home/services/backup-notify.nix, the waybar module). Readable by all,
      # written by root, so nothing running as the user can forge a success.
      # Runs as ExecStopPost, after failures too. For a oneshot, a run cut short
      # by `systemctl stop` or a shutdown ends as `signal`, not `success`.
      backupCleanupCommand = ''
        if [ "$SERVICE_RESULT" = success ]; then
          touch "$STATE_DIRECTORY/last-success"
        fi
        echo "$SERVICE_RESULT" > "$STATE_DIRECTORY/last-result"
      '';
    };

    systemd.tmpfiles.rules = [
      "d ${secretsDir} 0700 root root -"
      # Created empty when missing: restic refuses to start on an exclude file
      # that does not exist.
      "f ${excludeFile} 0600 root root -"
      "z ${secretsDir}/password 0400 root root -" # re-assert the mode if the file exists
      "z ${secretsDir}/rclone.conf 0600 root root -" # rclone rewrites it on token refresh
    ];

    # A workstation: the first run uploads tens of gigabytes and should not be
    # felt while working.
    systemd.services.restic-backups-yandex.serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";

      # /var/lib/restic-backups-yandex, 0755: where the outcome above is written.
      # Separate from secretsDir, which must stay unreadable to the user.
      StateDirectory = "restic-backups-yandex";
    };
  };
}

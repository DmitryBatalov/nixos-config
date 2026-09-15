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
      initialize = true;

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
        "${home}/Downloads"

        # Build output, at any depth. Not a bare `bin`: that would take
        # ~/.local/bin and every hand-written script directory with it. Nor
        # `packages`: restored NuGet in a Paket repository, source in a JS
        # monorepo.
        "node_modules"
        "obj"
        "bin/Debug"
        "bin/Release"
      ];

      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
      ];

      # Without a terminal restic reports no progress at all, so a multi-hour
      # first upload would say nothing in the journal until it ended. One line a
      # minute.
      progressFps = 1.0 / 60;
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
    };
  };
}

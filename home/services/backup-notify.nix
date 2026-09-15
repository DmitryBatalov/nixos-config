{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  # The job in modules/backup.nix. systemd names the state directory after the
  # unit, and the service records the outcome of every run there.
  unit = "restic-backups-yandex";
  result = "/var/lib/${unit}/last-result";

  notify = pkgs.writeShellScript "backup-notify" ''
    outcome=$(cat ${result}) || exit 0
    [ "$outcome" = success ] && exit 0

    body=$(printf '%s at %s\njournalctl -u %s' \
      "$outcome" "$(date -r ${result} '+%a %d %b %H:%M')" ${unit})
    exec ${pkgs.libnotify}/bin/notify-send --urgency=critical --app-name=restic \
      "Backup failed" "$body"
  '';
in {
  config = lib.mkIf osConfig.local.backup.enable {
    # Critical, because dunst keeps a critical notification on screen until it
    # is dismissed: a run that fails at night is still there in the morning.
    # What this cannot catch -- a reboot before anyone looks, a backup that
    # hangs or never runs at all -- is the waybar module's job.
    systemd.user.paths.backup-notify = {
      Unit.Description = "Watch the outcome of the last backup";
      Path.PathChanged = result;
      Install.WantedBy = ["default.target"];
    };

    systemd.user.services.backup-notify = {
      Unit.Description = "Notify when the last backup failed";
      Service = {
        Type = "oneshot";
        ExecStart = "${notify}";
      };
    };
  };
}

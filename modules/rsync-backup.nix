# Nightly rsync backup to another host over SSH.
#
# Enable by importing this module and setting stanmart-backup.target.
#
# Philosophy:
# - Push, not pull, so the schedule stays in this repo rather than in a NAS web UI.
# - This host holds a key to the target, which is only acceptable because the key is
#   restricted on the far side: authorized_keys pins it to `rrsync -wo <path>`, so it
#   can write into one directory and do nothing else -- no shell, no reads, no
#   forwarding. Snapshots on the target then make even a malicious overwrite
#   recoverable. Without both of those, this direction would be the wrong one.
# - No retention logic here on purpose. The target already snapshots and ships
#   encrypted copies offsite; duplicating that would mean two expiry policies to keep
#   in agreement, and the one on the NAS is better than anything worth writing here.
# - Secrets are deliberately NOT backed up. They live in a password manager, and a
#   backup that carries none is one you can be relaxed about. Restoring needs it.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) mkIf mkOption mkEnableOption types;
  cfg = config.stanmart-backup;
in
{
  options.stanmart-backup = {
    enable = mkEnableOption "nightly rsync backup to a remote host";

    target = mkOption {
      type = types.str;
      example = "backup@192.168.8.150:/volume1/martin/backup/homeassistant";
      description = "rsync destination, as user@host:/path.";
    };

    paths = mkOption {
      type = types.listOf types.str;
      description = "Absolute paths to copy. Directories are copied recursively.";
    };

    excludes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "rsync --exclude patterns.";
    };

    sshKeyFile = mkOption {
      type = types.str;
      default = "/var/lib/secrets/backup-ssh-key";
      description = ''
        Private key for the target. Never in the repo. Generate on this host with
          ssh-keygen -t ed25519 -f <this path> -N ""
        and install the .pub on the target under a forced-command authorized_keys entry.
      '';
    };

    remoteRsync = mkOption {
      type = types.str;
      default = "rsync --fake-super";
      description = ''
        Command run as rsync on the far side. --fake-super stores ownership and modes
        in extended attributes, which matters because an unprivileged rsync cannot set
        them: without it everything restores root-owned, and Node-RED's data directory
        has to come back as uid 1000 or its container will not start.
      '';
    };

    dates = mkOption {
      type = types.str;
      default = "*-*-* 03:30:00";
      description = "systemd calendar expression for the backup run.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.stanmart-backup = {
      description = "rsync backup to ${cfg.target}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        # Fail loudly and early rather than prompting or hanging when the key is absent.
        ExecStartPre = "${pkgs.coreutils}/bin/test -s ${cfg.sshKeyFile}";
        # A script rather than a bare ExecStart line: the invocation nests a quoted
        # ssh command inside -e, and systemd's own quoting rules are one more thing
        # that could be subtly wrong at 3am. This way the exact command is readable
        # in the unit script and behaves like any shell would run it.
        ExecStart = pkgs.writeShellScript "rsync-backup" ''
          set -euo pipefail

          exec ${pkgs.rsync}/bin/rsync \
            --archive \
            --delete \
            --human-readable \
            --stats \
            --rsync-path=${lib.escapeShellArg cfg.remoteRsync} \
            -e ${lib.escapeShellArg (
              lib.concatStringsSep " " [
                "${pkgs.openssh}/bin/ssh"
                "-i ${cfg.sshKeyFile}"
                "-o IdentitiesOnly=yes"
                "-o StrictHostKeyChecking=accept-new"
                "-o BatchMode=yes"
                "-o ConnectTimeout=30"
              ]
            )} \
            ${lib.concatMapStringsSep " " (p: "--exclude=${lib.escapeShellArg p}") cfg.excludes} \
            ${lib.escapeShellArgs cfg.paths} \
            ${lib.escapeShellArg cfg.target}
        '';
      };

      # A missed run because the box was off should still happen.
      unitConfig.StartLimitIntervalSec = 0;
    };

    systemd.timers.stanmart-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dates;
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/secrets 0700 root root -"
    ];
  };
}

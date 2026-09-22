# Nightly backup of service state to an SMB share.
#
# Enable by importing this module and setting stanmart-backup.share.
#
# Why SMB rather than rsync over SSH, which would be the reflex:
#   DSM only permits SSH logins for members of the administrators group. A key for an
#   admin account is a worse credential than a password for an account restricted to
#   one share, so the obvious "more secure" transport is the less secure one here.
#   Synology's permission model is built around share ACLs; this uses it as intended.
#
# Why a tarball rather than a file-by-file copy:
#   SMB does not carry POSIX ownership, and Node-RED's data directory has to restore
#   as uid 1000 or its container will not start. tar records ownership, modes and
#   symlinks *inside* the archive, so the destination filesystem's limitations stop
#   mattering. At a few MB the loss of incrementality costs nothing.
#
# Retention is deliberately absent. The share is snapshotted and shipped offsite
# encrypted by the NAS; a second expiry policy here would only be something to keep
# in agreement with that one. The archive name is fixed and overwritten nightly --
# history is the snapshots, not a pile of dated files.
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
    enable = mkEnableOption "nightly state backup to an SMB share";

    share = mkOption {
      type = types.str;
      example = "//192.168.8.150/backup-external";
      description = "SMB share to write the archive to.";
    };

    subdir = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Directory within the share, so several hosts can share one target.";
    };

    credentialsFile = mkOption {
      type = types.str;
      default = "/var/lib/secrets/smb-credentials";
      description = ''
        Never in the repo. A cifs credentials file, mode 0600:

          username=backup
          password=...

        The account it names should have write access to this share and nothing else.
      '';
    };

    paths = mkOption {
      type = types.listOf types.str;
      example = [ "/var/lib/zigbee2mqtt" ];
      description = "Absolute paths to archive. Stored relative, so restore is explicit.";
    };

    excludes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "tar --exclude patterns.";
    };

    dates = mkOption {
      type = types.str;
      default = "*-*-* 03:30:00";
      description = "systemd calendar expression for the backup run.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.stanmart-backup = {
      description = "Back up service state to ${cfg.share}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/test -s ${cfg.credentialsFile}";
        ExecStart = pkgs.writeShellScript "backup" ''
          set -euo pipefail

          archive=${lib.escapeShellArg "${cfg.subdir}.tar"}
          mnt=$(${pkgs.coreutils}/bin/mktemp -d)

          # The share is mounted only for the duration of the run: nothing is left
          # mounted for a compromised process to find, and a stale mount cannot
          # silently turn a backup into a write to the local disk.
          cleanup() {
            ${pkgs.util-linux}/bin/umount "$mnt" 2>/dev/null || true
            ${pkgs.coreutils}/bin/rmdir "$mnt" 2>/dev/null || true
          }
          trap cleanup EXIT

          ${pkgs.util-linux}/bin/mount -t cifs \
            -o credentials=${cfg.credentialsFile},vers=3.0,file_mode=0600,dir_mode=0700,nounix,noserverino \
            ${lib.escapeShellArg cfg.share} "$mnt"

          ${pkgs.coreutils}/bin/mkdir -p "$mnt/${cfg.subdir}"

          # Skip paths that do not exist rather than failing the whole run: a service
          # that is configured off has no state directory, and tar exits 2 on a missing
          # path. Warn about each one, though -- silently backing up less than intended
          # is how a backup quietly stops covering something that was renamed.
          targets=()
          for p in ${lib.escapeShellArgs (map (lib.removePrefix "/") cfg.paths)}; do
            if [ -e "/$p" ]; then
              targets+=("$p")
            else
              echo "note: skipping /$p, does not exist" >&2
            fi
          done

          if [ ''${#targets[@]} -eq 0 ]; then
            echo "nothing to back up: none of the configured paths exist" >&2
            exit 1
          fi

          # Write beside the live archive and rename, so a run that dies partway
          # cannot leave a truncated file where the only good copy used to be.
          set +e
          # Deliberately uncompressed. A flipped bit in a gzip stream destroys
          # everything after it, while damage to a plain tar costs one file and leaves
          # the rest extractable -- which matters for an archive whose reason to exist
          # is the Zigbee network key. It is also redundant work: the NAS compresses on
          # the way offsite, and can compress this at rest if the share has btrfs
          # compression on. At a few MB the space saved was never the point.
          ${pkgs.gnutar}/bin/tar \
            --create \
            --file "$mnt/${cfg.subdir}/$archive.tmp" \
            --directory / \
            ${lib.concatMapStringsSep " " (p: "--exclude=${lib.escapeShellArg p}") cfg.excludes} \
            "''${targets[@]}"
          rc=$?
          set -e

          # 1 means a file changed while being read. These services write occasionally
          # and the volatile one (the recorder database) is excluded, so treat it as a
          # warning rather than failing a backup that is almost certainly fine.
          if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
            echo "tar failed with status $rc" >&2
            exit "$rc"
          fi
          [ "$rc" -eq 1 ] && echo "note: a file changed while being archived" >&2

          ${pkgs.coreutils}/bin/mv -f "$mnt/${cfg.subdir}/$archive.tmp" "$mnt/${cfg.subdir}/$archive"
          echo "wrote $(${pkgs.coreutils}/bin/du -h "$mnt/${cfg.subdir}/$archive" | ${pkgs.coreutils}/bin/cut -f1) to ${cfg.share}/${cfg.subdir}/$archive"
        '';
      };

      unitConfig.StartLimitIntervalSec = 0;
    };

    systemd.timers.stanmart-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.dates;
        Persistent = true; # a run missed while the box was off still happens
        RandomizedDelaySec = "15m";
      };
    };

    # mount.cifs has to exist on the host; the script's mount call needs it in PATH.
    system.fsPackages = [ pkgs.cifs-utils ];

    systemd.tmpfiles.rules = [
      "d /var/lib/secrets 0700 root root -"
    ];
  };
}

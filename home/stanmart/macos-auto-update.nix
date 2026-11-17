# Auto-update home-manager weekly on macOS via launchd
# Enable by importing this module.
{ config, pkgs, lib, ... }:

let
  flakeUrl = "github:stanmart/nix-config";
  configName = "qc-macbook";
  logFile = "${config.home.homeDirectory}/Library/Logs/nix-update.log";
  # Written by the brewBundle activation step in work.nix when brew bundle fails
  brewFailedMarker = "${config.home.homeDirectory}/.local/state/nix-update/brew-bundle-failed";

  updateScript = pkgs.writeShellScript "nix-update" ''
    set -euo pipefail

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${logFile}"
    }

    # Modal dialog: it stays on screen until dismissed, so a 5 AM failure is still
    # there when the Mac is next used. Blocks this script until then, which is fine.
    alert() {
      /usr/bin/osascript \
        -e 'on run argv' \
        -e 'display alert "Nix auto-update" message (item 1 of argv) as warning' \
        -e 'end run' \
        "$1" >/dev/null 2>&1 || true
    }

    mkdir -p "$(dirname "${logFile}")"
    log "Starting home-manager update"

    if ! command -v nix &> /dev/null; then
      log "ERROR: nix not found"
      exit 1
    fi

    log "Running home-manager switch"
    if nix run home-manager -- switch --flake "${flakeUrl}#${configName}" --refresh 2>&1 | tee -a "${logFile}"; then
      log "Update completed successfully"
    else
      log "ERROR: Update failed"
      alert "home-manager switch failed. See ~/Library/Logs/nix-update.log"
      exit 1
    fi

    if [ -e "${brewFailedMarker}" ]; then
      log "WARNING: brew bundle failed during activation"
      alert "home-manager updated, but brew bundle failed. See ~/Library/Logs/nix-update.log"
    fi
  '';
in
{
  launchd.agents.nix-update = {
    enable = true;
    config = {
      Label = "com.stanmart.nix-update";
      ProgramArguments = [
        "/bin/bash"
        "-c"
        ''export PATH="/nix/var/nix/profiles/default/bin:$PATH"; exec ${updateScript}''
      ];

      # Run weekly on Mondays at 5 AM
      StartCalendarInterval = [{
        Weekday = 1;
        Hour = 5;
        Minute = 0;
      }];

      # launchd's default soft limit is 256 open files; fetching the flake inputs
      # into nix's git cache blows through that ("Too many open files")
      SoftResourceLimits.NumberOfFiles = 65536;

      StandardOutPath = "/tmp/nix-update-stdout.log";
      StandardErrorPath = "/tmp/nix-update-stderr.log";

      EnvironmentVariables = {
        NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
      };
    };
  };
}

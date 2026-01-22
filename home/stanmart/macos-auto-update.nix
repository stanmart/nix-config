# Auto-update home-manager weekly on macOS via launchd
# Enable by importing this module.
{ config, pkgs, lib, ... }:

let
  flakeUrl = "github:stanmart/nix-config";
  configName = "qc-macbook";
  logFile = "${config.home.homeDirectory}/Library/Logs/nix-update.log";

  updateScript = pkgs.writeShellScript "nix-update" ''
    set -euo pipefail

    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${logFile}"
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
      exit 1
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

      StandardOutPath = "/tmp/nix-update-stdout.log";
      StandardErrorPath = "/tmp/nix-update-stderr.log";

      EnvironmentVariables = {
        NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
      };
    };
  };
}

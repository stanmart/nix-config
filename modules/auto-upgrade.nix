# Auto-upgrade module for automatic system updates from GitHub
# Enable by importing this module.
# Checks weekly (Monday dawn) with randomization to spread load.
{ config, lib, ... }:

let
  cfg = config.stanmart-auto-upgrade;
in
{
  options.stanmart-auto-upgrade = {
    flakeOutput = lib.mkOption {
      type = lib.types.str;
      description = ''
        The flake output name for this host (e.g., "hetzner-cloud").
        Must match the key in nixosConfigurations.
      '';
    };

    allowReboot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to automatically reboot the system when required.
        When false, reboots must be performed manually.
      '';
    };

    operation = lib.mkOption {
      type = lib.types.enum [ "switch" "boot" ];
      default = "switch";
      description = ''
        The operation to perform on upgrade:
        - "switch": Apply the new configuration immediately
        - "boot": Configure for next boot but don't switch now
      '';
    };

    dates = lib.mkOption {
      type = lib.types.str;
      default = "Mon *-*-* 04:00:00";
      description = ''
        Systemd calendar expression for when to check for upgrades.
        Default is Monday at 4 AM.
      '';
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = ''
        Random delay in seconds to spread load across machines.
        Default is up to 1 hour.
      '';
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:stanmart/nix-config";
      description = "The flake URI to upgrade from.";
    };
  };

  config = {
    system.autoUpgrade = {
      enable = true;
      flake = "${cfg.flake}#${cfg.flakeOutput}";
      operation = cfg.operation;
      allowReboot = cfg.allowReboot;
      dates = cfg.dates;
      randomizedDelaySec = "${toString cfg.randomizedDelaySec}s";
      flags = [ "--refresh" ];
    };
  };
}

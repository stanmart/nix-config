{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption types getName;
  cfg = config.onepassword;
in
{
  options.onepassword = {
    gui = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the 1Password GUI app (system-level).";
      };

      polkitPolicyOwners = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "stanmart" ];
        description = ''
          Users allowed to authorize 1Password GUI/CLI actions via polkit.
          This is required for smooth desktop integration.
        '';
      };
    };
  };

  config = {
    # CLI always enabled
    programs._1password.enable = true;

    # GUI optional
    security.polkit.enable = mkIf cfg.gui.enable true;
    programs._1password-gui = mkIf cfg.gui.enable {
      enable = true;
      polkitPolicyOwners = cfg.gui.polkitPolicyOwners;
    };

    assertions = [
      {
        assertion = (!cfg.gui.enable) || (cfg.gui.polkitPolicyOwners != [ ]);
        message = ''
          onepassword.gui.enable=true but onepassword.gui.polkitPolicyOwners is empty.
          Set e.g. onepassword.gui.polkitPolicyOwners = [ "stanmart" ];
        '';
      }
    ];
  };
}

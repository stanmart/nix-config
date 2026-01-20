# Host-specific Home Manager configuration for desktop
# GUI-heavy environment with desktop applications
{ config, pkgs, ... }:

{
  # Desktop packages
  home.packages = with pkgs; [
    # Browsers
    chromium
    
    # Desktop tools
    vscode
  ];

  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "stanmart" ];
  };

  # Desktop-specific settings can go here
  # For example: gtk themes, fonts, etc.
}

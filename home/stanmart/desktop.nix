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

  # Git signing with GPG
  programs.git = {
    signing = {
      signByDefault = true;
      key = null; # Uses default GPG key
    };
  };

  # Desktop-specific settings can go here
  # For example: gtk themes, fonts, etc.
}

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
    
    # Fonts
    meslo-lgs-nf
  ];

  # Desktop-specific settings can go here
  # For example: gtk themes, fonts, etc.
}

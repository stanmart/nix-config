# Host-specific Home Manager configuration for desktop
# GUI-heavy environment with desktop applications
{ config, pkgs, ... }:

{
  # Desktop packages
  home.packages = with pkgs; [
    # Browsers
    firefox
    chromium
    
    # Desktop tools
    vscode
    
    # Additional development tools
    htop
    tmux
  ];

  # Desktop-specific settings can go here
  # For example: gtk themes, fonts, etc.
}

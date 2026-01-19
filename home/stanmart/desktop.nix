# Host-specific Home Manager configuration for desktop
# GUI-heavy environment with desktop applications
{ config, pkgs, ... }:

{
  imports = [
    ./oh-my-zsh.nix
  ];

  # Desktop packages
  home.packages = with pkgs; [
    # Browsers
    chromium
    
    # Desktop tools
    vscode
  ];

  # Desktop-specific settings can go here
  # For example: gtk themes, fonts, etc.
}

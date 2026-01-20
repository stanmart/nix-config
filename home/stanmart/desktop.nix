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

  # Git signing with GPG
  programs.git = {
    signing = {
      signByDefault = true;
      key = null; # Uses default GPG key
    };
    
    # Rewrite GitHub URLs to use SSH (requires proper SSH key setup)
    settings = {
      "url \"git@github.com:\"" = {
        insteadOf = [
          "git@github.com:"
          "http://github.com/"
          "https://github.com/"
        ];
      };
    };
  };

  # Desktop-specific settings can go here
  # For example: gtk themes, fonts, etc.
}

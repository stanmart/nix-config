# Host-specific Home Manager configuration for Raspberry Pi
# Minimal environment for Pi-hole server
{ config, pkgs, ... }:

{
  # Minimal additional packages
  home.packages = with pkgs; [
    htop
  ];
}

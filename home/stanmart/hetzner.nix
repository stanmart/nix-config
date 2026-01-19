# Host-specific Home Manager configuration for Hetzner cloud server
# Server-lean environment
{ config, pkgs, ... }:

{
  # Additional packages for server use
  home.packages = with pkgs; [
    htop
    tmux
  ];
}

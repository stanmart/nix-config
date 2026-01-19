# Host-specific Home Manager configuration for Raspberry Pi
# Minimal environment for Pi-hole server
{ config, pkgs, ... }:

{
  imports = [
    ./oh-my-zsh.nix
  ];

  # No additional packages needed
  # htop and tmux are in common.nix
}

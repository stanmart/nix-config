# Home Manager configuration for stanmart on OrbStack VM
# Local development environment
{ config, pkgs, ... }:

{
  imports = [
    ./common.nix
    ./oh-my-zsh.nix
  ];
}

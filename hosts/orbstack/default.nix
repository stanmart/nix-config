# NixOS configuration for OrbStack VM
# Local development VM on macOS
# Meant to be applied from inside the VM: sudo nixos-rebuild switch --impure --flake .#orbstack
{
  modulesPath,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../../modules/minimal.nix
    ../../modules/onepassword.nix
    /etc/nixos/configuration.nix
  ];
}

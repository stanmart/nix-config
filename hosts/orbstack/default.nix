# NixOS configuration for OrbStack VM
# Local development VM on macOS
# Meant to be applied from inside the VM: sudo nixos-rebuild switch --impure --flake .#orbstack --option filter-syscalls false
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
    /etc/nixos/configuration.nix
  ];
}

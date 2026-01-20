# NixOS configuration for OrbStack VM
# Local development VM on macOS
# Meant to be applied from inside the VM: sudo nixos-rebuild switch --flake .#orbstack
{ lib, ... }:

let
  required = [
    "/etc/nixos/orbstack.nix"
    "/etc/nixos/incus.nix"
    "/etc/nixos/configuration.nix"
  ];
  haveOrbstackGenerated = builtins.all builtins.pathExists required;
in
{
  imports =
    [
      ../../modules/minimal.nix
      ../../modules/onepassword.nix
    ]
    ++ lib.optionals (!haveOrbstackGenerated) [
      ./fallback.nix
    ]
    ++ lib.optionals haveOrbstackGenerated [
      /etc/nixos/configuration.nix
      # The other two are imported by configuration.nix
    ];

  system.activationScripts.orbstackGuard.text = ''
    if [ ! -f /etc/nixos/orbstack.nix ] || [ ! -f /etc/nixos/incus.nix ]; then
      echo "ERROR: OrbStack generated config missing on this machine." >&2
      echo "Refusing to activate to avoid breaking the VM." >&2
      exit 1
    fi
  '';
}

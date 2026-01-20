# Just enough so the config evaluates/builds off-VM.
# OrbStack-generated /etc/nixos/configuration.nix will override this on the VM.

{ lib, pkgs, ... }:

{
  boot.isContainer = lib.mkDefault true;

  # Match orbstack's default user setup
  users.users.stanmart = {
    uid = lib.mkDefault 501;
    extraGroups = lib.mkDefault [ "wheel" "orbstack" ];
    isSystemUser = lib.mkDefault true;
    group = lib.mkDefault "users";
    createHome = lib.mkDefault true;
    home = lib.mkDefault "/home/stanmart";
    homeMode = lib.mkDefault "700";
    useDefaultShell = lib.mkDefault true;
    openssh.authorizedKeys.keys = lib.mkDefault [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUXDcdw+FfLyMYNWmKs/j0LPAI4N29QzRJr92eR0vmK"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOPnYdF6Hbom3qxjSiM6mzXA6Luv5SB8N4v2axhgoYnvAAAABHNzaDo="
    ];
  };

  users.mutableUsers = lib.mkDefault false;
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  system.stateVersion = lib.mkDefault "26.05";
}

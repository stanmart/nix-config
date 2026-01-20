# Just enough so the config evaluates/builds off-VM.
# OrbStack-generated /etc/nixos/configuration.nix will override this on the VM.

{ lib, pkgs, ... }:

{

  boot.isContainer = lib.mkDefault true;

  fileSystems."/" = lib.mkDefault {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  # Match orbstack's default user setup
  users.users.stanmart = {
    uid = 501;
    isSystemUser = true;
    group = "users";
    createHome = true;
    home = "/home/stanmart";
    homeMode = "700";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUXDcdw+FfLyMYNWmKs/j0LPAI4N29QzRJr92eR0vmK"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOPnYdF6Hbom3qxjSiM6mzXA6Luv5SB8N4v2axhgoYnvAAAABHNzaDo="
    ];
  };

  users.mutableUsers = lib.mkDefault false;
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  system.stateVersion = lib.mkDefault "26.05";
}

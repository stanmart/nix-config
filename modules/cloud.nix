# Cloud/server-specific configuration
# For headless VMs and servers (not for desktop/physical machines)
{ config, pkgs, ... }:

{
  # Passwordless sudo for wheel group (cloud servers only)
  security.sudo.wheelNeedsPassword = false;

  # Docker for containers
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Add user to docker group
  users.users.stanmart.extraGroups = [ "docker" ];
}

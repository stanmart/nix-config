# NixOS configuration for Raspberry Pi with Pi-hole
# Initial minimal configuration for aarch64
{
  config,
  pkgs,
  ...
}:
{
  # System state version
  system.stateVersion = "24.05";

  # Raspberry Pi specific hardware
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Root filesystem (assumes SD card setup)
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  # Enable podman for containers
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  # Add docker group compatibility for podman
  users.users.stanmart.extraGroups = [ "podman" ];

  # Pi-hole will be added later as a container
  # For now, just ensure the networking is ready
}

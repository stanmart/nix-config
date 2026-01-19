# NixOS configuration for Raspberry Pi with Pi-hole
# Initial minimal configuration for aarch64
{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules/pihole.nix
  ];

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


  # your existing raspi settings...
  system.stateVersion = "24.05";
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  pihole = {
    interface = "eth0";
    enableDhcp = true;
    hostIp = "192.168.8.188";
  };

  services.tailscale.extraUpFlags = [
    "--advertise-routes=true"
  ];
}

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
    ../../modules/auto-upgrade.nix
  ];

  # Auto-upgrade from GitHub weekly
  stanmart-auto-upgrade = {
    flakeOutput = "raspi-pihole";
    allowReboot = true;  # Headless server, safe to reboot
  };

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

  pihole = {
    interface = "eth0";
    enableDhcp = true;
    hostIp = "192.168.8.188";
  };

  # --advertise-routes takes CIDRs, not a boolean; "true" is not a route and the flag
  # would have advertised nothing. Remote access to the LAN over the tailnet depends
  # on this, and the route still has to be approved in the admin console.
  services.tailscale.extraUpFlags = [
    "--advertise-routes=192.168.8.0/24"
  ];

  # The device will be its own DNS provider
  services.resolved.enable = false;
}

# NixOS configuration for Hetzner cloud VM
# Deploy with: nixos-anywhere --flake .#hetzner-cloud stanmart@<ip>
# Manage with: nixos-rebuild switch --flake .#hetzner-cloud
{
  modulesPath,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  # No password prompt for sudo
  security.sudo.wheelNeedsPassword = false;

  # Boot loader configuration for GRUB with EFI
  boot.loader.grub = {
    # disko will add all devices that have a EF02 partition
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # System state version - don't change this after initial install
  system.stateVersion = "24.05";

  # Caddy reverse proxy
  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
      # Caddy configuration file
      # Reload with: sudo systemctl reload caddy
      
      # Uncomment and modify the block below:
      # Subdomain-based routing example:
      # app1.example.com {
      #     reverse_proxy localhost:8080
      # }
      # 
      # app2.example.com {
      #     reverse_proxy localhost:3000
      # }
      
      # Path-based routing example:
      # example.com {
      #     reverse_proxy /api/* localhost:8080
      #     reverse_proxy /* localhost:3000
      # }
    '';
  };

  # Additional firewall ports for Caddy
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}

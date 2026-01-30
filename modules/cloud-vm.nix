# Shared configuration for cloud VMs (Hetzner, AWS, etc.)
# Deploy with: nixos-anywhere --flake .#<hostname> root@<ip>
{ modulesPath, lib, pkgs, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # No password prompt for sudo
  security.sudo.wheelNeedsPassword = false;

  # Boot loader - UEFI with GRUB
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };

  # Caddy reverse proxy
  services.caddy = {
    enable = true;
    configFile = pkgs.writeText "Caddyfile" ''
      # Caddy configuration file
      # Reload with: sudo systemctl reload caddy

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

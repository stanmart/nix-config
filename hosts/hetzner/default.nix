# NixOS configuration for Hetzner cloud VM
# Deploy with: nixos-anywhere --flake .#hetzner root@<ip>
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/cloud-vm.nix
    ../../modules/disk-config.nix
    ../../modules/auto-upgrade.nix
  ];

  # Auto-upgrade from GitHub weekly
  stanmart-auto-upgrade = {
    flakeOutput = "hetzner";
    allowReboot = true;
  };

  # Cloud-init for networking (required for IPv6 on Hetzner)
  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [ "Hetzner" "None" ];
      disable_root = false;
      users = [];
    };
  };
  networking.useDHCP = false;  # Let cloud-init/networkd handle networking
  networking.useNetworkd = true;

  # System state version - don't change this after initial install
  system.stateVersion = "24.05";
}

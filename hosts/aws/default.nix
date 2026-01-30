# NixOS configuration for AWS EC2 instance
# Deploy with: nixos-anywhere --flake .#aws root@<ip>
{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../modules/cloud-vm.nix
    ../../modules/disk-config.nix
    ../../modules/auto-upgrade.nix
  ];

  # AWS-specific kernel modules
  # - ena: Elastic Network Adapter (Nitro instances)
  # - nvme: NVMe storage (Nitro instances)
  # - xen_blkfront: Block storage (older Xen instances)
  boot.initrd.availableKernelModules = [ "ena" "nvme" "xen_blkfront" ];

  # AWS Nitro instances (T3, M5, C5, etc.) use NVMe
  disko.devices.disk.disk1.device = "/dev/nvme0n1";

  # Auto-upgrade from GitHub weekly
  stanmart-auto-upgrade = {
    flakeOutput = "aws";
    allowReboot = true;
  };

  # System state version - don't change this after initial install
  system.stateVersion = "24.05";
}

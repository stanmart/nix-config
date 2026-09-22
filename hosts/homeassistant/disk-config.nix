# Disko layout for the Lenovo ThinkCentre M75n (smart-home host).
#
# Deliberately not modules/disk-config.nix: that one is a hybrid BIOS/UEFI LVM layout
# for cloud VMs, and both of its distinguishing features are wrong here. The EF02 BIOS
# boot partition is dead weight on a UEFI-only machine, and LVM's payoff -- bringing a
# second disk in later as another PV -- cannot happen, because the single M.2 slot is
# what this NVMe occupies.
#
# Plain ext4 rather than btrfs: NixOS generations already cover OS rollback, and the
# container state under /var/lib needs a real off-box backup, not local snapshots.
{ lib, ... }:
{
  disko.devices.disk.main = {
    device = lib.mkDefault "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}

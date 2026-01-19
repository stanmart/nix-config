# NixOS configuration for desktop machine
# Initial configuration with GUI support
{
  config,
  pkgs,
  ...
}:
{
  # System state version
  system.stateVersion = "24.05";

  # Allow unfree packages (needed for some desktop apps like vscode)
  nixpkgs.config.allowUnfree = true;

  # Boot loader for UEFI systems
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Root filesystem (placeholder - adjust based on actual setup)
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  # Enable X11 and desktop environment
  services.xserver.enable = true;
  
  # GNOME desktop
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  
  # Or use KDE Plasma instead:
  # services.displayManager.sddm.enable = true;
  # services.desktopManager.plasma6.enable = true;

  # Enable sound with PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable networking
  networking.networkmanager.enable = true;

  # Add user to relevant groups
  users.users.stanmart.extraGroups = [ "networkmanager" "docker" ];

  # Optional: Docker for development
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };
}

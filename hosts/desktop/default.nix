# NixOS configuration for desktop machine
# Initial configuration with GUI support
{
  config,
  pkgs,
  ...
}:
{

  imports = [
  ../../modules/onepassword.nix
  ];

  # System state version
  system.stateVersion = "24.05";

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

  # AMD Graphics (Ryzen 3300U with Vega iGPU)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # For Steam/gaming
    extraPackages = with pkgs; [
      rocmPackages.clr.icd  # OpenCL support
    ];
  };

  # X11/Wayland with AMD driver
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
  };

  # Display manager and desktop environment
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Minimal GNOME (exclude some default apps)
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany  # web browser
    geary     # email client
    gnome-contacts
    gnome-maps
    gnome-music
  ];

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

  # Gaming
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };
  programs.gamemode.enable = true;

  # Allow unfree packages (Steam, etc.)
  nixpkgs.config.allowUnfree = true;

  # Add user to relevant groups
  users.users.stanmart.extraGroups = [ "networkmanager" ];

  # 1password GUI enabled
  onepassword.gui = {
    enable = true;
    polkitPolicyOwners = [ "stanmart" ];
  };
}

# Base system configuration shared across all hosts
{ config, pkgs, ... }:

{
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Base system packages
  environment.systemPackages = with pkgs; [
    curl
    git
    cloudflared
  ];

  # Enable zsh system-wide (availability only, not configuration)
  programs.zsh.enable = true;

  # User definition
  users.users.stanmart = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUXDcdw+FfLyMYNWmKs/j0LPAI4N29QzRJr92eR0vmK"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOPnYdF6Hbom3qxjSiM6mzXA6Luv5SB8N4v2axhgoYnvAAAABHNzaDo="
    ];
  };

  # Disable root password for security
  users.users.root.hashedPassword = "!";

  # Enable nix-ld for running dynamically linked binaries
  programs.nix-ld.enable = true;

  # SSH configuration (hardened)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      ChallengeResponseAuthentication = false;
      MaxAuthTries = 5;
      X11Forwarding = false;
      AllowUsers = [ "stanmart" ];
    };
  };

  # Fail2ban
  services.fail2ban = {
    enable = true;
    jails.sshd.settings = {
      enabled = true;
      filter = "sshd";
    };
  };

  # Tailscale
  services.tailscale = {
    enable = true;
  };

  # Firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    # Tailscale uses its own firewall rules
    trustedInterfaces = [ "tailscale0" ];
  };

  # Enable automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than-30d";
  };
}

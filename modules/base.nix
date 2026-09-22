# Base system configuration shared across all hosts
{ config, pkgs, ... }:

{

  imports = [
    ./minimal.nix
  ];

  # User definition
  users.users.stanmart = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICUXDcdw+FfLyMYNWmKs/j0LPAI4N29QzRJr92eR0vmK"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOPnYdF6Hbom3qxjSiM6mzXA6Luv5SB8N4v2axhgoYnvAAAABHNzaDo="
    ];
  };

  # Disable root password for security
  users.users.root.hashedPassword = "!";

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
    extraUpFlags = [
      "--ssh"
      "--advertise-exit-node"
      "--accept-routes"
    ];
    # Required for the two flags above to do anything. The flags are only a request
    # to the control plane; the kernel side has to be set up separately:
    #   "server" enables IP forwarding, without which an advertised exit node cannot
    #            actually route a packet;
    #   "client" loosens reverse path filtering, without which return traffic over an
    #            accepted subnet route can be dropped silently.
    # The default is "none", so both flags above were previously inert.
    useRoutingFeatures = "both";
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

  # Docker for containers
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # cloudflared tunnel service
  systemd.services.cloudflared = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/test -s /var/lib/cloudflared/token";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel run --token-file /var/lib/cloudflared/token";
      Restart = "on-failure";
      RestartSec = 2;
    };
  
    # Prevent infinite retry spam when token is missing
    unitConfig = {
      StartLimitIntervalSec = 60;
      StartLimitBurst = 2;
    };
  };

}

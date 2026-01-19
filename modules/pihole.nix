# Pi-hole profile (authoritative for internal split DNS + filtering resolver)
#
# Enable by importing this module.
#
# Philosophy:
# - Pi-hole is the DNS server for clients.
# - Split DNS is implemented explicitly via CNAME records (and whatever those point to).
# - No implicit hostname expansion (avoid expandHosts + local host injection).
# - DHCP is optional and host-specific.
# - Web UI on 8080.
# - No secrets in repo.

{ config, lib, ... }:

let
  inherit (lib) mkIf mkOption types optionals;
  cfg = config.pihole;

  # ---- Network profile (edit once per network) ----
  net = {
    # Local domain -- csigahaz.eu is handled explicitly via CNAME records
    domain = "csigahaz.eu";

    # Router/gateway for DHCP option router
    routerIp = "192.168.8.1";

    # DHCP pool (only used if enableDhcp=true)
    dhcp = {
      rangeStart = "192.168.8.20";
      rangeEnd   = "192.168.8.254";
      leaseTime  = "2d";
      ipv6       = false;
    };

    # quad9 filtered for ipv4 and ipv6
    upstreamDns = [ 
      "9.9.9.9"
      "149.112.112.112" 
      "2620:fe::fe"
      "2620:fe::9"
    ];

    # Blocklists
    blocklists = [
      {
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
        type = "block";
        enabled = true;
        description = "Hagezi Pro";
      }
      {
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt";
        type = "block";
        enabled = true;
        description = "Hagezi Threat Intelligence Feed";
      }
    ];

    # Split DNS: explicit records only
    # Format per your earlier example: "alias,target"
    cnameRecords = [
      "bazarr.csigahaz,csiganas"
      "bazarr.csigahaz.eu,csiganas"
      "csigahaz,csiganas"
      "csigahaz.eu,csiganas"
      "dsm.csigahaz,csiganas"
      "dsm.csigahaz.eu,csiganas"
      "file.csigahaz,csiganas"
      "file.csigahaz.eu,csiganas"
      "logs.csigahaz,csiganas"
      "logs.csigahaz.eu,csiganas"
      "mealie.csigahaz,csiganas"
      "mealie.csigahaz.eu,csiganas"
      "monitoring.csigahaz,csiganas"
      "monitoring.csigahaz.eu,csiganas"
      "nginx-raspi.csigahaz.eu,raspi"
      "nginx.raspi,raspi"
      "paperless.csigahaz,csiganas"
      "paperless.csigahaz.eu,csiganas"
      "pdf.csigahaz,csiganas"
      "pdf.csigahaz.eu,csiganas"
      "photos.csigahaz,csiganas"
      "photos.csigahaz.eu,csiganas"
      "pihole.csigahaz,raspi"
      "pihole.csigahaz.eu,raspi"
      "plex.csigahaz,csiganas"
      "plex.csigahaz.eu,csiganas"
      "portainer.csigahaz,raspi"
      "portainer.csigahaz.eu,raspi"
      "prowlarr.csigahaz,csiganas"
      "prowlarr.csigahaz.eu,csiganas"
      "radarr.csigahaz,csiganas"
      "radarr.csigahaz.eu,csiganas"
      "search.csigahaz,csiganas"
      "search.csigahaz.eu,csiganas"
      "sonarr.csigahaz,csiganas"
      "sonarr.csigahaz.eu,csiganas"
      "streaming.csigahaz,raspi"
      "streaming.csigahaz.eu,raspi"
      "tautulli.csigahaz,csiganas"
      "tautulli.csigahaz.eu,csiganas"
      "torrent.csigahaz,csiganas"
      "torrent.csigahaz.eu,csiganas"
    ];

    # A records
    aRecords = [
      "192.168.8.101 ap.csigahaz"
      "192.168.8.150 csiganas"
      "192.168.8.188 raspi"
      "192.168.8.1 router.csigahaz"
    ];
  };

in
{
  options.pihole = {
    # Host-specific knobs only
    interface = mkOption {
      type = types.str;
      default = "eth0";
      description = "Interface Pi-hole binds to (host-specific).";
    };

    enableDhcp = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Pi-hole DHCP server on this host (host-specific).";
    };

    hostIp = mkOption {
      type = types.str;
      default = "";
      description = "This host's LAN IP (required if enableDhcp=true; used for DHCP option 6).";
    };
  };

  config = {
    services.pihole-ftl = {
      enable = true;

      lists = net.blocklists;

      openFirewallDNS = true;
      openFirewallWebserver = true;
      openFirewallDHCP = cfg.enableDhcp;

      queryLogDeleter.enable = true;

      # Allow NixOS-managed dnsmasq fragments for Pi-hole to consume
      useDnsmasqConfig = true;

      settings = {
        dns = {
          interface = cfg.interface;

          # Keep the domain known to Pi-hole, but DO NOT auto-expand or auto-inject hosts.
          domain = net.domain;

          # No implicit expansion, no auto host injection.
          expandHosts = false;
          domainNeeded = true;

          # Split DNS lives here:
          cnameRecords = net.cnameRecords;

          # Canonical A records
          hosts = net.aRecords;

          # Forwarding for everything else:
          upstreams = net.upstreamDns;
        };

        dhcp = mkIf cfg.enableDhcp {
          active = true;
          start = net.dhcp.rangeStart;
          end = net.dhcp.rangeEnd;
          leaseTime = net.dhcp.leaseTime;
          router = net.routerIp;
          ipv6 = net.dhcp.ipv6;

          # Static DHCP leases
          hosts = [ ];

          # Don’t try to do IPv6 resolution via DHCP path
          resolver.resolveIPv6 = false;
        };

        # If something else provides time, keep Pi-hole NTP off
        ntp = {
          ipv4.active = false;
          ipv6.active = false;
          sync.active = false;
        };

        # Web/API password intentionally not configured here
        # webserver.api.pwhash = "...";
      };
    };

    services.pihole-web = {
      enable = true;
      ports = [ 8080 ];
    };

    assertions = [
      {
        assertion = (!cfg.enableDhcp) || (cfg.hostIp != "");
        message = "pihole.enableDhcp=true requires pihole.hostIp to be set.";
      }
    ];

    # Ensure DHCP server port is open only when DHCP is enabled
    networking.firewall.allowedUDPPorts = optionals cfg.enableDhcp [ 67 ];

    # Silence benign warning about versions file
    systemd.tmpfiles.rules = [
      "f /etc/pihole/versions 0644 pihole pihole - -"
    ];
  };
}

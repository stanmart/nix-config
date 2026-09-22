# Smart-home profile: Home Assistant and friends as OCI containers on the Docker runtime.
#
# Enable by importing this module.
#
# Philosophy:
# - Containers are declared in Nix (virtualisation.oci-containers), but run on Docker
#   -- not systemd-nspawn/NixOS containers -- so upstream images are used as published.
# - Images are pinned by digest in ./container-images.nix and bumped by Renovate.
# - All containers share the host network namespace. Home Assistant needs it for
#   discovery (mDNS/SSDP), and the Matter hub requires it outright.
# - Mosquitto listens on loopback only, so the stack needs no MQTT credentials at all.
# - App state lives under /var/lib/<service>; nothing but the Nix store is managed here.
# - No secrets in the repo: the Matter hub's Home Assistant token is read at runtime
#   from /var/lib/home-assistant-matter-hub/env, the same shape as base.nix's
#   /var/lib/cloudflared/token.
#
# Deliberate limitation: Home Assistant and Zigbee2MQTT both rewrite their own config
# at runtime (Z2M persists pairing state into configuration.yaml, HA owns .storage), so
# those files are SEEDED ONCE and then owned by the app. Managing them from the store
# would wipe paired devices on the next rebuild.

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkOption mkEnableOption types optionalAttrs;
  cfg = config.smarthome;

  images = import ./container-images.nix;

  # ---- Stack profile (edit once) ----
  stack = {
    # Where each service's state lives on the host, and who must own it.
    stateRoot = "/var/lib";

    ports = {
      homeassistant = 8123;
      zigbee2mqtt = 8080;
      nodeRed = 1880;
      matterHub = 8482;
      mqtt = 1883; # loopback only -- deliberately never opened in the firewall
    };

    # node-red's image runs as uid/gid 1000 and will not start if /data is root-owned.
    nodeRedUid = 1000;

    matterHubEnvFile = "/var/lib/home-assistant-matter-hub/env";
  };

  hostNetwork = [ "--network=host" ];

  # Public name -> backend port. Derived from stack.ports above rather than repeated,
  # so a port change cannot leave the proxy pointing somewhere stale. Each entry is
  # served only when the service behind it is actually enabled.
  vhosts = {
    ha = {
      port = stack.ports.homeassistant;
      enabled = true;
    };
    zigbee = {
      port = stack.ports.zigbee2mqtt;
      enabled = cfg.zigbee2mqtt.enable;
    };
    nodered = {
      port = stack.ports.nodeRed;
      enabled = cfg.nodeRed.enable;
    };
    matter = {
      port = stack.ports.matterHub;
      enabled = cfg.matterHub.enable;
    };
  };

  activeVhosts = lib.filterAttrs (_: v: v.enabled) vhosts;

  mosquittoConf = pkgs.writeText "mosquitto.conf" ''
    # Loopback only. Every client (Home Assistant, Zigbee2MQTT, Node-RED) shares the
    # host network namespace, so 127.0.0.1 reaches all of them and nothing else on the
    # LAN can connect. This is what makes anonymous access safe here -- if this listener
    # is ever widened, add authentication in the same commit.
    listener ${toString stack.ports.mqtt} 127.0.0.1
    allow_anonymous true

    persistence true
    persistence_location /mosquitto/data/
    autosave_interval 300

    log_dest stdout
    log_type warning
    log_type error
  '';

  # Seeded once into /var/lib/homeassistant, then owned by Home Assistant.
  haConfigSeed = pkgs.writeText "configuration.yaml" ''
    # Seeded by NixOS on first boot (modules/home-assistant.nix).
    # Home Assistant owns this file from here on -- edit it in place, not in the repo.
    default_config:

    http:
      # Required when reaching HA through the nginx in front of it: without these it
      # rejects proxied requests outright, and the UI never loads.
      use_x_forwarded_for: true
      trusted_proxies:
    ${lib.concatMapStrings (p: "    - \"${p}\"\n") cfg.trustedProxies}
    recorder:
      purge_keep_days: ${toString cfg.recorderKeepDays}

    automation: !include automations.yaml
    script: !include scripts.yaml
    scene: !include scenes.yaml
  '';

in
{
  options.smarthome = {
    coordinator = mkOption {
      type = types.str;
      default = "";
      example = "tcp://192.168.8.60:6638";
      description = ''
        Zigbee coordinator address, passed to Zigbee2MQTT as serial.port.
        A networked coordinator (SLZB-06 class) uses tcp://<ip>:6638 and must be put
        into Zigbee2MQTT / serial-over-TCP mode in its own web UI first.
        A local USB stick would be a /dev/serial/by-id/... path instead -- never
        /dev/ttyUSB0, whose number moves between boots.
      '';
    };

    coordinatorAdapter = mkOption {
      type = types.enum [ "zstack" "ember" "ezsp" "deconz" "zboss" "zigate" ];
      default = "zstack";
      description = ''
        Zigbee2MQTT adapter driver. "zstack" covers the Texas Instruments CC2652/CC1352
        parts used by the SLZB-06 and SLZB-06M; "ember" is the current driver for the
        Silicon Labs EFR32 parts in the SLZB-07.
      '';
    };

    timeZone = mkOption {
      type = types.str;
      default = config.time.timeZone;
      defaultText = lib.literalExpression "config.time.timeZone";
      description = "Timezone handed to Home Assistant via TZ.";
    };

    trustedProxies = mkOption {
      type = types.listOf types.str;
      default = [
        "127.0.0.1"
        "::1"
      ];
      description = ''
        Hosts Home Assistant will accept X-Forwarded-For from. Loopback by default,
        because the nginx that fronts it runs on this same machine. Home Assistant
        rejects proxied requests outright if the proxy is not listed here.
      '';
    };

    proxy = {
      enable = mkEnableOption "an nginx reverse proxy in front of the stack" // {
        default = true;
      };

      domain = mkOption {
        type = types.str;
        default = "csigahaz.eu";
        description = "Zone the service names live under. Served from a wildcard cert.";
      };

      shortDomain = mkOption {
        type = types.str;
        default = "csigahaz";
        description = ''
          The short, non-public form of the zone. No CA will issue for it, since it is
          not a real TLD, so these names get a plain-HTTP redirect to the FQDN rather
          than a certificate that would not validate.
        '';
      };

      acmeEmail = mkOption {
        type = types.str;
        description = "Contact address for the Let's Encrypt account.";
      };

      credentialsFile = mkOption {
        type = types.str;
        default = "/var/lib/secrets/acme-cloudflare.env";
        description = ''
          Runtime file holding CLOUDFLARE_DNS_API_TOKEN=... for the DNS-01 challenge.
          Needs Zone:DNS:Edit on the zone. Never in the repo.
        '';
      };
    };

    recorderKeepDays = mkOption {
      type = types.int;
      default = 30;
      description = ''
        Days of history the recorder keeps. The boot device is NVMe, so this is a disk
        space and UI responsiveness question rather than a write endurance one.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = !config.smarthome.proxy.enable;
      defaultText = lib.literalExpression "!config.smarthome.proxy.enable";
      description = ''
        Open the backend service ports directly to the LAN. Off when the proxy is
        enabled, so the only way in is through nginx and the vhost names -- the
        containers still bind those ports on all interfaces (host networking), the
        firewall is what makes the proxy the single entry point.

        The MQTT port is never opened either way: Mosquitto binds loopback only.
        Discovery (mDNS/SSDP) is independent of this and stays open whenever Home
        Assistant runs, since it is how HA finds devices in the first place.
      '';
    };

    zigbee2mqtt.enable = mkEnableOption "Zigbee2MQTT" // {
      default = true;
      description = ''
        Run Zigbee2MQTT. Turn this off while no coordinator exists: without one it
        cannot connect, and systemd would restart it forever, filling the journal with
        the same failure. Everything else in the stack is independent of it.
      '';
    };
    nodeRed.enable = mkEnableOption "Node-RED" // { default = true; };
    matterHub.enable = mkEnableOption "home-assistant-matter-hub" // { default = true; };
  };

  config = {
    # base.nix already enables Docker and puts stanmart in the docker group. The
    # oci-containers backend defaults to podman, so this is not optional.
    virtualisation.oci-containers.backend = "docker";

    # The Matter hub requires IPv6 on the Docker daemon.
    virtualisation.docker.daemon.settings = {
      ipv6 = true;
      fixed-cidr-v6 = "fd00::/80";
    };

    virtualisation.oci-containers.containers = {
      mosquitto = {
        image = images.mosquitto;
        extraOptions = hostNetwork;
        volumes = [
          "${mosquittoConf}:/mosquitto/config/mosquitto.conf:ro"
          "/var/lib/mosquitto:/mosquitto/data"
        ];
      };

      homeassistant = {
        image = images.homeassistant;
        # Home Assistant's own documented run flags. privileged is required for the
        # hardware integrations (Bluetooth, USB) to see the host's devices.
        privileged = true;
        extraOptions = hostNetwork;
        environment.TZ = cfg.timeZone;
        volumes = [
          "/var/lib/homeassistant:/config"
          "/etc/localtime:/etc/localtime:ro"
          "/run/dbus:/run/dbus:ro" # Bluetooth integration
        ];
        dependsOn = [ "mosquitto" ];
      };

    }
    // optionalAttrs cfg.zigbee2mqtt.enable {
      zigbee2mqtt = {
        image = images.zigbee2mqtt;
        extraOptions = hostNetwork;
        dependsOn = [ "mosquitto" ];
        # ZIGBEE2MQTT_CONFIG_* takes precedence over configuration.yaml, so the static
        # half of the config stays declarative while Zigbee2MQTT keeps ownership of the
        # file it writes pairing state into.
        environment = {
          TZ = cfg.timeZone;
          ZIGBEE2MQTT_CONFIG_MQTT_SERVER = "mqtt://127.0.0.1:${toString stack.ports.mqtt}";
          ZIGBEE2MQTT_CONFIG_SERIAL_PORT = cfg.coordinator;
          ZIGBEE2MQTT_CONFIG_SERIAL_ADAPTER = cfg.coordinatorAdapter;
          ZIGBEE2MQTT_CONFIG_FRONTEND_ENABLED = "true";
          ZIGBEE2MQTT_CONFIG_FRONTEND_PORT = toString stack.ports.zigbee2mqtt;
          ZIGBEE2MQTT_CONFIG_HOMEASSISTANT_ENABLED = "true";
          ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_LEVEL = "info";
        };
        volumes = [ "/var/lib/zigbee2mqtt:/app/data" ];
      };
    }
    // optionalAttrs cfg.nodeRed.enable {
      node-red = {
        image = images.node-red;
        extraOptions = hostNetwork;
        user = "${toString stack.nodeRedUid}:${toString stack.nodeRedUid}";
        environment.TZ = cfg.timeZone;
        volumes = [ "/var/lib/node-red:/data" ];
        dependsOn = [ "mosquitto" ];
      };
    }
    // optionalAttrs cfg.matterHub.enable {
      home-assistant-matter-hub = {
        image = images.home-assistant-matter-hub;
        extraOptions = hostNetwork;
        environment = {
          TZ = cfg.timeZone;
          HAMH_HOME_ASSISTANT_URL = "http://127.0.0.1:${toString stack.ports.homeassistant}";
          HAMH_HTTP_PORT = toString stack.ports.matterHub;
          HAMH_LOG_LEVEL = "info";
        };
        # HAMH_HOME_ASSISTANT_ACCESS_TOKEN lives here, not in the repo. Create a
        # long-lived token in the Home Assistant UI and write it into this file.
        environmentFiles = [ stack.matterHubEnvFile ];
        volumes = [ "/var/lib/home-assistant-matter-hub:/data" ];
        dependsOn = [ "homeassistant" ];
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/mosquitto 0750 root root -"
      "d /var/lib/homeassistant 0750 root root -"
      # Seeded once, then Home Assistant's. C copies only when the target is absent,
      # so a rebuild never clobbers edits made through the UI or by hand.
      "C /var/lib/homeassistant/configuration.yaml 0640 root root - ${haConfigSeed}"
      "f /var/lib/homeassistant/automations.yaml 0640 root root - []"
      "f /var/lib/homeassistant/scripts.yaml 0640 root root -"
      "f /var/lib/homeassistant/scenes.yaml 0640 root root -"
    ]
    ++ lib.optionals cfg.zigbee2mqtt.enable [
      # Holds the Zigbee network key once paired. Losing it means re-pairing every
      # device by hand -- this directory is the one that most needs a backup.
      "d /var/lib/zigbee2mqtt 0750 root root -"
    ]
    ++ lib.optionals cfg.nodeRed.enable [
      # The image's node user is uid 1000; root-owned /data makes it exit on startup.
      "d /var/lib/node-red 0750 ${toString stack.nodeRedUid} ${toString stack.nodeRedUid} -"
    ]
    ++ lib.optionals cfg.matterHub.enable [
      "d /var/lib/home-assistant-matter-hub 0750 root root -"
      # Created empty so the unit starts and reports a clean auth failure rather than
      # failing on a missing EnvironmentFile. Paste the token in after onboarding.
      "f ${stack.matterHubEnvFile} 0600 root root -"
    ]
    ++ lib.optionals cfg.proxy.enable [
      "d /var/lib/secrets 0700 root root -"
      # Likewise: exists but empty, so the ACME unit reports a credentials error
      # instead of dying on a missing EnvironmentFile. Write the Cloudflare token
      # here as CLOUDFLARE_DNS_API_TOKEN=...
      "f ${cfg.proxy.credentialsFile} 0600 root root -"
    ];

    networking.firewall = {
      allowedTCPPorts =
        # Backend ports, only when nothing fronts them.
        lib.optionals cfg.openFirewall (
          [ stack.ports.homeassistant ]
          ++ lib.optional cfg.zigbee2mqtt.enable stack.ports.zigbee2mqtt
          ++ lib.optional cfg.nodeRed.enable stack.ports.nodeRed
          ++ lib.optional cfg.matterHub.enable stack.ports.matterHub
        )
        # 80 is not just an ACME concern -- it carries the short-name redirects.
        ++ lib.optionals cfg.proxy.enable [
          80
          443
        ];

      # Discovery is how Home Assistant finds anything, so it is independent of
      # whether the backend ports are reachable.
      allowedUDPPorts = [
        5353 # mDNS -- HA discovery, and Matter commissioning
        1900 # SSDP
      ]
      ++ lib.optional cfg.matterHub.enable 5540; # Matter operational discovery
    };

    # ---- Reverse proxy ----
    security.acme = mkIf cfg.proxy.enable {
      acceptTerms = true;
      defaults.email = cfg.proxy.acmeEmail;

      # This host renews its own copy of the wildcard rather than being handed one.
      # That is deliberate, not an oversight: sharing a single certificate means
      # copying its private key to every machine that terminates TLS, which is a
      # distribution pipeline plus the key in transit and in backups, re-run every
      # 90 days. A token scoped to one zone never leaves the machine that uses it
      # and can be revoked on its own. The cost is that expiry must be monitored
      # per renewer -- see the homelab notes for the full argument.
      certs.${cfg.proxy.domain} = {
        domain = "*.${cfg.proxy.domain}";
        # DNS-01, not HTTP-01: these names resolve to a LAN address and are never
        # reachable from the internet, so there is no inbound path for a webroot
        # challenge. DNS-01 also gets the wildcard, which HTTP-01 cannot.
        dnsProvider = "cloudflare";
        environmentFile = cfg.proxy.credentialsFile;
        group = config.services.nginx.group;
      };
    };

    services.nginx = mkIf cfg.proxy.enable {
      enable = true;
      recommendedProxySettings = true; # sets X-Forwarded-For / -Proto for HA
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      # Home Assistant backup up/downloads are far larger than the 1m default.
      clientMaxBodySize = "1024m";

      virtualHosts =
        # Real vhosts on the public zone, covered by the wildcard.
        lib.mapAttrs' (
          name: v:
          lib.nameValuePair "${name}.${cfg.proxy.domain}" {
            useACMEHost = cfg.proxy.domain;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString v.port}";
              # Every one of these frontends is a single-page app that loses its
              # live connection without this -- Home Assistant will not even finish
              # loading.
              proxyWebsockets = true;
            };
          }
        ) activeVhosts

        # Short names redirect instead of serving TLS: a *.csigahaz.eu certificate
        # cannot cover *.csigahaz, so serving them would mean a name mismatch on
        # every visit. Plain HTTP, 301 to the FQDN.
        // lib.mapAttrs' (
          name: _:
          lib.nameValuePair "${name}.${cfg.proxy.shortDomain}" {
            locations."/".return = "301 https://${name}.${cfg.proxy.domain}$request_uri";
          }
        ) activeVhosts;
    };


    assertions = [
      {
        assertion = (!cfg.zigbee2mqtt.enable) || (cfg.coordinator != "");
        message = "smarthome.zigbee2mqtt.enable=true requires smarthome.coordinator (tcp://<ip>:6638 for a networked coordinator).";
      }
      {
        assertion = config.virtualisation.docker.enable;
        message = "smarthome requires virtualisation.docker.enable (provided by modules/base.nix).";
      }
    ];
  };
}

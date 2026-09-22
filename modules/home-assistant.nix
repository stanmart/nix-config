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
      # Required when reaching HA through the Synology reverse proxy: without these,
      # HA rejects proxied requests outright.
      use_x_forwarded_for: true
      trusted_proxies:
    ${lib.concatMapStrings (p: "    - ${p}\n") cfg.trustedProxies}
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
      default = [ "192.168.8.150" ];
      description = ''
        Hosts Home Assistant will accept X-Forwarded-For from. Defaults to the Synology,
        which terminates TLS for everything on the LAN.
      '';
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
      default = true;
      description = ''
        Open the service ports to the LAN. The MQTT port is never opened regardless --
        Mosquitto binds loopback only.
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
      "d /var/lib/zigbee2mqtt 0750 root root -"
      # Seeded once, then Home Assistant's. C copies only when the target is absent,
      # so a rebuild never clobbers edits made through the UI or by hand.
      "C /var/lib/homeassistant/configuration.yaml 0640 root root - ${haConfigSeed}"
      "f /var/lib/homeassistant/automations.yaml 0640 root root - []"
      "f /var/lib/homeassistant/scripts.yaml 0640 root root -"
      "f /var/lib/homeassistant/scenes.yaml 0640 root root -"
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
    ];

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        stack.ports.homeassistant
        stack.ports.zigbee2mqtt
      ]
      ++ lib.optional cfg.nodeRed.enable stack.ports.nodeRed
      ++ lib.optional cfg.matterHub.enable stack.ports.matterHub;

      allowedUDPPorts = [
        5353 # mDNS -- Home Assistant discovery, and Matter commissioning
        1900 # SSDP
      ]
      ++ lib.optional cfg.matterHub.enable 5540; # Matter operational discovery
    };

    assertions = [
      {
        assertion = cfg.coordinator != "";
        message = "smarthome.coordinator must be set (tcp://<ip>:6638 for a networked coordinator).";
      }
      {
        assertion = config.virtualisation.docker.enable;
        message = "smarthome requires virtualisation.docker.enable (provided by modules/base.nix).";
      }
    ];
  };
}

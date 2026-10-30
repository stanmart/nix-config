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
#   from /var/lib/secrets/matter-hub.env, the same shape as base.nix's
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
      # Wyoming speech-to-text, also loopback only. Voice satellites talk to Home
      # Assistant, never to this directly, so nothing else needs to reach it. Not the
      # image's 10300, a leftover from running beside Whisper; the Wyoming entry in
      # Home Assistant points here, so moving it means re-adding that entry.
      speechToPhrase = 10301;
      overgang = 5684; # UDP; the TRÅDFRI app only ever uses this port
    };

    # Images that drop privileges need their state directory owned to match, or they
    # cannot write to it. The failure is not always loud: Node-RED refuses to start,
    # but Mosquitto serves happily and only fails to persist, one line per
    # autosave_interval.
    nodeRedUid = 1000;
    mosquittoUid = 1883;
    overgangUid = 65532; # distroless "nonroot"

    # Environment files are kept in /var/lib/secrets (0700 root:root) out of the containers' writable data directories.
    matterHubEnvFile = "/var/lib/secrets/matter-hub.env";
    speechToPhraseEnvFile = "/var/lib/secrets/speech-to-phrase.env";
    overgangEnvFile = "/var/lib/secrets/overgang.env";
  };

  hostNetwork = [ "--network=host" ];

  # Public name -> backend port. Derived from stack.ports above rather than repeated,
  # so a port change cannot leave the proxy pointing somewhere stale. Each entry is
  # served only when the service behind it is actually enabled.
  vhosts = {
    home = {
      port = stack.ports.homeassistant;
      enabled = true;
      # A LAN-only name for the companion app's Internal URL. home.csigahaz.eu also
      # has a public record (the Cloudflare tunnel), so using it for both Internal and
      # External URL leaves the app nothing to switch on when the Wi-Fi changes -- it
      # keeps one URL and waits for DNS caches and a dead websocket to catch up. This
      # name never gets a public record; it exists only in the Pi-hole. An alias on
      # the .eu vhost only, so no plain-HTTP short form comes with it.
      aliases = [ "home-local" ];
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

  # Seeded once into /var/lib/overgang, then edited in place: the room layout follows
  # Home Assistant, which changes without a deploy, so it does not belong in the repo.
  # Restart the container (systemctl restart docker-overgang) after editing. Rooms and
  # devices are listed in ÖVERGÅNG's README; the app shows rooms in the order given.
  overgangConfigSeed = pkgs.writeText "overgang.toml" ''
    # Seeded by NixOS on first boot (modules/home-assistant.nix).
    # Edit in place; restart docker-overgang to apply.
    #
    # The security code and the Home Assistant token come from /var/lib/secrets/overgang.env
    # (OVERGANG_SECURITY_CODE, OVERGANG_HA_TOKEN), never from this file.

    [gateway]
    listen = ":${toString stack.ports.overgang}"
    state_file = "/data/state.json"
    # Phones pair with this, dash-separated, as the gateway's serial number.
    mac = "02:00:00:00:4f:47"
    mdns = true

    [backend]
    kind = "homeassistant"
    url = "ws://127.0.0.1:${toString stack.ports.homeassistant}/api/websocket"

    # [[rooms]]
    # name = "Bedroom"
    # entity = "light.bedroom_ceiling_lights"  # optional: switches the room at once
    #
    #   [[rooms.devices]]
    #   entity = "light.bedroom_bulb_1"
  '';

  # Seeded once into /var/lib/homeassistant, then owned by Home Assistant.
  #
  # Reverse-proxy settings are deliberately NOT here. They are configured once through
  # the UI, at Settings > System > Network:
  #
  #   Use X-Forwarded-For: on
  #   Trusted proxies:     127.0.0.1, ::1   (nginx runs on this same host)
  #
  # Until that is set, every request through nginx returns "400: Bad Request" and the
  # log says "not set-up for reverse proxies". Reaching Home Assistant directly on
  # 8123 still works, which is the way in to fix it:
  #
  #   ssh -L 8123:127.0.0.1:8123 <host>
  #
  # Two reasons this is not in YAML. Home Assistant deprecated HTTP-in-YAML and it
  # stops working in 2027.2.0; and even before that it never worked unattended --
  # a YAML http block was staged as *pending* and reverted unless a human confirmed
  # it in the web UI within five minutes, which no first boot does.
  haConfigSeed = pkgs.writeText "configuration.yaml" ''
    # Seeded by NixOS on first boot (modules/home-assistant.nix).
    # Home Assistant owns this file from here on -- edit it in place, not in the repo.
    default_config:

    # No http: block. Home Assistant deprecated HTTP-in-YAML -- it stops working in
    # 2027.2.0 -- and the reverse-proxy settings now live in the UI under
    # Settings > System > Network.
    #
    # Nothing is lost by dropping it, because it never worked unattended anyway: a
    # YAML http block was only ever *pending* until a human confirmed it through the
    # web UI within five minutes, and reverted otherwise. It looked declarative
    # without being declarative. See the note above haConfigSeed.

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
        Silicon Labs EFR32 parts in the SLZB-07 and SLZB-MR5U.
      '';
    };

    coordinatorTransmitPower = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 20;
      description = ''
        Coordinator radio transmit power in dBm, passed to Zigbee2MQTT as
        advanced.transmit_power. null leaves the adapter's firmware default.
      '';
    };

    timeZone = mkOption {
      type = types.str;
      default = config.time.timeZone;
      defaultText = lib.literalExpression "config.time.timeZone";
      description = "Timezone handed to Home Assistant via TZ.";
    };

    # No trustedProxies option: Home Assistant no longer accepts it from YAML, so an
    # option here could only ever have been a lie about where the setting lives. It is
    # UI state now -- see the note above haConfigSeed.

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
          not a real TLD, so these names are served over plain HTTP instead. Same
          backends, no certificate, no redirect to the FQDN.
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

    # Speech-to-text for Assist, added in Home Assistant through the Wyoming
    # integration (host 127.0.0.1, port from stack.ports). English only, since
    # speech-to-phrase has no Hungarian.
    #
    # Deliberately the only voice service. Whisper was tried and dropped: base-int8
    # took ~1.2 s per command on this CPU and misheard names, which is only worth it
    # with an LLM behind it, and models good enough for Hungarian took 4-20+ s. Piper
    # was dropped too: commands should succeed silently, not answer out loud.
    speechToPhrase.enable = mkEnableOption "speech-to-phrase speech-to-text (Wyoming)" // {
      default = true;
    };

    # Keeps the old TRÅDFRI app working once the lights leave the real gateway.
    overgang.enable = mkEnableOption "ÖVERGÅNG, an IKEA TRÅDFRI gateway emulator on top of Home Assistant";
  };

  config = {
    # base.nix already enables Docker and puts stanmart in the docker group. The
    # oci-containers backend defaults to podman, so this is not optional.
    virtualisation.oci-containers.backend = "docker";

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
          # Our own dashboard cards, served as /local/custom-cards/<file>.js. The
          # dashboard resource that loads them lives in HA's .storage, so its ?v=
          # must be bumped by hand after a change: /local is served with a 31-day
          # browser cache.
          "${./home-assistant-cards}:/config/www/custom-cards:ro"
        ];
        # Soft dependency on mosquitto handled below via systemd.services
      };

    }
    // optionalAttrs cfg.zigbee2mqtt.enable {
      zigbee2mqtt = {
        image = images.zigbee2mqtt;
        extraOptions = hostNetwork;
        # Soft dependency on mosquitto handled below via systemd.services
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
          # Without it, unplugged devices keep their last state in Home Assistant
          # instead of going unavailable. Defaults: mains devices after 10 min of
          # silence (pinged first), battery devices after 25 h.
          ZIGBEE2MQTT_CONFIG_AVAILABILITY_ENABLED = "true";
          ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_LEVEL = "info";
          # Output logs only to console (journald), avoiding unbounded historical log.txt files on disk
          ZIGBEE2MQTT_CONFIG_ADVANCED_LOG_OUTPUT = "[\"console\"]";
        }
        // optionalAttrs (cfg.coordinatorTransmitPower != null) {
          ZIGBEE2MQTT_CONFIG_ADVANCED_TRANSMIT_POWER = toString cfg.coordinatorTransmitPower;
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
          HAMH_MDNS_NETWORK_INTERFACE = "enp2s0f1";
        };
        # HAMH_HOME_ASSISTANT_ACCESS_TOKEN lives here, not in the repo. Create a
        # long-lived token in the Home Assistant UI and write it into this file.
        environmentFiles = [ stack.matterHubEnvFile ];
        volumes = [ "/var/lib/home-assistant-matter-hub:/data" ];
        dependsOn = [ "homeassistant" ];
      };
    }
    // optionalAttrs cfg.speechToPhrase.enable {
      # Recognizes only the commands it can build from Home Assistant's own sentence
      # templates and the names of exposed entities and areas, which makes it near
      # instant. It reads those names over the websocket API, hence the token.
      speech-to-phrase = {
        image = images.speech-to-phrase;
        extraOptions = hostNetwork;
        # The image takes the token only as an argument, so the entrypoint is
        # wrapped to expand it from the env file at runtime. The image's run.sh
        # passes our arguments last, so --uri here overrides its 0.0.0.0.
        entrypoint = "bash";
        cmd = [
          "-c"
          ''
            [ -n "$STP_HASS_TOKEN" ] || { echo "STP_HASS_TOKEN missing from ${stack.speechToPhraseEnvFile}" >&2; exit 1; }
            exec bash /run.sh \
              --uri tcp://127.0.0.1:${toString stack.ports.speechToPhrase} \
              --hass-websocket-uri ws://127.0.0.1:${toString stack.ports.homeassistant}/api/websocket \
              --hass-token "$STP_HASS_TOKEN" \
              --retrain-on-start
          ''
        ];
        # STP_HASS_TOKEN=<long-lived token> lives here, not in the repo.
        environmentFiles = [ stack.speechToPhraseEnvFile ];
        # Models and the trained language model -- both regenerable, not backed up.
        volumes = [
          "/var/lib/speech-to-phrase/models:/models"
          "/var/lib/speech-to-phrase/train:/train"
        ];
        dependsOn = [ "homeassistant" ];
      };
    }
    // optionalAttrs cfg.overgang.enable {
      overgang = {
        image = images.overgang;
        # Host networking for the same reason as the Matter hub: the app finds the
        # gateway over mDNS, and talks CoAP over DTLS on a fixed UDP port. It faces the
        # LAN and holds a Home Assistant token, so it gets nothing else: no root (the
        # image runs as overgangUid), no capabilities, and a read-only filesystem
        # apart from /data.
        extraOptions = hostNetwork ++ [
          "--read-only"
          "--cap-drop=ALL"
          "--security-opt=no-new-privileges"
        ];
        cmd = [
          "serve"
          "-config"
          "/data/overgang.toml"
        ];
        environment.TZ = cfg.timeZone;
        # OVERGANG_SECURITY_CODE (what phones pair with) and OVERGANG_HA_TOKEN (a
        # long-lived Home Assistant token) live here, not in the repo.
        environmentFiles = [ stack.overgangEnvFile ];
        volumes = [ "/var/lib/overgang:/data" ];
        dependsOn = [ "homeassistant" ];
      };
    };

    # dependsOn makes the hub Require Home Assistant, so stopping HA by hand stops the
    # hub too -- but starting HA again does not bring it back, and nothing notices the
    # bridge is gone until a controller shows every accessory as "No Response". Wanting
    # it from HA's unit closes that loop.
    systemd.services.docker-home-assistant-matter-hub = mkIf cfg.matterHub.enable {
      wantedBy = [ "docker-homeassistant.service" ];
    };
    # Same loop as the Matter hub: dependsOn stops it with Home Assistant but never
    # starts it again.
    systemd.services.docker-overgang = mkIf cfg.overgang.enable {
      wantedBy = [ "docker-homeassistant.service" ];
    };
    systemd.services.docker-speech-to-phrase = mkIf cfg.speechToPhrase.enable {
      wantedBy = [ "docker-homeassistant.service" ];
    };

    # Soft ordering on mosquitto so MQTT container bumps do not pull down HA and Z2M
    systemd.services.docker-homeassistant = {
      after = [ "docker-mosquitto.service" ];
      wants = [ "docker-mosquitto.service" ];
    };
    systemd.services.docker-zigbee2mqtt = mkIf cfg.zigbee2mqtt.enable {
      after = [ "docker-mosquitto.service" ];
      wants = [ "docker-mosquitto.service" ];
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/secrets 0700 root root -"
      "d /var/lib/mosquitto 0750 ${toString stack.mosquittoUid} ${toString stack.mosquittoUid} -"
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
    ++ lib.optionals cfg.speechToPhrase.enable [
      "d /var/lib/speech-to-phrase 0750 root root -"
      "d /var/lib/speech-to-phrase/models 0750 root root -"
      "d /var/lib/speech-to-phrase/train 0750 root root -"
      # Same as the Matter hub's: exists but empty, so the container fails with a
      # clear message until a token is written in as STP_HASS_TOKEN=...
      "f ${stack.speechToPhraseEnvFile} 0600 root root -"
    ]
    ++ lib.optionals cfg.overgang.enable [
      # Holds the identities paired phones use. Losing it means re-pairing every phone.
      "d /var/lib/overgang 0750 ${toString stack.overgangUid} ${toString stack.overgangUid} -"
      "C /var/lib/overgang/overgang.toml 0640 ${toString stack.overgangUid} ${toString stack.overgangUid} - ${overgangConfigSeed}"
      # Empty until the security code and token are written in, like the Matter hub's.
      "f ${stack.overgangEnvFile} 0600 root root -"
    ]
    ++ lib.optionals cfg.proxy.enable [
      # Exists but empty, so the ACME unit reports a credentials error
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
      ++ lib.optional cfg.matterHub.enable 5540 # Matter operational discovery
      # CoAP over DTLS for the TRÅDFRI app. Opened regardless of openFirewall: nginx
      # cannot front it, and DTLS-PSK is its own authentication.
      ++ lib.optional cfg.overgang.enable stack.ports.overgang;
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

        # Resolve the challenge against public DNS, not the system resolver.
        #
        # lego finds the zone apex by walking SOA records, and the internal view
        # CNAMEs the apex (csigahaz.eu -> csiganas) for split-horizon. Following that
        # takes lego out of the domain entirely, so it never finds the zone and fails
        # with "failed to find zone eu.: zone could not be found" -- which reads like
        # a credentials problem and is not one.
        #
        # The challenge record is public anyway: it is written to Cloudflare and read
        # back by Let's Encrypt, so the internal view is the wrong one to consult.
        dnsResolver = "1.1.1.1:53";
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
        # Reject anything that does not match a known name. Without this, nginx falls
        # back to whichever server block happens to be declared first, so hitting the
        # box by bare IP silently served Home Assistant -- including its unauthenticated
        # onboarding page, to anyone on the LAN, before onboarding is completed.
        {
          "_" = {
            default = true;
            rejectSSL = true;
            locations."/".return = "444";
          };
        }

        # Real vhosts on the public zone, covered by the wildcard.
        // lib.mapAttrs' (
          name: v:
          lib.nameValuePair "${name}.${cfg.proxy.domain}" {
            serverAliases = map (a: "${a}.${cfg.proxy.domain}") (v.aliases or [ ]);
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

        # Short names serve the same backends over plain HTTP. No CA will issue for a
        # non-public TLD, so TLS here is not an option -- and redirecting to the FQDN
        # instead would defeat the point of having a short name to type. The tradeoff
        # is real and local: anything reaching Home Assistant this way sends its
        # session token in the clear across the LAN, so prefer the .eu name from a
        # browser and keep these for scripts, curl and devices that cannot do TLS.
        // lib.mapAttrs' (
          name: v:
          lib.nameValuePair "${name}.${cfg.proxy.shortDomain}" {
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString v.port}";
              proxyWebsockets = true;
            };
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

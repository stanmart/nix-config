# NixOS configuration for the smart-home host.
#
# Hardware: Lenovo ThinkCentre M75n Thin Client -- AMD Ryzen 3 3300U, 8 GB soldered
# (~5.7 GiB reaches the OS; the Vega iGPU reserves the rest as UMA frame buffer),
# 128 GB Samsung MZALQ128HCHQ NVMe, Realtek RTL8111 ethernet, ASUS USB-AC53 Nano
# (RTL8822BU, in-tree rtw88_8822bu driver).
#
# Deploy with: nixos-anywhere --flake .#homeassistant --target-host stanmart@<ip>
{
  modulesPath,
  lib,
  ...
}:
let
  # ---- Network profile ----
  # The address (192.168.8.20) comes from a DHCP reservation on the Pi-hole keyed to
  # this host's wired MAC, so it is not repeated here -- the reservation is the single
  # source of truth and lives in modules/pihole.nix.
  wiredInterface = "enp2s0f1";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ../../modules/home-assistant.nix
    ../../modules/backup.nix
    ../../modules/auto-upgrade.nix
  ];

  # Nightly copy to the NAS, which already snapshots and ships encrypted copies
  # offsite -- so this only has to move bytes, not manage retention.
  stanmart-backup = {
    enable = true;
    share = "//192.168.8.150/backup-external";
    paths = [
      # The Zigbee network key lives here. Lose it and every paired device has to be
      # re-paired by hand -- this is the directory the whole exercise is for.
      "/var/lib/zigbee2mqtt"
      "/var/lib/homeassistant"
      "/var/lib/node-red"
      "/var/lib/home-assistant-matter-hub"
      "/var/lib/mosquitto"
    ];
    excludes = [
      # The recorder database is the only hot file here, and the least valuable: it
      # is history, and it is regenerable. Excluding it removes the risk of rsync
      # copying a torn SQLite file mid-write, which would otherwise be the one reason
      # to stop the containers during a backup.
      "home-assistant_v2.db*"
      # Regenerable caches and noise.
      "*.log*"
      "tts/"
      "deps/"
    ];
  };

  # Auto-upgrade from GitHub weekly. Headless and unattended, so reboots are allowed --
  # the container stack comes back on its own.
  stanmart-auto-upgrade = {
    flakeOutput = "homeassistant";
    allowReboot = true;
  };

  networking.hostName = "homeassistant";

  # Matches the nixpkgs stable release current at first install. Do not change after
  # installing -- it pins stateful-service defaults, it is not a version to keep fresh.
  system.stateVersion = "26.05";

  time.timeZone = "Europe/Zurich";

  # ---- Boot and hardware ----
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-amd" ];

  hardware.cpu.amd.updateMicrocode = true;
  # rtw88 firmware for the USB wifi adapter, plus AMD microcode above.
  hardware.enableRedistributableFirmware = true;
  # Home Assistant reaches BLE devices through the host's dbus socket.
  hardware.bluetooth.enable = true;

  # nixos-anywhere needs to escalate over SSH. Setting it here rather than in base.nix
  # keeps the change to this host, and means a future reimage needs no manual prep.
  security.sudo.wheelNeedsPassword = false;

  # ---- Networking ----
  # systemd-networkd rather than the scripted backend, for route metrics: the box is
  # dual-homed on one subnet and "which IP is it on today" must not be ambiguous for the
  # host that owns a DNS record.
  # Advertise the LAN over the tailnet. base.nix already advertises this host as an
  # exit node; the subnet route is the half it does not cover.
  #
  # Deliberately overlapping with raspi rather than waiting for it to retire: Tailscale
  # accepts several routers for the same CIDR, elects one as primary and fails over to
  # the other, so running both is redundancy now and a no-op handover later. The
  # Rebuild Plan flags losing this role as something that breaks remote access to the
  # NAS silently, and the way to not have that happen is to not have a handover day.
  #
  # Inert until the route is approved in the admin console -- separately from the exit
  # node, and separately per machine.
  services.tailscale.extraUpFlags = [ "--advertise-routes=192.168.8.0/24" ];

  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = [
    "192.168.8.188" # Pi-hole
    "9.9.9.9" # Quad9, so a Pi-hole outage does not take name resolution with it
  ];

  systemd.network.networks = {
    "10-wired" = {
      matchConfig.Name = wiredInterface;
      networkConfig.DHCP = "ipv4";
      dhcpV4Config = {
        RouteMetric = 100;
        # networking.nameservers below is the single source of truth for resolvers, so
        # don't let a DHCP-supplied list silently compete with it.
        UseDNS = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    # Standby only. Higher metric keeps traffic on the wire whenever it is up, and
    # RequiredForOnline=no means a wifi failure degrades to "no wifi" instead of a host
    # that never finishes booting.
    "20-wireless" = {
      # Match on type, not name. Under EndeavourOS this adapter was "wlan0"; NixOS
      # names it "wlp4s0f4u2u4", and a USB adapter's name encodes the port it is
      # plugged into -- so any literal name is wrong as soon as it moves sockets.
      matchConfig.Type = "wlan";
      networkConfig.DHCP = "ipv4";
      dhcpV4Config = {
        RouteMetric = 600;
        UseDNS = false;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # Wifi is configured on the box, not here. This repo is public, and an SSID is a
  # locating identifier: wardriving databases map distinctive SSIDs to street
  # addresses, and this repo already carries a real name, a domain and a LAN layout.
  # The SSID adds the one thing they don't -- where the house is. It is broadcast in
  # the clear anyway, so publishing it protects nobody locally and only helps someone
  # remote find the place.
  #
  # allowAuxiliaryImperativeNetworks lets wpa_supplicant read a writable
  # /etc/wpa_supplicant/imperative.conf alongside the (empty) declarative one, so both
  # SSID and passphrase stay off GitHub. Join a network once with:
  #   sudo wpa_cli -i wlan0
  #   > add_network / set_network 0 ssid "..." / set_network 0 psk "..." / enable_network 0 / save_config
  # Cheap to do, because the box is wired and wifi is only a standby path.
  networking.wireless = {
    enable = true;
    allowAuxiliaryImperativeNetworks = true;
    networks = { };
  };

  # ---- Monitoring ----
  # Report into the existing Beszel hub. The point is the alerting: without it, the
  # way you find out this box is down is that the lights do not come on.
  #
  # The hub dials the agent on 45876 and authenticates with its own public key, which
  # goes in the environment file as KEY=... -- not in the repo, since the module warns
  # that `environment` lands in the world-readable Nix store.
  #
  # No Docker socket, so no per-container stats. That access is root-equivalent and
  # not worth it for a nicer graph; container logs already go to the journal.
  services.beszel.agent = {
    enable = true;
    openFirewall = true;
    environmentFile = "/var/lib/secrets/beszel-agent.env";
  };

  systemd.tmpfiles.rules = [
    # Created empty so the unit fails with a clear error rather than on a missing
    # EnvironmentFile. Add the hub's key, then restart beszel-agent.
    "f /var/lib/secrets/beszel-agent.env 0600 root root -"
  ];

  # ---- Smart-home stack ----
  smarthome = {
    # No Zigbee coordinator yet. Left off rather than pointed at a placeholder: with
    # nowhere to connect, Zigbee2MQTT would be restarted forever and bury real failures
    # in the journal. To turn it on: buy the coordinator, put it into Zigbee2MQTT /
    # serial-over-TCP mode in its own web UI, set the address here, flip enable.
    zigbee2mqtt.enable = false;
    # coordinator = "tcp://192.168.8.<x>:6638";
    coordinatorAdapter = "zstack";

    # nginx fronts every frontend on its own name, so the backend ports are not
    # opened to the LAN -- the vhosts are the only way in. Already public in this
    # repo's commit history, so the ACME address discloses nothing new.
    proxy.acmeEmail = "martin.stancsics@gmail.com";
  };
}

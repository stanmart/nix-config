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
  # .15 sits below Pi-hole's DHCP pool (192.168.8.20-254), so it is a static address
  # rather than a reservation: this host comes up on a known IP even if Pi-hole is down.
  hostIp = "192.168.8.15";
  prefixLength = 24;
  gateway = "192.168.8.1";
  wiredInterface = "enp2s0f1";
  wirelessInterface = "wlan0";
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ../../modules/home-assistant.nix
    ../../modules/auto-upgrade.nix
  ];

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
  networking.useDHCP = false;
  networking.useNetworkd = true;
  networking.nameservers = [
    "192.168.8.188" # Pi-hole
    "9.9.9.9" # Quad9, so a Pi-hole outage does not take name resolution with it
  ];

  systemd.network.networks = {
    "10-wired" = {
      matchConfig.Name = wiredInterface;
      address = [ "${hostIp}/${toString prefixLength}" ];
      routes = [
        {
          Gateway = gateway;
          Metric = 100;
        }
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    # Standby only. Higher metric keeps traffic on the wire whenever it is up, and
    # RequiredForOnline=no means a wifi failure degrades to "no wifi" instead of a host
    # that never finishes booting.
    "20-wireless" = {
      matchConfig.Name = wirelessInterface;
      networkConfig.DHCP = "ipv4";
      dhcpV4Config.RouteMetric = 600;
      linkConfig.RequiredForOnline = "no";
    };
  };

  networking.wireless = {
    enable = true;
    # No secrets in the repo: the PSK is read at runtime from secretsFile, which maps
    # PSK_HOME -> the "ext:PSK_HOME" reference below. Write it on the host as:
    #   printf 'PSK_HOME=<passphrase>\n' | sudo tee /var/lib/wpa_supplicant/secrets
    secretsFile = "/var/lib/wpa_supplicant/secrets";
    networks."CHANGEME-SSID".pskRaw = "ext:PSK_HOME";
  };

  # Created empty so wpa_supplicant starts and reports a clean auth failure rather than
  # failing outright on a missing secrets file.
  systemd.tmpfiles.rules = [
    "d /var/lib/wpa_supplicant 0700 root root -"
    "f /var/lib/wpa_supplicant/secrets 0600 root root -"
  ];

  # ---- Smart-home stack ----
  smarthome = {
    # The SLZB-06 must be in Zigbee2MQTT / serial-over-TCP mode before this connects.
    coordinator = "tcp://192.168.8.60:6638";
    coordinatorAdapter = "zstack";
  };
}

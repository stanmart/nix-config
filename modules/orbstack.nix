# OrbStack-specific module
# For VMs running in OrbStack on macOS
{ config, pkgs, modulesPath, ... }:

{
  imports = [
    # Include the default lxd configuration.
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # OrbStack requires specific user configuration
  users.users.stanmart = {
    uid = 501;  # Match the macOS user UID
    extraGroups = [ "orbstack" ];

    # simulate isNormalUser, but with an arbitrary UID
    isSystemUser = true;
    group = "users";
    createHome = true;
    home = "/home/stanmart";
    homeMode = "700";
  };

  # This being `true` leads to a few nasty bugs in OrbStack
  users.mutableUsers = false;

  # Networking configuration for OrbStack
  networking = {
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
  };

  systemd.network = {
    enable = true;
    networks."50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  # Extra certificates from OrbStack
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
MIICDDCCAbKgAwIBAgIQDC/LacAP5IKAoDazQYENZDAKBggqhkjOPQQDAjBmMR0w
GwYDVQQKExRPcmJTdGFjayBEZXZlbG9wbWVudDEeMBwGA1UECwwVQ29udGFpbmVy
cyAmIFNlcnZpY2VzMSUwIwYDVQQDExxPcmJTdGFjayBEZXZlbG9wbWVudCBSb290
IENBMB4XDTI0MDkwMjExMzk0OVoXDTM0MDkwMjExMzk0OVowZjEdMBsGA1UEChMU
T3JiU3RhY2sgRGV2ZWxvcG1lbnQxHjAcBgNVBAsMFUNvbnRhaW5lcnMgJiBTZXJ2
aWNlczElMCMGA1UEAxMcT3JiU3RhY2sgRGV2ZWxvcG1lbnQgUm9vdCBDQTBZMBMG
ByqGSM49AgEGCCqGSM49AwEHA0IABFrmM3gOVztOpnefsAaNJzbPXsxXzsTJfPLL
yeL8hacyxShr02WabjDK9HyaB+GMdeN9LtnZ9JYbxYS3KOGfT1KjQjBAMA4GA1Ud
DwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRpuHCteDUvL/qn
JRSp5j5HYg/NZDAKBggqhkjOPQQDAgNIADBFAiEA58evAoQ/JkteyoXjDl6VNdp1
+0Bn71hT8PYix4r995QCIGq3KJqG2Z/pRMj4rQ2xCmM0GOudS47/7UASC+sB7yID
-----END CERTIFICATE-----

    ''
  ];
}

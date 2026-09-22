# Pinned container images for the smart-home stack.
#
# Every entry is "repo:tag@sha256:...". The tag is documentation; the digest is
# what docker actually resolves, so a moved tag can never change what runs here.
#
# Bumped automatically by Renovate (see renovate.json5). The "# renovate:" comment
# above each pin is what the custom manager matches on -- keep the shape:
#
#   # renovate: datasource=docker depName=<registry>/<repo>
#   <attr> = "<registry>/<repo>:<tag>@sha256:<digest>";
#
# To resolve a digest by hand:
#   skopeo inspect --format '{{.Digest}}' docker://<registry>/<repo>:<tag>
{
  # renovate: datasource=docker depName=ghcr.io/home-assistant/home-assistant
  homeassistant = "ghcr.io/home-assistant/home-assistant:2026.9.3@sha256:d8922685169707fd91e8b9729902d975f06157d005e422874d201e0261dda196";

  # renovate: datasource=docker depName=eclipse-mosquitto
  mosquitto = "eclipse-mosquitto:2.0.22@sha256:199ea8ef2e35ec2b1b37e59cfd1dbae538ed4dfa4a2251a121a52215a6248a21";

  # renovate: datasource=docker depName=ghcr.io/koenkk/zigbee2mqtt
  zigbee2mqtt = "ghcr.io/koenkk/zigbee2mqtt:2.14.1@sha256:fef0de769dcd04c27b3a6d277b61046eb96284bdd4198dcb1687c3a01b3020f3";

  # renovate: datasource=docker depName=nodered/node-red
  node-red = "nodered/node-red:4.1.15-22@sha256:7aa04e1c7be16aec5b4b4d6e64ae863c4720b0ab18e2c1f46905f7b0c71e3a19";

  # renovate: datasource=docker depName=ghcr.io/riddix/home-assistant-matter-hub
  home-assistant-matter-hub = "ghcr.io/riddix/home-assistant-matter-hub:2.0.57@sha256:3f63aca9cd94162c0736859b43949e95d164d2d47dbd1239574738e583c77661";
}

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
  mosquitto = "eclipse-mosquitto:2.0.22@sha256:09b62ff32c2e7b64d4b431b9a89236073289b68db273de2b089edeb9b0d92b5c";

  # renovate: datasource=docker depName=ghcr.io/koenkk/zigbee2mqtt
  zigbee2mqtt = "ghcr.io/koenkk/zigbee2mqtt:2.14.3@sha256:fb4a6b0f6868ad1cd6a9996479802b2420e599c3463b62bbff8c8cd9a908f43a";

  # renovate: datasource=docker depName=nodered/node-red
  node-red = "nodered/node-red:4.1.17-22@sha256:0993277cef34b251b87d9c05cce6af49a4f801be8781ff4c8a1962746471f8da";

  # renovate: datasource=docker depName=ghcr.io/riddix/home-assistant-matter-hub
  home-assistant-matter-hub = "ghcr.io/riddix/home-assistant-matter-hub:2.0.59@sha256:ef997a84c088ac89e57f9cde0fb6fd18447da0a3c8cc9466c4232ba5a15bd9d7";

  # renovate: datasource=docker depName=ghcr.io/matter-js/matterjs-server
  matter-server = "ghcr.io/matter-js/matterjs-server:1.5.5@sha256:ee149c7c67eff0e90f131e8f0d628f7b099591ec58473c8cda1209e8ae4df66e";

  # renovate: datasource=docker depName=rhasspy/wyoming-speech-to-phrase
  speech-to-phrase = "rhasspy/wyoming-speech-to-phrase:1.4.3@sha256:e532f0dbc6b21285c4c784212003865b9167041927328a767cb0beb1a0beaa20";

  # renovate: datasource=docker depName=ghcr.io/stanmart/overgang
  overgang = "ghcr.io/stanmart/overgang:0.1.2@sha256:edfc0a067f2026d8afe1740187f9b39a60cae3a506f23f81d3f6975b91b83b8b";
}

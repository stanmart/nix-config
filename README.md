# NixOS Multi-Host Configuration

Flake-based NixOS configuration supporting multiple hosts with clean system/user separation.

## Hosts

- **hetzner-cloud** — x86_64 server (Hetzner VM)
- **raspi-pihole** — aarch64 Raspberry Pi (Pi-hole + containers)
- **desktop** — x86_64 desktop machine (GNOME)

## Quick Start

### Deploy to Hetzner Cloud

1. **Create a VM** with cloud-init:
```bash
hcloud server create \
  --user-data-from-file cloud-init.yaml \
  --type cx23 \
  --location hel1 \
  --image ubuntu-24.04 \
  --name my-server
```

2. **Deploy NixOS**:
```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#hetzner-cloud \
  root@<vm-ip>
```

3. **Post-deployment** (on the server):
```bash
# Set up Tailscale
sudo tailscale up --auth-key=YOUR_KEY --ssh --advertise-exit-node

# Clone this repo for future updates
git clone https://github.com/stanmart/nix.git /home/stanmart/nixos
```

## Managing Systems

### Local Rebuild (on the target machine)
```bash
sudo nixos-rebuild switch --flake .#hetzner-cloud
```

### Remote Rebuild (from your local machine)
```bash
nixos-rebuild switch \
  --flake .#hetzner-cloud \
  --target-host stanmart@<ip> \
  --use-remote-sudo
```

## Structure

```
├── flake.nix              # Multi-host entry point
├── modules/base.nix       # Shared system config
├── hosts/
│   ├── hetzner-cloud/     # Server configuration
│   ├── raspi-pihole/      # Raspberry Pi configuration
│   └── desktop/           # Desktop configuration
└── home/stanmart/
    ├── common.nix         # Shared user config
    ├── hetzner.nix        # Server-specific user config
    ├── raspi.nix          # Pi-specific user config
    └── desktop.nix        # Desktop-specific user config
```

See [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for architectural details.

## What's Included

- **Base**: SSH, fail2ban, Tailscale, automatic garbage collection
- **Hetzner**: Docker, Caddy reverse proxy
- **Desktop**: GNOME, PipeWire, Docker
- **Raspberry Pi**: Podman (Pi-hole container coming later)
- **User Tools**: git, zsh, direnv, pixi, uv, bat, fzf, fd, delta

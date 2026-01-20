# NixOS Multi-Host Configuration

[![CI](https://github.com/stanmart/nix/actions/workflows/ci.yml/badge.svg)](https://github.com/stanmart/nix/actions/workflows/ci.yml)

Flake-based NixOS configuration supporting multiple hosts with clean system/user separation.

## Hosts

- **hetzner-cloud** — x86_64 server (Hetzner VM)
- **raspi-pihole** — aarch64 Raspberry Pi (Pi-hole + containers)
- **desktop** — x86_64 desktop machine (GNOME)
- **orbstack** — aarch64 local development VM (OrbStack on macOS)

## Quick Start

### Deploy to Hetzner Cloud

> [!TIP]
> A Hetzner snapshot with NixOS pre-configured may already exist for this setup. Check your Hetzner Cloud console for available snapshots before manually deploying. Using a snapshot is faster and skips the initial deployment steps.

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
  stanmart@<vm-ip>
```

3. **Post-deployment** (on the server):
```bash
# Set up Tailscale
sudo tailscale up --auth-key=YOUR_KEY --ssh --advertise-exit-node

# Clone this repo for future updates
git clone https://github.com/stanmart/nix.git
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
  --sudo
  --build-host stanmart@<ip>  # if different architecture
```

## Structure

```
├── flake.nix              # Multi-host entry point
├── modules/               # Shared system-level configurations
│   └── base.nix           # Auto-imported for all hosts via mkHost
│   └── ...                # Other capability modules (e.g., pihole)
├── hosts/                 # Per-host system configurations
└── home/stanmart/         # Home Manager user configurations
    └── common.nix         # Auto-imported for all hosts via mkHost
    └── ...                # Other capability modules (e.g., desktop)
```

See [`.github/copilot-instructions.md`](.github/copilot-instructions.md) for architectural details.

## What's Included

- **Base**: SSH, security (fail2ban), VPN (Tailscale), automatic cleanup
- **Hetzner**: Reverse proxy (Caddy), containers (Docker)
- **Desktop**: GUI (GNOME), graphics (AMD), gaming (Steam), audio (PipeWire)
- **Raspberry Pi**: DNS/DHCP server (Pi-hole)
- **User Environment**: Development tools, shell (zsh), version control (git), editors, CLI utilities

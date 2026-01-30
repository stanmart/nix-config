# NixOS Multi-Host Configuration

[![CI](https://github.com/stanmart/nix/actions/workflows/ci.yml/badge.svg)](https://github.com/stanmart/nix/actions/workflows/ci.yml)

Flake-based NixOS configuration supporting multiple hosts with clean system/user separation, plus standalone Home Manager for macOS.

## Structure

```
├── flake.nix              # Entry point: defines all hosts and home configs
├── modules/               # Shared system-level (NixOS) modules
│   ├── base.nix           # Auto-imported for all hosts (users, SSH, Tailscale)
│   ├── minimal.nix        # Minimal settings imported by base.nix
│   └── ...                # Other opt-in modules (onepassword, pihole, etc.)
├── hosts/                 # Per-host system configurations (one folder each)
└── home/stanmart/         # Home Manager user configurations
    ├── common.nix         # Auto-imported for all hosts (shell, git, SSH, GPG)
    ├── ...                # Other opt-in modules (desktop, dev-tools, etc.)
    └── assets/            # Static config files (p10k.zsh, Brewfile, etc.)
```

## Hosts

### NixOS Systems

| Host | Architecture | Description |
|------|--------------|-------------|
| **desktop** | x86_64 | Primary desktop machine with GNOME, AMD graphics, Steam, PipeWire audio |
| **raspi-pihole** | aarch64 | Raspberry Pi running Pi-hole for DNS/DHCP on home network |
| **orbstack** | aarch64 | Local development VM running in OrbStack on macOS |
| **hetzner** | x86_64 | Hetzner cloud server with Caddy reverse proxy and Docker |
| **aws** | x86_64 | AWS EC2 instance with Caddy reverse proxy and Docker |

### Home Manager Only

| Host | Architecture | Description |
|------|--------------|-------------|
| **qc-macbook** | aarch64-darwin | Work laptop (macOS) - user environment only, no NixOS |

## Managing Systems

### NixOS Hosts

**Local rebuild** (on the target machine):
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

**Remote rebuild** (from another machine):
```bash
nixos-rebuild switch \
  --flake .#<hostname> \
  --target-host stanmart@<ip> \
  --build-host stanmart@<ip> \
  --use-remote-sudo
```

### macOS Home Manager

On the macOS machine:
```bash
nix run home-manager -- switch --flake .#qc-macbook
```

## Automatic Updates

### NixOS Hosts

NixOS hosts use `system.autoUpgrade` via the `modules/auto-upgrade.nix` module. Updates check weekly (Mondays at 4 AM with up to 1 hour randomized delay) from `github:stanmart/nix-config`.

Configuration options per host:
```nix
stanmart-auto-upgrade = {
  allowReboot = true;   # Auto-reboot if needed (servers)
  operation = "switch"; # "switch" (immediate) or "boot" (next reboot)
};
```

Current configuration:
| Host | Auto Reboot | Operation |
|------|-------------|-----------|
| **raspi-pihole** | Yes | switch |
| **hetzner** | Yes | switch |
| **aws** | Yes | switch |
| **desktop** | No | switch |

### macOS Home Manager (qc-macbook)

macOS uses a launchd agent managed by home-manager (`home/stanmart/macos-auto-update.nix`). Updates run weekly on Mondays at 5 AM.

No manual setup needed - `home-manager switch` installs and loads the agent automatically.

**Logs:** `~/Library/Logs/nix-update.log` and `/tmp/nix-update-*.log`

## Deploying Cloud VMs

Both Hetzner and AWS configs use `nixos-anywhere` to deploy NixOS from any base Linux image.

### Hetzner

```bash
# Create VM (any Linux image works)
hcloud server create \
  --type cx22 \
  --location hel1 \
  --image ubuntu-24.04 \
  --name my-server

# Deploy NixOS
nixos-anywhere --flake .#hetzner root@<ip>
```

### AWS EC2

```bash
# Launch instance (any Linux AMI works), then deploy:
nixos-anywhere --flake .#aws root@<ip>
```

**Note:** Use Nitro-based instance types (T3, M5, M6, C5, C6, R5, R6, etc.). Older Xen instances (T2, M4) are not supported.

### Post-deployment (both providers)

```bash
sudo tailscale up --auth-key=YOUR_KEY --ssh --advertise-exit-node
```

## Architecture

### System vs Home Split

**System (NixOS)** handles:
- Boot, disks, hardware
- Networking, firewall
- System services (SSH, Tailscale, fail2ban, Docker)
- Users and groups

**Home (Home Manager)** handles:
- Shell configuration (zsh, prompt, aliases)
- Git, GPG, SSH client config
- Editors and CLI tools
- GUI applications
- Per-user services

### Module Composition

The `mkHost` helper in `flake.nix` automatically includes:
- `modules/base.nix` for all hosts
- `home/stanmart/common.nix` for the user

Per-host modules are added via `modules` and `homeModules` parameters:
```nix
desktop = mkHost {
  hostname = "desktop";
  system = "x86_64-linux";
  modules = [ ./hosts/desktop ];
  homeModules = [
    ./home/stanmart/desktop.nix
    ./home/stanmart/fancy-shell.nix
    ./home/stanmart/has-keys.nix
    ./home/stanmart/dev-tools.nix
  ];
};
```

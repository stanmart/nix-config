# NixOS Flake-Based Multi-Host Architecture

This document describes the architectural principles and long-term design patterns for maintaining the NixOS repository as a flake-based, multi-host setup with clear system vs Home Manager separation.

---

## Executive Summary

The repository uses a flake-based, multi-host architecture supporting:

- a Hetzner VM (server)
- a Raspberry Pi (Pi-hole + containers)
- a desktop (GUI, sometimes server-ish)

This structure provides:

- `flake.nix` as the entry point
- `hosts/<host>/default.nix` for system configuration
- `modules/*.nix` for shared system concerns
- `home/<user>/*.nix` for Home Manager, split into common + host-specific overlays

Secrets are explicitly out of scope for now.


---

## Target Directory Structure

```
.
├── flake.nix
├── flake.lock
│
├── modules/
│   ├── base.nix          # shared system defaults (users, nix, ssh, etc.)
│   ├── server.nix        # optional later: server-specific knobs
│   ├── desktop.nix       # optional later: GUI defaults
│   └── containers.nix    # optional later: podman/docker patterns
│
├── hosts/
│   ├── hetzner-cloud/
│   │   ├── default.nix   # migrated from old configuration.nix
│   │   └── disk-config.nix
│   │
│   ├── raspi-pihole/
│   │   └── default.nix   # aarch64, podman + pihole (initially minimal)
│   │
│   └── desktop/
│       └── default.nix   # GUI machine, sometimes server-ish
│
└── home/
    └── stanmart/
        ├── common.nix    # shared user environment
        ├── hetzner.nix   # server-specific user tweaks
        ├── raspi.nix     # minimal user env for Pi
        └── desktop.nix   # GUI apps, fonts, desktop tooling
```

---

## Design Principles

### 1. System vs Home Split

**System (NixOS):**
- bootloader, disks, hardware
- networking, firewall
- system services (ssh, tailscale, fail2ban, docker/podman)
- users and groups (but not dotfiles or shells)

**Home (Home Manager):**
- shell config (zsh)
- git config
- editors, CLI tools
- GUI applications
- per-user services

This optimizes:
- change velocity
- blast radius
- portability across machines

### 2. Same User, Different Hosts

The same user (`stanmart`) gets different Home Manager overlays per host:
- `common.nix` → everywhere
- `desktop.nix` → GUI-heavy
- `hetzner.nix` → server-lean
- `raspi.nix` → pihole plus a couple of containers

The flake wires this automatically based on host name.

---

## Long-term Maintenance Notes

- Keep changes incremental
- Prefer composition over conditionals
- Do not introduce secrets
- This architecture favors clarity and maintainability over cleverness

For active development and step-by-step execution instructions, see the migration plan.
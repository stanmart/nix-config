# NixOS Configuration Maintenance Guide

This document describes the conventions for maintaining this NixOS multi-host configuration repository.

For repository structure and host descriptions, see [README.md](../README.md).

## Key Concepts

### System vs Home Split

**System (NixOS modules):**
- Boot, disks, hardware configuration
- Networking, firewall rules
- System services (SSH, Tailscale, fail2ban, Docker)
- User accounts (but not dotfiles)

**Home (Home Manager modules):**
- Shell configuration (zsh, prompts, aliases)
- Git, GPG, SSH client settings
- Editors and CLI tools
- GUI applications
- Per-user services (gpg-agent)

### The mkHost Helper

Most hosts use `mkHost` in `flake.nix` which automatically:
1. Imports `modules/base.nix`
2. Sets up Home Manager with `home/stanmart/common.nix`
3. Allows additional modules via `modules` and `homeModules` parameters

Exception: `orbstack` defines its config inline because it imports OrbStack's generated configs from `/etc/nixos/`.

### Module Composition Pattern

Prefer small, focused modules over conditionals:
- `fancy-shell.nix` vs `simple-shell.nix` (not a single shell.nix with flags)
- `has-keys.nix` only on machines with GPG/SSH keys set up
- `desktop.nix` only on GUI machines

## Common Tasks

### Adding a Package

**System-wide:** Add to `modules/base.nix` or `modules/minimal.nix`
**User-level:** Add to `home/stanmart/common.nix` or a specific module
**Host-specific:** Add to the host's `default.nix` or a host-specific home module

### Adding a New Host

1. Create `hosts/<hostname>/default.nix`
2. Add to `nixosConfigurations` in `flake.nix` using `mkHost`
3. Specify appropriate `homeModules` for the use case

### Adding a New Home Module

1. Create `home/stanmart/<feature>.nix`
2. Add to relevant hosts' `homeModules` in `flake.nix`
3. Keep modules focused on a single capability

### Adding Static Config Files

Place in `home/stanmart/assets/` and reference with:
```nix
home.file."<destination>".source = ./assets/<filename>;
# or
xdg.configFile."<app>/config".source = ./assets/<filename>;
```

## Conventions

- **No secrets in the repo** - Use environment files or secret managers
- **Composition over conditionals** - Multiple small modules, not complex conditionals
- **Keep changes incremental** - Small, focused commits
- **Test builds before deploy** - `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`

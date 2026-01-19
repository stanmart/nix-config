# A set of minimal packages and settings
{ config, pkgs, ... }:

{
  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Base system packages
  environment.systemPackages = with pkgs; [
    curl
    git
    cloudflared
  ];

  # Enable zsh system-wide and set it as default shell
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Enable nix-ld for running dynamically linked binaries
  programs.nix-ld.enable = true;
}
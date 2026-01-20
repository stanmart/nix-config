# Some common toolchains for programming languages

{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # Basics
    gcc
    gnumake

    # Rust
    rustup  # let the user manage Rust toolchains

    # Python
    pixi
    uv

    # Misc
    cloc
    tlrc
    git-filter-repo
  ];

  # PATH additions
  home.sessionPath = lib.mkBefore [
    "$HOME/.pixi/bin"
    "$HOME/.cargo/bin"
  ];
}
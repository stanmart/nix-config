# Some common toolchains for programming languages

{ config, pkgs, ... }:

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
  ];

  # PATH additions
  home.sessionPath = [
    "$HOME/.pixi/bin"
    "$HOME/.cargo/bin"
  ];
}
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  NIX_CONFIG = "extra-experimental-features = nix-command flakes repl-flake";
  nativeBuildInputs = with pkgs; [
    git
    nixfmt
    nix-index
    hugo
    colmena
    niv
  ];
}

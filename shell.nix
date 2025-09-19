# https://unix.stackexchange.com/questions/741682/how-to-pin-a-package-version-with-nix-shell
# shell.nix
let
  pkgs_for_hugo = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/29dcf702b10d258b9bcd56bd38667c329614e128.tar.gz";
  }) {};
in

{ pkgs ? import <nixpkgs> {} }:
  pkgs.mkShell {
    # nativeBuildInputs is usually what you want -- tools you need to run
    nativeBuildInputs = with pkgs.buildPackages; [
      pkgs_for_hugo.hugo
    ];
}

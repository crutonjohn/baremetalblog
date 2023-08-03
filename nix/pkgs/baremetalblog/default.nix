{ stdenvNoCC, lib, fetchFromGitHub, git, hugo, sources ? import ../nix/sources.nix }:

let
  baremetalblog_src = sources.baremetalblog-src;
  nixpkgs =  import sources.nixpkgs {};
in
nixpkgs.stdenv.mkDerivation {
  pname = "baremetalblog";
  version = "custom";

  src = baremetalblog_src;

  strictDeps = true;

  buildInputs = [ git hugo ];

  buildPhase = ''
    rm -rf $src/public/*
    hugo --minify -t Blonde
  '';

  installPhase = ''
    cp -rv $src/public/* $out
  '';

  meta = with lib; {
    description = "A homelab and music focused blog.";
    homepage = "https://baremetalblog.com";
    platforms = platforms.linux;
  };
}

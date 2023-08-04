{ pkgs ? import <nixpkgs> { inherit system; }, sources ? import ../../../nix/sources.nix }:

let
  baremetalblog_src = sources.baremetalblog;
  blonde_src = sources.blonde;
  # pkgs =  import sources.nixpkgs {};
in
pkgs.stdenv.mkDerivation rec {
  pname = "baremetalblog";
  version = "custom";

  src = baremetalblog_src;

  strictDeps = true;

  nativeBuildInputs = with pkgs; [ 
    hugo 
    nodejs_20 
    nodePackages.postcss 
    nodePackages.postcss-cli 
    nodePackages.tailwindcss
    nodePackages_latest.concurrently
    nodePackages.autoprefixer
  ];

# ${pkgs.nodejs_20}/bin/
# ${pkgs.hugo}/bin/
    # npm cache clean --force
    # npm install --loglevel=verbose
    # npm i -D @fullhuman/postcss-purgecss postcss
  buildPhase = ''
    npm i -D @fullhuman/postcss-purgecss postcss
    hugo --minify -t Blonde
  '';

  installPhase = ''
    runHook preInstall

    cp -rv public/* $out

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "A homelab and music focused blog.";
    homepage = "https://baremetalblog.com";
    platforms = platforms.linux;
  };
}

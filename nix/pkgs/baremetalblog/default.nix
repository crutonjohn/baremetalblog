{
  pkgs ? import <nixpkgs> { inherit system; }, 
  system ? builtins.currentSystem, 
  nodejs ? pkgs."nodejs_20",
  sources ? import ../../../nix/sources.nix
}:

let
  nodeDependencies = (pkgs.callPackage ./node.nix {}).nodeDependencies;
  blonde_src = sources.Blonde;
in

pkgs.stdenv.mkDerivation {
  name = "baremetalblog";
  srcs = [
    ../../..
    blonde_src
  ];
  nativeBuildInputs = [nodejs pkgs.hugo];
  sourceRoot = "";
  buildPhase = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    mkdir -p $out

    ls -al ./

    hugo --minify -t Blonde

    cp -r public $out/

  '';
}
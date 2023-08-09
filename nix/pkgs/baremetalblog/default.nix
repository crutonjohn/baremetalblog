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
  src = ../../..;
  nativeBuildInputs = [nodejs pkgs.hugo];
  configurePhase = ''
    cp -r ${blonde_src} themes/Blonde
  '';
  buildPhase = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    mkdir -p $out

    hugo --minify -t Blonde

    cp -r public $out/

  '';
}
{
  pkgs ? import <nixpkgs> { inherit system; }, 
  system ? builtins.currentSystem, 
  nodejs ? pkgs."nodejs_20", 
  sources ? import ../../../nix/sources.nix
}:

let
  nodeDependencies = (pkgs.callPackage ./default.nix {}).nodeDependencies;
  baremetalblog_src = sources.baremetalblog;
in

pkgs.stdenv.mkDerivation {
  name = "baremetalblog";
  src = baremetalblog_src;
  nativeBuildInputs = [nodejs pkgs.hugo];
  buildPhase = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    ls -al

    mkdir -p $out

    npm run build

    cp -r public $out/

  '';
}
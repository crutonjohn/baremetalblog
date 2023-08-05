{
  pkgs ? import <nixpkgs> { inherit system; }, 
  system ? builtins.currentSystem, 
  nodejs ? pkgs."nodejs_20"
}:

let
  nodeDependencies = (pkgs.callPackage ./node.nix {}).nodeDependencies;
in

pkgs.stdenv.mkDerivation {
  name = "baremetalblog";
  src = ../../..;
  nativeBuildInputs = [nodejs pkgs.hugo];
  buildPhase = ''
    ln -s ${nodeDependencies}/lib/node_modules ./node_modules
    export PATH="${nodeDependencies}/bin:$PATH"

    ls -al ../

    mkdir -p $out

    npm run build

    cp -r public $out/

  '';
}
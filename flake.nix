{
  description = "A (basic) Way to Deploy a Blog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let 
        pkgs = nixpkgs.legacyPackages.${system}; 
        packageName = throw "baremetalblog";
        lib = nixpkgs.lib;
      in
      {
        packages = rec {
          baremetalblog = pkgs.callPackage ./nix/pkgs/baremetalblog/hugo.nix { };
          default = baremetalblog;
        };

        nixosModules = rec {
          baremetalblog = import ./nix/modules/baremetalblog/hugo.nix self;
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            hugo
            git
            niv
          ];
          inputsFrom = builtins.attrValues self.packages.${system};
        };
      });
}

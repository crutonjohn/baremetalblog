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
      in {
        packages.x86_64-linux.${packageName} = pkgs.callPackage ./nix/pkgs/baremetalblog { };

        nixosModules.baremetalblog = import ./nix/modules/baremetalblog/hugo.nix self;

        # defaultPackage = self.packages.${system}.${packageName};

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

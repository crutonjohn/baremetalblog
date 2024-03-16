{
  description = "A (basic) Way to Deploy a Blog";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    # submodule = {
    #   type = "git";
    #   url = "file://submodule";
    # };
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
          default = baremetalblog;
          # baremetalblog = pkgs.callPackage ./nix/pkgs/baremetalblog { };
          baremetalblog = pkgs.stdenv.mkDerivation {
            name = "baremetalblog";
            src = pkgs.fetchFromGitHub {
              owner = "crutonjohn";
              repo = "baremetalblog";
              rev = "f37d5da4a04181a9721f9179ec3bdd762c86a308";
              sha256 = "sha256-0S9lY0CXADtaGv8uyXEHRJicggCUxS3yo99IP3XqULY=";
              fetchSubmodules = true;
            };
            buildPhase = ''
              ls -al themes/hello-friend

              mkdir -p $out

              ${pkgs.hugo}/bin/hugo --minify --noBuildLock -t hello-friend -d $out/

            '';
          };
        };

        nixosModules = rec {
          baremetalblog = import ./nix/modules/baremetalblog self;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            nixfmt
            nix-index
            hugo
            nodejs_18
            node2nix
            act
          ];
          inputsFrom = builtins.attrValues self.packages.${system};
        };
      });
}

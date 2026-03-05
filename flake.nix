{
  description = "Experimental playground for content-addressed fetchers in Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        cafeteriaLib = import ./lib { inherit pkgs; };
        tests = import ./tests { inherit pkgs cafeteriaLib; };
      in
      {
        lib = cafeteriaLib;
        formatter = treefmtEval.config.build.wrapper;
        checks = {
          formatting = treefmtEval.config.build.check self;
          unit-tests =
            if tests == [ ] then
              pkgs.runCommand "unit-tests" { } "touch $out"
            else
              throw "Tests failed: ${builtins.toJSON (map (t: t.name) tests)}";
    ipfs-fetch-dagpb = cafeteriaLib.ipfs.fetchFromIpfs {
    ipfsCid = (import ./tests/constants.nix).cidDagPb;
    gateway = (import ./tests/constants.nix).gateway;
  };
            };
      }
    );
}

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
        fmtBuild = treefmtEval.config.build;
        cafeteriaLib = import ./lib { inherit pkgs; };
      in
      {
        lib = cafeteriaLib;
        formatter = fmtBuild.wrapper;
        checks = import ./checks.nix {
          inherit
            pkgs
            self
            cafeteriaLib
            fmtBuild
            ;
        };
      }
    );
}

{
  description = "Experimental playground for content-addressed fetchers in Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    yants = {
      url = "git+https://code.tvl.fyi/depot.git:/nix/yants.git";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
      yants,
    }:
    let
      modules = import ./modules;
    in
    {
      nixosModules.default = modules.nixos;
      homeModules.default = modules.homeManager;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        fmtBuild = treefmtEval.config.build;
        cafeteriaLib = import ./lib {
          inherit pkgs;
          yants = import yants { inherit (pkgs) lib; };
        };
      in
      {
        lib = cafeteriaLib;
        formatter = fmtBuild.wrapper;
        checks = import ./checks {
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

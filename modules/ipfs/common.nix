{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixpkgs.ipfs;
  cafeteriaLib =
    {
      pkgs,
      defaultGateway,
    }:
    import ../../lib { inherit pkgs defaultGateway; };
in
{
  options.nixpkgs.ipfs = {
    gateway = lib.mkOption {
      type = lib.types.str;
      default = "https://ipfs.io";
      description = "Default IPFS gateway URL used by nix-cafeteria fetchers.";
      example = "https://dweb.link";
    };
  };

  config.nixpkgs.overlays = [
    (
      final: prev:
      let
        cafeteria = cafeteriaLib {
          pkgs = prev;
          defaultGateway = cfg.gateway;
        };
      in
      {
        lib = prev.lib // {
          inherit (cafeteria) ipfs;
        };
      }
    )
  ];
}

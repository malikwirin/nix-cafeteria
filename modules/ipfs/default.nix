let
  common = {
    ipfs = ./common.nix;
  };
in
{
  nixos = common;
  homeManager = common;
}

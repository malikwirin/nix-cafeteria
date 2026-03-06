{ pkgs }:

let
  cid = import ./cid { inherit pkgs; };
  car = import ./car.nix { inherit pkgs; };
in
{
  inherit car cid;
  ipfs = import ./ipfs.nix { inherit pkgs cid car; };
}

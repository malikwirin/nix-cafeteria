{ pkgs }:

let
  cid = import ./cid { inherit pkgs; };
in
{
  inherit cid;
  ipfs = import ./ipfs.nix { inherit pkgs cid; };
}

{ pkgs }:

let
  encoding = import ./encoding.nix { };
  cid = import ./cid.nix { inherit pkgs encoding; };
in
{
  inherit encoding cid;
  ipfs = import ./ipfs.nix { inherit cid; };
}

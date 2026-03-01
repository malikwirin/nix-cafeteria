{ pkgs }:

let
  encoding = import ./encoding.nix { };
in
{
  inherit encoding;
  cid = import ./cid.nix { inherit pkgs encoding; };
}

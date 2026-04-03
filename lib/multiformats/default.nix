{ yants }:

let
  encoding = import ./encoding.nix { inherit yants; };
  cid = import ./cid { inherit encoding yants; };
in
{
  inherit cid encoding;
}

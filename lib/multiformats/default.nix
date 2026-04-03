{ yants }:

let
  cid = import ./cid { inherit encoding multicodec yants; };
  encoding = import ./encoding.nix { inherit yants; };
  multicodec = import ./multicodec.nix { inherit yants; };
in
{
  inherit cid encoding multicodec;
}

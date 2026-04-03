{ yants }:

let
  cid = import ./cid {
    inherit
      encoding
      multicodec
      multihash
      yants
      ;
  };
  encoding = import ./encoding.nix { inherit yants; };
  multicodec = import ./multicodec.nix { inherit yants; };
  multihash = import ./multihash.nix { inherit encoding yants; };
in
{
  inherit
    cid
    encoding
    multicodec
    multihash
    ;
}

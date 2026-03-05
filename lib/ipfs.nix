{ cid }:

let
  stripTrailingSlash =
    s:
    let
      len = builtins.stringLength s;
    in
    if len > 0 && builtins.substring (len - 1) 1 s == "/" then builtins.substring 0 (len - 1) s else s;
in
{
  /*
    Returns the IPFS gateway URL for a given CID.
    Validates the CID and strips trailing slashes from the gateway address.

    Example:
      gatewayUrl "https://ipfs.io" "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "https://ipfs.io/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
  */
  gatewayUrl =
    gateway: cidStr:
    let
      _ = cid.cidVersion cidStr; # validates CID, throws on invalid
    in
    "${stripTrailingSlash gateway}/ipfs/${cidStr}";
}

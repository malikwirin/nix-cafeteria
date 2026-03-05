{ pkgs, cid }:

let
  stripTrailingSlash =
    s:
    let
      len = builtins.stringLength s;
    in
    if len > 0 && builtins.substring (len - 1) 1 s == "/" then builtins.substring 0 (len - 1) s else s;

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
      valid = if !(cid.cidValid cidStr) then throw "Invalid CID: ${cidStr}" else true;
    in
    builtins.seq valid "${stripTrailingSlash gateway}/ipfs/${cidStr}";
in
{
  inherit gatewayUrl;

  # FIXME: not tested positively yet
  fetchFromIpfs =
    {
      ipfsCid,
      gateway ? "https://ipfs.io",
    }:
    pkgs.fetchurl {
      url = gatewayUrl gateway ipfsCid;
      hash = cid.cidDigest ipfsCid;
    };

  # FIXME: not tested positively yet
  fetchFromIpfsCar =
    {
      carCid,
      blockCid,
      gateway ? "https://ipfs.io",
    }:
    pkgs.fetchzip {
      url = gatewayUrl gateway carCid;
      hash = cid.cidDigest carCid;
      postFetch = ''
        ${pkgs.go-car}/bin/car extract $out --block ${blockCid} > $out
        rm -rf $out/.car
      '';
    };

}

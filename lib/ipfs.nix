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

  /*
      Fetches a file from an IPFS gateway using a CIDv1.

      Supported codecs:
        - raw:    Hash is derived from the CID automatically.
                  The `hash` parameter is ignored.
        - dag-pb: The gateway returns decoded UnixFS content whose hash
                  cannot be derived from the CID. The `hash` parameter
                  is required and must be a Nix SRI string
                  (e.g. "sha256-..."). Use `nix-prefetch-url` to obtain it.

      Throws if:
        - the CID is invalid
        - the codec is unsupported
        - dag-pb is used without an explicit hash

      Examples:
        fetchFromIpfs {
          ipfsCid = "bafkreigsvbhuxc3fbe36zd3tzwf6fr2k3vnjcg5gjxzhiwhnqiu5vackey";
        }
        => «derivation ...»

        fetchFromIpfs {
          ipfsCid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
          hash = "sha256-...";
        }
        => «derivation ...»
  */
  fetchFromIpfs =
    {
      ipfsCid,
      hash ? null,
      gateway ? "https://ipfs.io",
    }:
    let
      codec = cid.cidCodec ipfsCid;
      fetch =
        hash:
        pkgs.fetchurl {
          url = gatewayUrl gateway ipfsCid;
          inherit hash;
        };
    in
    if codec == "raw" then
      fetch (cid.cidDigest ipfsCid)
    else if codec == "dag-pb" then
      if hash == null then throw "fetchFromIpfs requires explicit hash for dag-pb CIDs" else fetch hash
    else
      throw "fetchFromIpfs unsupported codec: ${codec}";

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

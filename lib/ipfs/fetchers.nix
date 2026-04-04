{
  pkgs,
  ipfsBlock,
  multiformats,
  yants,
}:

let
  inherit (ipfsBlock) block dagPbFileBlock getDagPbFileHash;
  inherit (yants)
    defun
    drv
    string
    function
    ;
  inherit (multiformats) multicodec;
  inherit (multicodec) codecName;
  url = string; # FIXME;
  stripTrailingSlash = defun [ string string ] (
    s:
    let
      len = builtins.stringLength s;
    in
    if len > 0 && builtins.substring (len - 1) 1 s == "/" then builtins.substring 0 (len - 1) s else s
  );

  blockFetcher = function; # (block gateway -> derivation) FIXME: enforce signature

  /*
    Returns the IPFS gateway URL for a given CID.

    Example:
      gatewayUrl "https://ipfs.io" "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "https://ipfs.io/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
  */
  gatewayUrl = defun [ url string url ] (
    gateway: suffix: "${stripTrailingSlash gateway}/ipfs/${suffix}"
  );

  /*
    Fetcher for identity blocks. Returns the CID hash directly —
    the content is embedded in the CID itself.
  */
  identityFetcher = defun [
    block # accepts all kinds of blocks
    url
    drv
  ] (b: _: b.cid.hash);

  /*
    Fetcher for raw blocks. Fetches the block bytes directly from
    the gateway using the CID hash as content hash.
  */
  rawFetcher =
    defun
      [
        block # accepts all kinds of blocks
        url
        drv
      ]
      (
        b: gateway:
        pkgs.fetchurl {
          inherit (b.cid) hash;
          url = gatewayUrl gateway b.cid.cidStr;
        }
      );

  /*
    Fetcher for dag-pb file blocks. Fetches a specific file from a
    UnixFS DAG-PB tree. Requires b.path to be set and b.hash to be
    the content hash of the target file (not the CID hash).
  */
  dagPbFileFetcher = defun [ dagPbFileBlock url drv ] (
    b: gateway:
    pkgs.fetchurl {
      url = gatewayUrl gateway "${b.cid.cidStr}/${b.path}";
      hash = getDagPbFileHash b gateway;
    }
  );

  nameToFetcher = {
    "identity" = identityFetcher;
    "raw" = rawFetcher;
    "dag-pb" = dagPbFileFetcher;
  };

in
{
  inherit
    blockFetcher
    gatewayUrl
    rawFetcher
    url
    ;
  /*
    Returns the codec-specific fetcher function for a given codec name.
    Throws if the codec has no registered fetcher.
  */
  getFetcher = defun [ codecName blockFetcher ] (
    codec: nameToFetcher."${codec}" or (throw "Unsupported codec: ${codec}")
  );
}

{
  pkgs,
  car,
  cid,
  defaultGateway,
  yants,
}:

let
  inherit (cid)
    asCid
    cidStringType
    ;
  inherit (yants) defun string;

  stripTrailingSlash =
    s:
    let
      len = builtins.stringLength s;
    in
    if len > 0 && builtins.substring (len - 1) 1 s == "/" then builtins.substring 0 (len - 1) s else s;

  /*
    Returns the IPFS gateway URL for a given CID.

    Example:
      gatewayUrl "https://ipfs.io" "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "https://ipfs.io/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
  */
  gatewayUrl = defun [ string cidStringType string ] (
    gateway: cidStr: "${stripTrailingSlash gateway}/ipfs/${cidStr}"
  );

  /*
    Fetches a file from an IPFS gateway using a CIDv1.
    Accepts both CID strings and parsed cidType attrsets.

    Supported codecs:
      - raw:    Hash is derived automatically from the CID multihash.
      - dag-pb: Requires an explicit `hash` argument.

    Arguments:
      ipfsCid  - CID string or cidType attrset. Defaults to cid.parseHash hash
                 if only `hash` is provided.
      hash     - Nix SRI hash string. Required for dag-pb. Ignored for raw.
      gateway  - IPFS gateway URL (default: defaultGateway)
      asRaw    - Treat as raw codec regardless of actual codec (default: false)

    Examples:
      fetchFromIpfs {
        ipfsCid = "bafkreigsvbhuxc3fbe36zd3tzwf6fr2k3vnjcg5gjxzhiwhnqiu5vackey";
      }
      => «derivation»

      fetchFromIpfs {
        hash = "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=";
      }
      => «derivation»
  */
  fetchFromIpfs =
    {
      hash ? null,
      ipfsCid ? cid.parseHash hash, # already returns cidType
      gateway ? defaultGateway,
      asRaw ? false,
    }:
    # ipfsCid is cidType — no isCid branch needed
    let
      parsed = asCid ipfsCid;
      codec = parsed.codec;
      fetch =
        hash:
        pkgs.fetchurl {
          inherit hash;
          url = gatewayUrl gateway parsed.cidStr;
        };
    in
    if codec == "raw" || asRaw then
      fetch parsed.hash
    else if codec == "dag-pb" then
      if hash == null then
        throw "fetchFromIpfs currently does not support the actual files of dag-pb CIDs"
      else
        fetch hash
    else
      throw "fetchFromIpfs unsupported codec: ${codec}";
in
{
  inherit gatewayUrl fetchFromIpfs;

  /*
    Fetches a CAR file from an IPFS gateway and returns all contained blocks
    as an attrset keyed by CID string.
    Accepts both CID strings and parsed cidType attrsets.

    Raw blocks are fetched directly (hash is derivable from the CID multihash).
    Non-raw blocks are extracted from the downloaded CAR file.
    The root CID is excluded from the result.

    Requires IFD (import-from-derivation).

    Arguments:
      carCid  - CID string or cidType attrset of the CAR file
      gateway - IPFS gateway URL (default: defaultGateway)

    Returns:
      An attrset mapping each child CID string to its derivation:
      {
        "bafkrei..." = «derivation»;  # raw, fetched directly
        "bafybei..." = «derivation»;  # non-raw, extracted from CAR
      }

    Example:
      fetchCarBlocks {
        carCid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
      }
  */
  fetchCarBlocks = # TODO: add typing with carCid as (either cidType string)
    {
      carCid,
      gateway ? defaultGateway,
    }:
    let
      parsed = asCid carCid;
      carFile = pkgs.fetchurl {
        inherit (parsed) hash;
        url = gatewayUrl gateway parsed.cidStr;
      };
      allCids = car.carCidStrings carFile;
      childCids = builtins.filter (c: c != parsed.cidStr) allCids;
      fetchBlock =
        cidStr:
        let
          blockParsed = cid.parseCid cidStr;
        in
        if blockParsed.codec == "raw" then
          fetchFromIpfs {
            ipfsCid = blockParsed;
            inherit gateway;
          }
        else
          car.carExtract {
            inherit carFile;
            blockCid = cidStr;
          };
    in
    builtins.listToAttrs (
      builtins.map (cidStr: {
        name = cidStr;
        value = fetchBlock cidStr;
      }) childCids
    );

  /*
    Fetches a CAR file from an IPFS gateway and optionally extracts a specific block.
    Accepts both CID strings and parsed cidType attrsets.

    Arguments:
      carCid   - CID string or cidType attrset of the CAR file
      blockCid - CID string of the block to extract from the CAR (optional)
      gateway  - IPFS gateway URL (default: defaultGateway)

    Returns:
      A derivation containing the CAR file, or the extracted block if blockCid is given.
  */
  fetchFromIpfsCar =
    {
      carCid,
      blockCid ? null,
      gateway ? defaultGateway,
    }:
    let
      parsed = asCid carCid;
    in
    pkgs.fetchzip (
      {
        inherit (parsed) hash;
        url = gatewayUrl gateway parsed.cidStr;
      }
      // (pkgs.lib.optionalAttrs (blockCid != null) {
        postFetch = ''
          ${car.carExtract { inherit blockCid; }}
          rm -rf $out/.car
        '';
      })
    );
}

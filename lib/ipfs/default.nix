{
  pkgs,
  car,
  defaultGateway,
  multiformats,
  yants,
}:

let
  ipfsBlock = import ./block.nix { inherit multiformats yants; };
  inherit (ipfsBlock)
    block
    blockFetcher
    dagPbFileBlock
    getDagPbFileHash
    ;
  inherit (multiformats) cid encoding multicodec;
  inherit (multicodec) codecName;
  inherit (cid)
    asCid
    cidStringType
    cidType
    ;
  inherit (encoding) sriHash;
  inherit (yants)
    attrs
    defun
    drv
    string
    option
    struct
    either
    bool
    ;

  stripTrailingSlash = defun [ string string ] (
    s:
    let
      len = builtins.stringLength s;
    in
    if len > 0 && builtins.substring (len - 1) 1 s == "/" then builtins.substring 0 (len - 1) s else s
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
      hash = getDagPbFileHash b;
    }
  );

  nameToFetcher = {
    "identity" = identityFetcher;
    "raw" = rawFetcher;
    "dag-pb" = dagPbFileFetcher;
  };

  /*
    Returns the codec-specific fetcher function for a given codec name.
    Throws if the codec has no registered fetcher.
  */
  getFetcher = defun [ codecName blockFetcher ] (
    codec: nameToFetcher."${codec}" or (throw "Unsupported codec: ${codec}")
  );

  /*
    Constructs a minimal block attrset from a parsed CID.
    Sets path = null and hash = cid.hash as defaults.
    Use mkBlock to override path and hash.
  */
  mkBaseBlock = defun [ cidType block ] (cid: {
    inherit cid;
    fetcher = getFetcher cid.codec;
    path = null;
  });

  /*
    Constructs a full block attrset from a CID with optional path and hash overrides.
    For dag-pb blocks without path: uses rawFetcher (fetches protobuf blob).
    For dag-pb blocks with path: uses dagPbFileFetcher (fetches file from UnixFS tree).
  */
  mkBlock =
    defun
      [
        (struct "mkBlockArgs" {
          cid = cidType;
          path = option string;
        })
        block
      ]
      (
        {
          cid,
          path ? null,
        }:
        let
          base = mkBaseBlock cid;
        in
        base
        // pkgs.lib.optionalAttrs (path != null) {
          inherit path;
        }
        // pkgs.lib.optionalAttrs (base.cid.codec == "dag-pb" && path == null) {
          fetcher = rawFetcher;
        }
      );

  url = string; # FIXME;

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
    Fetches a file from an IPFS gateway using a CIDv1.
    Accepts both CID strings and parsed cidType attrsets.
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
    defun
      [
        (struct "fetchFromIpfsArgs" {
          hash = option sriHash;
          ipfsCid = option (either cidStringType cidType);
          gateway = option url;
          asRaw = option bool; # TODO: replace with enum codec override
          path = option string;
        })
        drv
      ]
      (
        {
          hash ? null,
          ipfsCid ? cid.parseHash hash, # already returns cidType
          gateway ? defaultGateway,
          asRaw ? false,
          path ? null,
        }:
        # ipfsCid is cidType — no isCid branch needed
        let
          parsed = asCid ipfsCid;
          block = mkBlock {
            cid = parsed;
            inherit path;
          };
        in
        if asRaw then rawFetcher block else block.fetcher block gateway
      );
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
  fetchCarBlocks =
    defun
      [
        (struct "fetchCarBlocksArgs" {
          carCid = either cidStringType cidType;
          gateway = option url;
        })
        (attrs drv) # { "bafkrei..." = derivation; ... }
      ]
      (
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
        )
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
    defun
      [
        (struct "fetchFromIpfsCarArgs" {
          carCid = either cidStringType cidType;
          blockCid = option cidStringType;
          gateway = option url;
        })
        drv
      ]
      (
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
        )
      );
}

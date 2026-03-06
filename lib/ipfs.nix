{
  pkgs,
  car,
  cid,
}:

let
  inherit (cid) encoding;
  inherit (encoding) sriHashNames base64Encode;

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

  /*
    Computes a Nix SRI hash string from a parsed multihash attribute set.
    Maps the multihash function name to the SRI algorithm identifier
    and base64-encodes the digest bytes.

    Arguments:
      multihash - A multihash attribute set (as found in a parsed CID's
                  `multihash` field). Must contain:
                    fn     - Hash function set with `name` (string)
                    digest - List of byte values (list of integers)

    Returns:
      A Nix SRI hash string (e.g. "sha256-w8RzPsiv/QbPnp/1D/...=").

    Throws if no SRI name mapping exists for the hash function.

    Example:
      cidDigestFromMultihash {
        fn = { name = "sha2-256"; code = 18; };
        digest = [ 195 196 115 62 ... ];
      }
      => "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
  */
  cidDigestFromMultihash =
    multihash:
    let
      inherit (multihash) fn digest;
      hashName = sriHashNames."${fn.name}";
    in
    "${hashName}-${base64Encode digest}";

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
      hash ? null,
      ipfsCid ? cid.parseHash hash,
      gateway ? "https://ipfs.io",
    }:
    let
      parsed = if cid.isCid ipfsCid then ipfsCid else cid.parseCid ipfsCid;
      codec = parsed.codec;
      fetch =
        hash:
        pkgs.fetchurl {
          url = gatewayUrl gateway ipfsCid;
          inherit hash;
        };
    in
    if codec == "raw" then
      fetch (cidDigestFromMultihash parsed.multihash)
    else if codec == "dag-pb" then
      if hash == null then throw "fetchFromIpfs requires explicit hash for dag-pb CIDs" else fetch hash
    else
      throw "fetchFromIpfs unsupported codec: ${codec}";
in
{
  inherit gatewayUrl fetchFromIpfs;

  /*
    Fetches a CAR file from an IPFS gateway and makes all contained
    blocks available as an attrset keyed by CID string.

    - raw blocks are fetched directly via fetchFromIpfs (hash is
      derivable from the CID, no CAR extraction needed)
    - non-raw blocks (dag-pb, dag-cbor, ...) are extracted from the
      downloaded CAR file

    The root CID is excluded from the result.

    Requires IFD (import-from-derivation).

    Arguments:
      carCid  - CID of the CAR file (string or parsed CID)
      gateway - IPFS gateway URL (default: "https://ipfs.io")

    Returns:
      An attribute set mapping each child CID string to its derivation:
      {
        "bafkrei..." = «derivation»;  # raw, fetched directly
        "bafybei..." = «derivation»;  # dag-pb, extracted from CAR
      }

    Example:
      blocks = fetchCarBlocks {
        carCid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
      };
  */
  fetchCarBlocks =
    {
      carCid,
      gateway ? "https://ipfs.io",
    }:
    let
      carCidStr = if cid.isCid carCid then carCid.cidStr else carCid;
      parsed = if cid.isCid carCid then carCid else cid.parseCid carCid;
      carHash = cidDigestFromMultihash parsed.multihash;

      carFile = pkgs.fetchurl {
        url = gatewayUrl gateway carCidStr;
        hash = carHash;
      };

      allCids = car.carCidStrings carFile;

      # remove root CID
      childCids = builtins.filter (c: c != carCidStr) allCids;

      fetchBlock =
        cidStr:
        let
          blockParsed = cid.parseCid cidStr;
          codec = blockParsed.codec;
        in
        if codec == "raw" then
          fetchFromIpfs {
            ipfsCid = cidStr;
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
    Fetches a CAR file from an IPFS gateway and extracts a specific block.

    Arguments:
      carCid   - CID of the CAR file (string or parsed CID)
      blockCid - CID of the block to extract from the CAR
      gateway  - IPFS gateway URL (default: "https://ipfs.io")

    Returns:
      A derivation containing the extracted block.
  */
  fetchFromIpfsCar =
    {
      carCid,
      blockCid ? null,
      gateway ? "https://ipfs.io",
    }:
    let
      parsed = if cid.isCid carCid then carCid else (cid.parseCid carCid);
      carHash = cidDigestFromMultihash parsed.multihash;
    in
    pkgs.fetchzip (
      {
        url = gatewayUrl gateway carCid;
        hash = carHash;
      }
      // (pkgs.lib.optionalAttrs (blockCid != null) {
        postFetch = ''
          ${car.carExtract { inherit blockCid; }}
          rm -rf $out/.car
        '';
      })
    );
}

{ pkgs }:

let
  encoding = import ./encoding.nix;
  inherit (encoding)
    base32Byte
    base64Encode
    sriHashNames
    hexToBytes
    base32Encode
    isSha256
    ;
  minLength = 10;

  # Returns true if the CID string meets the minimum length requirement.
  isValidLength = cid: builtins.stringLength cid >= minLength;
  # Returns true if the CID string is valid (currently just checks length and multibase prefix).
  cidValid = cid: isValidLength cid && builtins.substring 0 1 cid == "b";

  # Maps multihash function codes (as decimal strings) to their canonical names.
  hashFunctionNames = {
    "18" = "sha2-256"; # 0x12
  };

  /*
    Extracts the CID version byte from a base32-encoded CID body
    (i.e. the CID string with the multibase prefix removed).
  */
  cidVersionFromBase32 = code: base32Byte code 0;

  # Maps multicodec codes (as decimal strings) to their canonical names.
  codecNames = {
    "85" = "raw"; # 0x55
    "112" = "dag-pb"; # 0x70
    "113" = "dag-cbor"; # 0x71
    "297" = "dag-json"; # 0x0129
  };

  /*
      Returns the version number of a CIDv1 string as an integer.
      Only base32-encoded CIDs (multibase prefix 'b') are supported.
      Throws if the CID is too short, uses an unsupported multibase, or is malformed.

      Example:
        cidVersion "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        => 1
  */
  cidVersion =
    cid:
    if !(cidValid cid) then
      throw "Invalid CID"
    else
      cidVersionFromBase32 (builtins.substring 1 (-1) cid);

  /*
    Extracts the hash function from a base32-decoded CID body.
    Returns an attribute set with the canonical name and numeric multihash code.
    Throws if the hash function code is not supported.

    Arguments:
      body - The CID body string (without multibase prefix).

    Returns:
      An attribute set with:
        name - Canonical hash function name (string, e.g. "sha2-256")
        code - Numeric multihash function code (integer, e.g. 18)

    Example:
      hashFunction "afybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => { name = "sha2-256"; code = 18; }
  */
  hashFunction =
    body:
    let
      code = base32Byte body 2;
    in
    if hashFunctionNames ? ${toString code} then
      {
        name = hashFunctionNames.${toString code};
        inherit code;
      }
    else
      throw "Unsupported hash function code: ${toString code}";

  /*
      Returns the name of the hash function used in a CIDv1 string.
      Only base32-encoded CIDv1 with sha2-256 multihash is supported.
      Throws if the CID is too short, uses an unsupported multibase,
      has an unsupported version, or uses an unsupported hash function.

      Example:
        cidHashFunction "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        => { name = "sha2-256"; code = "18"; }
  */
  cidHashFunction =
    cid:
    if !(cidValid cid) then
      throw "Invalid CID"
    else
      let
        body = builtins.substring 1 (-1) cid;
        version = base32Byte body 0;
      in
      if version != 1 then throw "Unsupported CID version: ${toString version}" else hashFunction body;

  /*
    Returns true if the given value is a multihash attribute set
    (i.e. has `_type = "cid.multihash"`).

    Example:
      isMultihash { _type = "cid.multihash"; fn = { ... }; len = 32; digest = [ ... ]; }
      => true
      isMultihash { foo = 1; }
      => false
  */
  isMultihash = x: x ? _type && x._type == "cid.multihash";

  /*
    Creates a structured CID attribute set from its components.
    This is an internal constructor — use `parseCid` to create
    a CID value from a base32-encoded CID string.

    Arguments:
      version   - CID version number (integer, e.g. 1)
      codec     - Multicodec name (string, e.g. "dag-pb", "raw")
      multihash - Attribute set with:
                    fn     - Hash function name (string, e.g. "sha2-256")
                    code   - Multihash function code (integer, e.g. 18)
                    len    - Digest length in bytes (integer)
                    digest - List of byte values (list of integers)

    Returns:
      An attribute set with `_type = "cid"` and the given fields.

    Example:
      mkCid {
        version = 1;
        codec = "raw";
        multihash = { fn = "sha2-256"; code = 18; len = 32; digest = [ ... ]; };
      }
      => { _type = "cid"; version = 1; codec = "raw"; multihash = { ... }; }
  */
  mkCid =
    {
      version,
      codec,
      multihash,
    }:
    assert isMultihash multihash;
    {
      _type = "cid";
      inherit version codec multihash;
    };

  /*
    Returns the name of the multicodec used in a CIDv1 string.
    Only base32-encoded CIDv1 is supported.
    Throws if the CID is invalid, has an unsupported version,
    or uses an unsupported codec.

    Example:
      cidCodec "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "dag-pb"
  */
  cidCodec =
    cid:
    if !(cidValid cid) then
      throw "Invalid CID"
    else
      let
        body = builtins.substring 1 (-1) cid;
        version = cidVersion cid;
        codecCode = base32Byte body 1;
      in
      if version != 1 then
        throw "Unsupported CID version: ${toString version}"
      else if codecNames ? ${toString codecCode} then
        codecNames.${toString codecCode}
      else
        throw "Unsupported codec code: ${toString codecCode}";

  /*
    Extracts the multihash from a base32-decoded CID body and returns
    it as a structured attribute set. Reads the hash function, digest
    length, and digest bytes from the binary CID layout.

    Arguments:
      body - The CID body string (without multibase prefix).

    Returns:
      An attribute set with:
        _type  - "cid.multihash"
        fn     - Hash function attribute set (as returned by `hashFunction`)
        len    - Digest length in bytes (integer)
        digest - List of byte values (list of integers)

    Example:
      mkMultihash "afybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => {
        _type = "cid.multihash";
        fn = { name = "sha2-256"; code = 18; };
        len = 32;
        digest = [ 195 196 115 62 ... ];
      }
  */
  mkMultihash =
    body:
    let
      digestLen = base32Byte body 3;
      digestBytes = builtins.genList (i: base32Byte body (4 + i)) digestLen;
    in
    {
      _type = "cid.multihash";
      fn = hashFunction body;
      len = digestLen;
      digest = digestBytes;
    };

  /*
    Constructs a base32-encoded CIDv1 string for a raw block from a SHA-256 SRI hash.
    Uses CIDv1 with codec "raw" (0x55) and multihash sha2-256 (0x12).

    Arguments:
      sha256 - A SHA-256 hash in SRI format (e.g. "sha256-w8RzPs...").

    Returns:
      A base32-encoded CIDv1 string with multibase prefix 'b'.

    Example:
      cidFromSha256 "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
      => "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
  */
  cidFromSha256 =
    sha256:
    let
      hex = builtins.convertHash {
        hash = sha256;
        hashAlgo = "sha256";
        toHashFormat = "base16";
      };
      # 01 = CIDv1, 55 = raw, 12 = sha2-256, 20 = 32 bytes
      prefix = "01551220";
      cidBytes = hexToBytes "${prefix}${hex}";
    in
    # b = multibase
    "b${base32Encode cidBytes}";

  /*
    Parses a base32-encoded CIDv1 string into a structured CID attribute set.
    Only CIDs with multibase prefix 'b' (base32lower) are supported.
    Throws if the CID is invalid, uses an unsupported version, codec, or hash function.

    Arguments:
      cidStr - A base32-encoded CIDv1 string (e.g. "bafybeig...").

    Returns:
      An attribute set with:
        _type     - "cid"
        version   - CID version (integer)
        codec     - Multicodec name (string)
        multihash - Attribute set with fn, code, len, digest

    Example:
      parseCid "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => {
        _type = "cid";
        version = 1;
        codec = "dag-pb";
        multihash = {
          fn = "sha2-256";
          code = 18;
          len = 32;
          digest = [ 195 196 115 62 ... ];
        };
      }
  */
  parseCid =
    cidStr:
    if !(cidValid cidStr) then
      throw "parseCid: invalid or unsupported CID string: ${builtins.substring 0 20 (toString cidStr)}"
    else
      let
        version = cidVersion cidStr;
        codec = cidCodec cidStr;
      in
      mkCid {
        inherit version codec;
        multihash = mkMultihash (builtins.substring 1 (-1) cidStr);
      };

  cidFromSha =
    hash:
    let
      converter =
        if isSha256 hash then
          hash: (cidFromSha256 hash)
        else
          throw "cidFromSha: expected a SHA-256 SRI hash string, got: ${toString hash}";
    in
    converter hash;
in
{
  inherit
    cidVersion
    cidHashFunction
    cidValid
    encoding
    cidCodec
    parseCid
    ;

  /*
    Constructs a structured CIDv1 attribute set for a raw block
    from a SHA-256 hash in SRI format.

    This is a convenience constructor for the common case of
    content-addressed raw blocks. The resulting CID uses
    CIDv1 with codec "raw" (0x55) and multihash sha2-256 (0x12).

    Arguments:
      hash - A SHA-256 hash in SRI format (e.g. "sha256-w8RzPs...").

    Returns:
      A structured CID attribute set ({ _type = "cid"; ... }).

    Example:
      parseHash "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
      => {
        _type = "cid";
        version = 1;
        codec = "raw";
        multihash = {
          _type = "cid.multihash";
          fn = { name = "sha2-256"; code = 18; };
          len = 32;
          digest = [ ... ];
        };
      }
  */
  parseHash = hash: parseCid (cidFromSha hash);

  /*
    Returns true if the given value is a parsed CID attribute set
    (i.e. created by `mkCid` or `parseCid`).

    Example:
      isCid (parseCid "bafybeig...")  => true
      isCid "bafybeig..."            => false
      isCid { foo = 1; }             => false
  */
  isCid = x: x ? _type && x._type == "cid";

  /*
    Extracts the raw digest from a CIDv1 string and returns it as a Nix SRI hash string.
    Only base32-encoded CIDv1 with sha2-256 multihash is supported.
    Throws if the CID is too short, uses an unsupported multibase,
    has an unsupported version, or uses an unsupported hash function.

    Example:
      cidDigest "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
  */
  cidDigest =
    cid:
    let
      hashFn = cidHashFunction cid; # validates version, multibase, hash fn
      body = builtins.substring 1 (-1) cid;
      digestLen = base32Byte body 3;
      digestBytes = builtins.genList (i: base32Byte body (4 + i)) digestLen;
      sriName =
        if sriHashNames ? ${hashFn.name} then
          sriHashNames.${hashFn.name}
        else
          throw "No SRI name for ${hashFn.name}";
    in
    "${sriName}-${base64Encode digestBytes}";
}

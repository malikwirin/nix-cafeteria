{ yants }:

let
  encoding = import ./encoding.nix { inherit yants; };
  inherit (encoding)
    base32Byte
    base64Encode
    byte
    sha256Hash
    sriHash
    sriHashAlgo
    sriHashNames
    hexToBytes
    base32Encode
    ;
  inherit (yants)
    bool
    defun
    either
    int
    list
    restrict
    struct
    string
    ;

  minLength = 10; # FIXME: currently arbitrary

  # Returns true if the CID string meets the minimum length requirement.
  isValidLength = defun [ string bool ] (cid: builtins.stringLength cid >= minLength);
  # Returns true if the CID string is valid (currently just checks length and multibase prefix).
  cidValid = defun [ string bool ] (cid: isValidLength cid && builtins.substring 0 1 cid == "b");

  # Maps multihash function codes (as decimal strings) to their canonical names.
  hashFunctionNames = {
    "18" = "sha2-256"; # 0x12
  };

  hashFunctionCode = restrict "hashFunctionCode" (v: hashFunctionNames ? ${toString v}) int;
  hashFunctionName = restrict "hashFunctionName" (
    v: builtins.elem v (builtins.attrValues hashFunctionNames)
  ) string;

  cidVersionType = restrict "cidVersion" (v: v == 0 || v == 1) int;

  hashFnType = struct "hashFn" {
    name = hashFunctionName; # e.g. "sha2-256"
    code = hashFunctionCode; # e.g. 18
  };

  multihashType = struct "multihash" {
    fn = hashFnType;
    len = int; # digest length in bytes
    digest = list byte; # raw byte values
  };

  cidStringType = restrict "cidString" cidValid string;

  # Maps multicodec codes (as decimal strings) to their canonical names.
  codecNames = {
    "00" = "identity"; # 0x00
    "85" = "raw"; # 0x55
    "112" = "dag-pb"; # 0x70
    "113" = "dag-cbor"; # 0x71
    "297" = "dag-json"; # 0x0129
  };

  codecType = restrict "codec" (v: codecNames ? ${toString v}) int;
  codecName = restrict "codecName" (v: builtins.elem v (builtins.attrValues codecNames)) string;

  cidHashConverters = {
    "sha256" = cidFromSha256;
    # "sha512" = cidFromSha512;
  };

  supportedShaHash = restrict "supportedShaHash" (s: cidHashConverters ? ${sriHashAlgo s}) sriHash;

  /*
    Type for functions that convert supported SHA hashes to CID strings.
    Signature: supportedShaHash → cidStringType
  */
  cidConverterType = defun [
    supportedShaHash
    cidStringType
  ];

  cidType = struct "cid" {
    version = cidVersionType;
    codec = codecName;
    multihash = multihashType;
    cidStr = cidStringType;
    hash = sriHash;
  };

  /*
    Returns the version number of a CIDv1 string as an integer.
    Only base32-encoded CIDs (multibase prefix 'b') are supported.

    Example:
      cidVersion "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => 1
  */
  cidVersion = defun [ cidStringType cidVersionType ] (
    cidStr: base32Byte (builtins.substring 1 (-1) cidStr) 0
  );

  /*
    Type for base32-decoded CID body (without multibase prefix).
    Validates by re-prefixing "b" and checking cidStringType validity.
  */
  cidBody = restrict "cidBody" (s: cidValid ("b" + s)) string;

  /*
    Extracts the multicodec code from position 1 (0-indexed) of a CID body.
    Expects version byte already consumed at position 0.

    Arguments:
      body - Decoded CID body (cidBody)

    Returns:
      Integer multicodec code (codecType)

    Example:
      getCodecCode "afybeig..." → 112  (dag-pb)
  */
  getCodecCode = defun [ cidBody codecType ] (body: base32Byte body 1);

  /*
    Extracts the multihash function code from position 2 (0-indexed) of a CID body.

    The CID body layout is:
      0 - CID version
      1 - multicodec code
      2 - multihash function code
      3 - digest length
      4+ - digest bytes

    Arguments:
      body - Decoded CID body (cidBody)

    Returns:
      Integer multihash function code (hashFunctionCode)

    Example:
      getHashCode "afybeig..." → 18  (sha2-256)
  */
  getHashCode = defun [ cidBody hashFunctionCode ] (body: base32Byte body 2);

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
  hashFunction = defun [ cidBody hashFnType ] (
    body:
    let
      hashCode = getHashCode body;
    in
    {
      name = hashFunctionNames.${toString hashCode};
      code = hashCode;
    }
  );

  /*
    Extracts the CID body (without multibase prefix 'b') from a base32-encoded CID string.

    Arguments:
      cidStr - Valid base32-encoded CID string (cidStringType)

    Returns:
      The body portion as a string (cidBody)

    Example:
      getBody "bafybeig..." → "afybeig..."
  */
  getBody = defun [ cidStringType cidBody ] (cidStr: builtins.substring 1 (-1) cidStr);

  /*
      Returns the name of the hash function used in a CIDv1 string.
      Only base32-encoded CIDv1 with sha2-256 multihash is supported.

      Example:
        cidHashFunction "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        => { name = "sha2-256"; code = 18; }
  */
  cidHashFunction = defun [ cidStringType hashFnType ] (
    cidStr:
    let
      body = getBody cidStr;
      version = cidVersion cidStr;
    in
    if version != 1 then throw "Unsupported CID version: ${toString version}" else hashFunction body
  );

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
  cidDigestFromMultihash = defun [ multihashType sriHash ] (
    multihash:
    let
      inherit (multihash) fn digest;
      hashName = sriHashNames."${fn.name}";
    in
    "${hashName}-${base64Encode digest}"
  );

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
      A cidType attrset

    Example:
      mkCid {
        version = 1;
        codec = "raw";
        multihash = { fn = "sha2-256"; code = 18; len = 32; digest = [ ... ]; };
      }
  */
  mkCid =
    defun
      [
        (struct "mkCidArgs" {
          version = cidVersionType;
          codec = codecName;
          multihash = multihashType;
          cidStr = cidStringType;
        })
        cidType
      ]
      (
        {
          version,
          codec,
          multihash,
          cidStr,
        }:
        {
          inherit
            version
            codec
            multihash
            cidStr
            ;
          hash = cidDigestFromMultihash multihash;
        }
      );

  /*
    Returns the name of the multicodec used in a CIDv1 string.
    Only base32-encoded CIDv1 is supported.
    Throws if the CID is invalid, has an unsupported version,
    or uses an unsupported codec.

    Example:
      cidCodec "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "dag-pb"
  */
  cidCodec = defun [ cidStringType codecName ] (
    cidStr:
    let
      body = getBody cidStr;
      version = cidVersion cidStr;
      codecCode = getCodecCode body;
    in
    if version != 1 then
      throw "Unsupported CID version: ${toString version}"
    else if codecNames ? ${toString codecCode} then
      codecNames.${toString codecCode}
    else
      throw "Unsupported codec code: ${toString codecCode}"
  );

  /*
    Extracts the multihash from a base32-decoded CID body and returns
    it as a structured attribute set. Reads the hash function, digest
    length, and digest bytes from the binary CID layout.

    Arguments:
      body - The CID body string (without multibase prefix).

    Returns:
      An attribute set with:
        fn     - Hash function attribute set (as returned by `hashFunction`)
        len    - Digest length in bytes (integer)
        digest - List of byte values (list of integers)

    Example:
      mkMultihash "afybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => {
        fn = { name = "sha2-256"; code = 18; };
        len = 32;
        digest = [ 195 196 115 62 ... ];
      }
  */
  mkMultihash = defun [ cidBody multihashType ] (
    body:
    let
      digestLen = base32Byte body 3;
    in
    {
      fn = hashFunction body;
      len = digestLen;
      digest = builtins.genList (i: base32Byte body (4 + i)) digestLen;
    }
  );

  /*
    Constructs a multihash from a CIDv1 string by extracting the body and parsing it.

    Arguments:
      cidStr - Valid base32-encoded CIDv1 string (cidStringType)

    Returns:
      Parsed multihash structure (multihashType)

    Example:
      mkMultiHashFromCid "bafybeig..." → { fn = { name = "sha2-256"; code = 18; }; len = 32; digest = [ ... ]; }
  */
  mkMultiHashFromCid = defun [ cidStringType multihashType ] (cidStr: mkMultihash (getBody cidStr));

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
  cidFromSha256 = defun [ sha256Hash cidStringType ] (
    hash:
    let
      hex = builtins.convertHash {
        inherit hash;
        hashAlgo = "sha256";
        toHashFormat = "base16";
      };
      # CIDv1 binary prefix (hex):
      #   01 = CID version 1
      #   55 = multicodec "raw" (0x55)
      #   12 = multihash function "sha2-256" (0x12)
      #   20 = digest length: 32 bytes (0x20)
      prefix = "01551220";
      cidBytes = hexToBytes "${prefix}${hex}";
    in
    # "b" = multibase prefix for base32lower
    "b${base32Encode cidBytes}"
  );

  /*
    Parses a base32-encoded CIDv1 string into a structured CID attribute set.
    Only CIDs with multibase prefix 'b' (base32lower) are supported.

    Arguments:
      cidStr - A base32-encoded CIDv1 string (e.g. "bafybeig...").

    Returns:
      An attribute set with:
        version   - CID version (integer)
        codec     - Multicodec name (string)
        multihash - Attribute set with fn, code, len, digest

    Example:
      parseCid "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => {
        version = 1;
        codec = "dag-pb";
        multihash = {
          fn = "sha2-256";
          code = 18;
          len = 32;
          digest = [ 195 196 115 62 ... ];
        };
        hash = "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=";
      }
  */
  parseCid = defun [ cidStringType cidType ] (
    cidStr:
    mkCid {
      inherit cidStr;
      version = cidVersion cidStr;
      codec = cidCodec cidStr;
      multihash = mkMultiHashFromCid cidStr;
    }
  );

  /*
    Generic dispatch function for converting any supported SHA hash to a CID string.
    Looks up the appropriate converter in cidHashConverters based on the hash algorithm.

    Arguments:
      hash - Supported SHA hash (supportedShaHash)

    Returns:
      Base32-encoded CIDv1 string (cidStringType)

    Example:
      cidFromSha "sha256-w8RzPsiv/..." → "bafybeigdyrzt5s..."
  */
  cidFromSha = cidConverterType (
    hash:
    let
      converter = cidHashConverters.${sriHashAlgo hash};
    in
    converter hash
  );
in
{
  inherit
    cidDigestFromMultihash
    cidStringType
    cidVersion
    cidHashFunction
    cidValid
    encoding
    cidCodec
    parseCid
    cidType
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
      A cidType attrset

    Example:
      parseHash "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
      => {
        version = 1;
        codec = "raw";
        multihash = {
          fn = { name = "sha2-256"; code = 18; };
          len = 32;
          digest = [ ... ];
        };
      }
  */
  parseHash = defun [ supportedShaHash cidType ] (hash: parseCid (cidFromSha hash));

  /*
    Extracts the raw digest from a CIDv1 string and returns it as a Nix SRI hash string.
    Only base32-encoded CIDv1 with sha2-256 multihash is supported.
    Throws if the CID is too short, uses an unsupported multibase,
    has an unsupported version, or uses an unsupported hash function.

    Example:
      cidDigest "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
  */
  cidDigest = defun [ cidStringType supportedShaHash ] (
    cid:
    let
      hashFn = cidHashFunction cid;
      body = builtins.substring 1 (-1) cid;
      digestLen = base32Byte body 3;
      digestBytes = builtins.genList (i: base32Byte body (4 + i)) digestLen;
      sriName =
        if sriHashNames ? ${hashFn.name} then
          sriHashNames.${hashFn.name}
        else
          throw "No SRI name for ${hashFn.name}";
    in
    "${sriName}-${base64Encode digestBytes}"
  );

  /*
    Normalizes a CID string or cidType attrset to a cidType attrset.
    Accepts both raw CID strings and already-parsed cidType attrsets.
    Throws if the value is neither a valid CID string nor a cidType attrset.

    Arguments:
      x - A base32-encoded CIDv1 string or a cidType attrset

    Returns:
      A cidType attrset.

    Examples:
      asCid "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      => { version = 1; codec = "dag-pb"; multihash = { ... }; cidStr = "bafybei..."; hash = "sha256-..."; }

      asCid (parseCid "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      => { version = 1; codec = "dag-pb"; ... }  # idempotent
  */
  asCid = defun [ (either cidStringType cidType) cidType ] (
    x: if builtins.isString x then parseCid x else cidType x
  );

  /*
    Returns a new cidType attrset with the multihash replaced and the hash
    field updated accordingly. Use this instead of `//` to ensure that
    `multihash` and `hash` remain consistent.

    Arguments:
      parsedCid   - A cidType attrset (e.g. from parseCid or parseHash)
      newMultihash - A multihashType attrset to replace the existing multihash

    Returns:
      A cidType attrset with updated `multihash` and `hash` fields.

    Example:
      withMultihash (parseCid "bafybeig...") { fn = { name = "sha2-256"; code = 18; }; len = 32; digest = [ ... ]; }
      => { version = 1; codec = "dag-pb"; multihash = { ... }; cidStr = "bafybei..."; hash = "sha256-..."; }
  */
  withMultihash = defun [ cidType multihashType cidType ] (
    parsedCid: newMultihash:
    parsedCid
    // {
      multihash = newMultihash;
      hash = cidDigestFromMultihash newMultihash;
    }
  );
}

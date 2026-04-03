{ encoding, yants }:
let
  inherit (encoding)
    byte
    base64Encode
    sriHash
    sriHashNames
    ;
  inherit (yants)
    restrict
    int
    string
    struct
    list
    defun
    ;

  hashFunctionNames = {
    "18" = "sha2-256"; # 0x12
  };

  hashFunctionCode = restrict "hashFunctionCode" (v: hashFunctionNames ? ${toString v}) int;
  hashFunctionName = restrict "hashFunctionName" (
    v: builtins.elem v (builtins.attrValues hashFunctionNames)
  ) string;

  hashFnType = struct "hashFn" {
    name = hashFunctionName;
    code = hashFunctionCode;
  };

  /*
    Constructs a hashFnType attribute set from a numeric multihash function code.
    Combines the code with its canonical name looked up from hashFunctionNames.

    Arguments:
      code - Numeric multihash function code (hashFunctionCode, e.g. 18)

    Returns:
      An attribute set with:
        name - Canonical hash function name (string, e.g. "sha2-256")
        code - The numeric code passed in (integer, e.g. 18)

    Example:
      mkHashFn 18
      => { name = "sha2-256"; code = 18; }
  */
  mkHashFn = defun [ hashFunctionCode hashFnType ] (code: {
    name = getHashFunctionName code;
    inherit code;
  });

  multihashType = struct "multihash" {
    fn = hashFnType;
    len = int;
    digest = list byte;
  };

  /*
    Returns the canonical name of a multihash function by its numeric code.
    Throws if the code is not present in hashFunctionNames.

    Arguments:
      code - Numeric multihash function code (hashFunctionCode, e.g. 18)

    Returns:
      Canonical hash function name (hashFunctionName, e.g. "sha2-256")

    Example:
      getHashFunctionName 18
      => "sha2-256"
  */
  getHashFunctionName = defun [ hashFunctionCode hashFunctionName ] (
    code: hashFunctionNames.${toString code}
  );

  /*
    Converts a parsed multihash attribute set to a Nix SRI hash string.
    Maps the multihash function name to its SRI algorithm identifier via
    sriHashNames and base64-encodes the raw digest bytes.

    Arguments:
      multihash - A multihashType attribute set with:
                    fn     - Hash function set with `name` (e.g. "sha2-256")
                    digest - List of raw byte values (list of integers 0–255)

    Returns:
      A Nix SRI hash string (e.g. "sha256-w8RzPsiv/QbPnp/1D/...=").

    Throws if no SRI name mapping exists for the hash function name.

    Example:
      multihashToSriHash {
        fn = { name = "sha2-256"; code = 18; };
        len = 32;
        digest = [ 195 196 115 62 ... ];
      }
      => "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo="
  */
  multihashToSriHash = defun [ multihashType sriHash ] (
    multihash:
    let
      hashName = sriHashNames.${multihash.fn.name}; # TODO: use getter instead of direct access
    in
    "${hashName}-${base64Encode multihash.digest}"
  );
in
{
  inherit
    hashFunctionCode
    hashFnType
    mkHashFn
    multihashToSriHash
    multihashType
    ;
}

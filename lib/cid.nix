{ pkgs, encoding }:

let
  inherit (encoding) base32Byte base64Encode;
  minLength = 10;

  # Returns true if the CID string meets the minimum length requirement.
  isValidLength = cid: builtins.stringLength cid >= minLength;

  # Maps multihash function codes (as decimal strings) to their canonical names.
  hashFunctionNames = {
    "18" = "sha2-256"; # 0x12
  };

  /*
    Extracts the CID version byte from a base32-encoded CID body
    (i.e. the CID string with the multibase prefix removed).
  */
  cidVersionFromBase32 = code: base32Byte code 0;

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
    if !(isValidLength cid) then
      throw "Invalid CID: too short (min ${toString minLength} characters)"
    else
      let
        multibase = builtins.substring 0 1 cid;
      in
      if multibase == "b" then
        cidVersionFromBase32 (builtins.substring 1 (-1) cid)
      else
        throw "Non base32 CID not supported";

  /*
      Returns the name of the hash function used in a CIDv1 string.
      Only base32-encoded CIDv1 with sha2-256 multihash is supported.
      Throws if the CID is too short, uses an unsupported multibase,
      has an unsupported version, or uses an unsupported hash function.

      Example:
        cidHashFunction "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
        => "sha2-256"
  */
  cidHashFunction =
    cid:
    if !(isValidLength cid) then
      throw "Invalid CID: too short (min ${toString minLength} characters)"
    else
      let
        multibase = builtins.substring 0 1 cid;
      in
      if multibase != "b" then
        throw "Non base32 CID not supported"
      else
        let
          body = builtins.substring 1 (-1) cid;
          version = base32Byte body 0;
          # byte 1 = multicodec (skipped, assumed single-byte varint)
          hashFnCode = base32Byte body 2;
        in
        if version != 1 then
          throw "Unsupported CID version: ${toString version}"
        else if hashFunctionNames ? ${toString hashFnCode} then
          hashFunctionNames.${toString hashFnCode}
        else
          throw "Unsupported hash function code: ${toString hashFnCode}";

  sriHashNames = {
    "sha2-256" = "sha256";
  };
in
{
  inherit cidVersion cidHashFunction;

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
        if sriHashNames ? ${hashFn} then sriHashNames.${hashFn} else throw "No SRI name for ${hashFn}";
    in
    "${sriName}-${base64Encode digestBytes}";
}

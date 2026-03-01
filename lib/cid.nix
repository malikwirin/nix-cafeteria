{ pkgs }:

let
  minLength = 10;

  # Returns true if the CID string meets the minimum length requirement.
  isValidLength = cid: builtins.stringLength cid >= minLength;

  /*
    Lookup table mapping base32 characters (RFC 4648 alphabet, lowercase)
    to their 5-bit integer values.
  */
  base32Values = {
    a = 0;
    b = 1;
    c = 2;
    d = 3;
    e = 4;
    f = 5;
    g = 6;
    h = 7;
    i = 8;
    j = 9;
    k = 10;
    l = 11;
    m = 12;
    n = 13;
    o = 14;
    p = 15;
    q = 16;
    r = 17;
    s = 18;
    t = 19;
    u = 20;
    v = 21;
    w = 22;
    x = 23;
    y = 24;
    z = 25;
    "2" = 26;
    "3" = 27;
    "4" = 28;
    "5" = 29;
    "6" = 30;
    "7" = 31;
  };

  /*
    Returns the 5-bit integer value of a single base32 character.
    Throws if the character is not in the base32 alphabet.
  */
  base32CharValue =
    c: if base32Values ? ${c} then base32Values.${c} else throw "Invalid base32 character: ${c}";

  /*
    Decodes byte n (0-indexed) from a base32-encoded string s.
    Each base32 character encodes 5 bits; this function reconstructs
    the original 8-bit bytes from the bit stream.
    Only n = 0, 1, 2 are implemented (sufficient for CID header parsing).
    Throws for n > 2.
  */
  base32Byte =
    s: n:
    let
      cv = i: base32CharValue (builtins.substring i 1 s);
      c0 = cv 0;
      c1 = cv 1;
      c2 = cv 2;
      c3 = cv 3;
      c4 = cv 4;
      mod = a: b: a - (a / b) * b;
    in
    if n == 0 then
      c0 * 8 + c1 / 4
    else if n == 1 then
      (mod c1 4) * 64 + c2 * 2 + c3 / 16
    else if n == 2 then
      (mod c3 16) * 16 + c4 / 2
    else
      throw "base32Byte: n > 2 not implemented";

  # Maps multihash function codes (as decimal strings) to their canonical names.
  hashFunctionNames = {
    "18" = "sha2-256"; # 0x12
  };

  /*
    Extracts the CID version byte from a base32-encoded CID body
    (i.e. the CID string with the multibase prefix removed).
  */
  cidVersionFromBase32 = code: base32Byte code 0;
in
{
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

}

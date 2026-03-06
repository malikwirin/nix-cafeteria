let
  mod = a: b: a - (a / b) * b;

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

  base32CharValue =
    c: if base32Values ? ${c} then base32Values.${c} else throw "Invalid base32 character: ${c}";

  base64Table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  base64Char = n: builtins.substring n 1 base64Table;

  base32Table = "abcdefghijklmnopqrstuvwxyz234567";
  base32Char = n: builtins.substring n 1 base32Table;

  hexValues = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };

  hexCharValue = c: if hexValues ? ${c} then hexValues.${c} else throw "Invalid hex character: ${c}";
in
{
  inherit mod;

  /*
    Decodes byte n (0-indexed) from a base32-encoded string s.
    Works for any n — no upper limit.
  */
  base32Byte =
    s: n:
    let
      group = n / 5;
      byteInGroup = n - group * 5;
      charBase = group * 8;
      cv = i: base32CharValue (builtins.substring (charBase + i) 1 s);
      c0 = cv 0;
      c1 = cv 1;
      c2 = cv 2;
      c3 = cv 3;
      c4 = cv 4;
      c5 = cv 5;
      c6 = cv 6;
      c7 = cv 7;
    in
    if byteInGroup == 0 then
      c0 * 8 + c1 / 4
    else if byteInGroup == 1 then
      (mod c1 4) * 64 + c2 * 2 + c3 / 16
    else if byteInGroup == 2 then
      (mod c3 16) * 16 + c4 / 2
    else if byteInGroup == 3 then
      (mod c4 2) * 128 + c5 * 4 + c6 / 8
    else
      (mod c6 8) * 32 + c7;

  /*
    Decodes a lowercase hex string into a list of byte values (integers 0–255).
    The input string length must be even.

    Example:
      hexToBytes "c3c4" => [ 195 196 ]
      hexToBytes "0112" => [ 1 18 ]
  */
  hexToBytes =
    s:
    let
      len = builtins.stringLength s;
      numBytes = len / 2;
      decodeByte =
        i:
        let
          hi = hexCharValue (builtins.substring (i * 2) 1 s);
          lo = hexCharValue (builtins.substring (i * 2 + 1) 1 s);
        in
        hi * 16 + lo;
    in
    builtins.genList decodeByte numBytes;

  # Encodes a list of integers (bytes) as a base64 string with padding.
  base64Encode =
    bytes:
    let
      len = builtins.length bytes;
      b = i: builtins.elemAt bytes i;
      encodeGroup =
        i:
        let
          b0 = b i;
          b1 = if i + 1 < len then b (i + 1) else 0;
          b2 = if i + 2 < len then b (i + 2) else 0;
          remaining = len - i;
        in
        base64Char (b0 / 4)
        + base64Char ((mod b0 4) * 16 + b1 / 16)
        + (if remaining >= 2 then base64Char ((mod b1 16) * 4 + b2 / 64) else "=")
        + (if remaining >= 3 then base64Char (mod b2 64) else "=");
      numGroups = (len + 2) / 3;
    in
    builtins.concatStringsSep "" (builtins.genList (i: encodeGroup (i * 3)) numGroups);

  /*
    Encodes a list of byte values (integers 0–255) as a base32lower string
    (RFC 4648, lowercase alphabet a–z2–7, no padding).

    Each group of 5 bytes produces 8 base32 characters.
    Trailing groups are encoded without padding.

    Example:
      base32Encode [ 1 85 18 32 ]
      => "afkreja"
  */
  base32Encode =
    bytes:
    let
      len = builtins.length bytes;
      b = i: if i < len then builtins.elemAt bytes i else 0;
      numGroups = (len + 4) / 5;
      # number of valid base32 characters based on input length
      r = mod len 5;
      numChars =
        if r == 0 then
          numGroups * 8
        else if r == 1 then
          numGroups * 8 - 6
        else if r == 2 then
          numGroups * 8 - 4
        else if r == 3 then
          numGroups * 8 - 3
        else
          numGroups * 8 - 1;
      encodeGroup =
        g:
        let
          i = g * 5;
          b0 = b i;
          b1 = b (i + 1);
          b2 = b (i + 2);
          b3 = b (i + 3);
          b4 = b (i + 4);
        in
        [
          (base32Char (b0 / 8))
          (base32Char ((mod b0 8) * 4 + b1 / 64))
          (base32Char ((mod b1 64) / 2))
          (base32Char ((mod b1 2) * 16 + b2 / 16))
          (base32Char ((mod b2 16) * 2 + b3 / 128))
          (base32Char ((mod b3 128) / 4))
          (base32Char ((mod b3 4) * 8 + b4 / 32))
          (base32Char (mod b4 32))
        ];
      allChars = builtins.concatLists (builtins.genList encodeGroup numGroups);
    in
    builtins.concatStringsSep "" (builtins.genList (i: builtins.elemAt allChars i) numChars);

  /*
    Maps canonical multihash function names to their corresponding
    Nix SRI hash algorithm identifiers.

    Example:
      sriHashNames."sha2-256"
      => "sha256"
  */
  sriHashNames = {
    "sha2-256" = "sha256";
  };

  isSha256 =
    hash:
    with builtins;
    (isString hash) && (stringLength hash == 51) && (substring 0 7 hash == "sha256-");
}

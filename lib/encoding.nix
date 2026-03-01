{ }:

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
}

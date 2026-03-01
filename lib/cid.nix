{ pkgs }:

let
  minLength = 10;

  isValidLength = cid: builtins.stringLength cid >= minLength;

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

  base32FirstByte =
    s:
    let
      c1 = base32CharValue (builtins.substring 0 1 s);
      c2 = base32CharValue (builtins.substring 1 1 s);
    in
    (c1 * 8) + (c2 / 4);

  cidVersionFromBase32 = code: base32FirstByte code;
in
{
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

  cidHashFunction = cid: throw "not implemented";
}

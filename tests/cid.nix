{ pkgs }:

let
  inherit (pkgs.lib) runTests;
  cid = import ../lib/cid.nix { inherit pkgs; };
in
runTests {
  testCidVersionV1 = {
    expr = cid.cidVersion "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
    expected = 1;
  };

  testCidVersionV1Short = {
    expr = cid.cidVersion "bafkreifjjcie6lypi6ny7amxnfftagclbuxndqonfipmb53t5lkpscezbm";
    expected = 1;
  };

  testCidVersionInvalidPrefix = {
    expr = builtins.tryEval (cid.cidVersion "notacid");
    expected = {
      success = false;
      value = false;
    };
  };
}

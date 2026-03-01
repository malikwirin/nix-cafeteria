{ pkgs }:

let
  inherit (pkgs.lib) runTests;
  cid = import ../lib/cid.nix { inherit pkgs; };
  cid1 = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
  cid2 = "bafkreifjjcie6lypi6ny7amxnfftagclbuxndqonfipmb53t5lkpscezbm";
in
runTests {
  testCidVersionV1 = {
    expr = cid.cidVersion cid1;
    expected = 1;
  };

  testCidVersionV1Short = {
    expr = cid.cidVersion cid2;
    expected = 1;
  };

  testCidVersionInvalidPrefix = {
    expr = builtins.tryEval (cid.cidVersion "notacid");
    expected = {
      success = false;
      value = false;
    };
  };

  testCidHashFunctionV1 = {
    expr = cid.cidHashFunction cid1;
    expected = "sha2-256";
  };

  testCidHashFunctionV1Raw = {
    expr = cid.cidHashFunction cid2;
    expected = "sha2-256";
  };

  testCidHashFunctionUnsupported = {
    expr = builtins.tryEval (
      cid.cidHashFunction "bafkrgqhhyivzstcz3hhswshfjgy6buap4trqa3rvmrb7d2bkrpjb6rxzou"
    );
    expected = {
      success = false;
      value = false;
    };
  };

}

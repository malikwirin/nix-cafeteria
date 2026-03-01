{ pkgs }:

let
  inherit (pkgs.lib) runTests;
  cid = import ../lib/cid.nix { inherit pkgs; };
  cidDagPb = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
  cidRaw = "bafkreifjjcie6lypi6ny7amxnfftagclbuxndqonfipmb53t5lkpscezbm";

in
runTests {
  testCidVersionDagPb = {
    expr = cid.cidVersion cidDagPb;
    expected = 1;
  };

  testCidVersionRaw = {
    expr = cid.cidVersion cidRaw;
    expected = 1;
  };

  testCidVersionInvalidPrefix = {
    expr = builtins.tryEval (cid.cidVersion "notacid");
    expected = {
      success = false;
      value = false;
    };
  };

  testCidHashFunctionDagPb = {
    expr = cid.cidHashFunction cidDagPb;
    expected = "sha2-256";
  };

  testCidHashFunctionRaw = {
    expr = cid.cidHashFunction cidRaw;
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

  testCidDigestDagPb = {
    expr = cid.cidDigest cidDagPb;
    expected = "w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=";
  };

  testCidDigestRaw = {
    expr = cid.cidDigest cidRaw;
    expected = "iQWFhMlVK1mxMSgkGZdaWLp2RnBaW1q1dW4SnLJmf0o=";
  };

  testCidDigestInvalidPrefix = {
    expr = builtins.tryEval (cid.cidDigest "notacid1234");
    expected = {
      success = false;
      value = false;
    };
  };
}

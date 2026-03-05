{ pkgs, cafeteriaLib }:

let
  inherit (cafeteriaLib) cid;
  constants = import ./constants.nix;
  inherit (constants) cidDagPb cidRaw;
in
{
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

  testCidCodecDagPb = {
    expr = cid.cidCodec cidDagPb;
    expected = "dag-pb";
  };

  testCidCodecRaw = {
    expr = cid.cidCodec cidRaw;
    expected = "raw";
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
    expected = "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=";
  };

  testCidDigestRaw = {
    expr = cid.cidDigest cidRaw;
    expected = "sha256-0qhPS4tlCTfsj3PNi+LHSt1akRumTfJ0WO2CKdqASiY=";
  };

  testCidDigestInvalidPrefix = {
    expr = builtins.tryEval (cid.cidDigest "notacid1234");
    expected = {
      success = false;
      value = false;
    };
  };
}

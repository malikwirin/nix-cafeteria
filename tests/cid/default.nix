{
  cafeteriaLib,
  constants,
}:

let
  inherit (cafeteriaLib) cid;
  inherit (constants) cidDagPb cidRaw hash;
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
    expected = hash.sha2-256;
  };

  testCidHashFunctionRaw = {
    expr = cid.cidHashFunction cidRaw;
    expected = hash.sha2-256;
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

  # --- mkCid / parseCid ---
  testParseCidDagPbVersion = {
    expr = (cid.parseCid cidDagPb).version;
    expected = 1;
  };

  testParseCidDagPbCodec = {
    expr = (cid.parseCid cidDagPb).codec;
    expected = "dag-pb";
  };

  testParseCidDagPbHashFn = {
    expr = (cid.parseCid cidDagPb).multihash.fn;
    expected = hash.sha2-256;
  };

  testParseCidDagPbDigestLen = {
    expr = (cid.parseCid cidDagPb).multihash.len;
    expected = 32;
  };

  testParseCidDagPbDigestLength = {
    expr = builtins.length (cid.parseCid cidDagPb).multihash.digest;
    expected = 32;
  };

  testParseCidRawCodec = {
    expr = (cid.parseCid cidRaw).codec;
    expected = "raw";
  };

  testParseCidRawHashFn = {
    expr = (cid.parseCid cidRaw).multihash.fn;
    expected = hash.sha2-256;
  };

  testParseCidInvalid = {
    expr = builtins.tryEval (cid.parseCid "notacid");
    expected = {
      success = false;
      value = false;
    };
  };

  testParseCidInvalidShort = {
    expr = builtins.tryEval (cid.parseCid "bshort");
    expected = {
      success = false;
      value = false;
    };
  };

  # --- parseHash ---

  testParseHashDagPbVersion = {
    expr = (cid.parseHash "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=").version;
    expected = 1;
  };

  testParseHashDagPbCodec = {
    expr = (cid.parseHash "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=").codec;
    expected = "raw";
  };

  testParseHashDagPbHashFn = {
    expr = (cid.parseHash "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=").multihash.fn;
    expected = hash.sha2-256;
  };

  testParseHashDagPbDigestLen = {
    expr = (cid.parseHash "sha256-w8RzPsiv/QbPnp/1D/xrzS7IWmFwAEu3CWacMd6UORo=").multihash.len;
    expected = 32;
  };

  testParseHashInvalid = {
    expr = builtins.tryEval (cid.parseHash "notahash");
    expected = {
      success = false;
      value = false;
    };
  };
}

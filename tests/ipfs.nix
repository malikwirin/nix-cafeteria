{ pkgs, cafeteriaLib }:

let
  inherit (pkgs.lib) runTests;
  constants = import ./constants.nix;
  inherit (constants) cidDagPb cidRaw gateway;
  inherit (cafeteriaLib) ipfs;
in
runTests {
  testIpfsGatewayUrlDagPb = {
    expr = ipfs.gatewayUrl gateway cidDagPb;
    expected = "https://ipfs.io/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
  };

  testIpfsGatewayUrlRaw = {
    expr = ipfs.gatewayUrl gateway cidRaw;
    expected = "https://ipfs.io/ipfs/bafkreifjjcie6lypi6ny7amxnfftagclbuxndqonfipmb53t5lkpscezbm";
  };

  testIpfsGatewayUrlTrailingSlash = {
    expr = ipfs.gatewayUrl "${gateway}/" cidDagPb;
    expected = "https://ipfs.io/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
  };

  testIpfsGatewayUrlInvalidCid = {
    expr = builtins.tryEval (ipfs.gatewayUrl gateway "notacid1234");
    expected = {
      success = false;
      value = false;
    };
  };
}

{
  pkgs,
  cafeteriaLib,
  constants,
}:

let
  inherit (constants) cidDagPb cidRaw gateway;
  inherit (cafeteriaLib) ipfs;
in
{
  testIpfsGatewayUrlDagPb = {
    expr = ipfs.gatewayUrl gateway cidDagPb;
    expected = "https://ipfs.io/ipfs/bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi";
  };

  testIpfsGatewayUrlRaw = {
    expr = ipfs.gatewayUrl gateway cidRaw;
    expected = "https://ipfs.io/ipfs/bafkreigsvbhuxc3fbe36zd3tzwf6fr2k3vnjcg5gjxzhiwhnqiu5vackey";
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

  testFetchFromIpfsDagPbWithoutHash = {
    expr = builtins.tryEval (
      ipfs.fetchFromIpfs {
        ipfsCid = cidDagPb;
        gateway = gateway;
      }
    );
    expected = {
      success = false;
      value = false;
    };
  };

  testFetchFromIpfsDagPbWithHash = {
    expr =
      (builtins.tryEval (
        ipfs.fetchFromIpfs {
          ipfsCid = cidDagPb;
          gateway = gateway;
          hash = pkgs.lib.fakeHash;
        }
      )).success;
    expected = true;
  };
}

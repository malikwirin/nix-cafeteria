{
  pkgs,
  cafeteriaLib,
  constants,
}:

let
  inherit (constants) cidDagPb cidRaw gateway;
  inherit (cafeteriaLib) multiformats ipfs;
  inherit (multiformats) cid;
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

  testFetchFromIpfsDagPbRootBlock = {
    expr =
      (builtins.tryEval (
        ipfs.fetchFromIpfs {
          ipfsCid = cidDagPb;
          gateway = gateway;
        }
      )).success;
    expected = true;
  };

  testFetchFromIpfsDagPbFileWithoutHash = {
    expr = builtins.tryEval (
      ipfs.fetchFromIpfs {
        ipfsCid = cidDagPb;
        gateway = gateway;
        path = "index.html";
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

  # --- fetchFromIpfsCar ---

  testFetchFromIpfsCarRawEvaluates = {
    expr =
      (builtins.tryEval (
        ipfs.fetchFromIpfsCar {
          carCid = cidRaw;
          inherit gateway;
        }
      )).success;
    expected = true;
  };

  testFetchFromIpfsCarWithBlockCidEvaluates = {
    expr =
      (builtins.tryEval (
        ipfs.fetchFromIpfsCar {
          carCid = cidRaw;
          blockCid = cidDagPb;
          inherit gateway;
        }
      )).success;
    expected = true;
  };

  testFetchFromIpfsCarInvalidCid = {
    expr = builtins.tryEval (
      ipfs.fetchFromIpfsCar {
        carCid = "notacid";
        inherit gateway;
      }
    );
    expected = {
      success = false;
      value = false;
    };
  };

  testFetchFromIpfsCarParsedCidEvaluates = {
    expr =
      (builtins.tryEval (
        ipfs.fetchFromIpfsCar {
          carCid = cid.parseCid cidRaw;
          inherit gateway;
        }
      )).success;
    expected = true;
  };

  # --- fetchCarBlocks ---

  testFetchCarBlocksInvalidCid = {
    expr = builtins.tryEval (
      ipfs.fetchCarBlocks {
        carCid = "notacid";
      }
    );
    expected = {
      success = false;
      value = false;
    };
  };
}

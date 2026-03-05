{
  pkgs,
  fmtBuild,
  self,
  cafeteriaLib,
}:
let
  # constants = import ./tests/constants.nix;
  # inherit (constants) cidDagPb gateway;
  tests = pkgs.lib.runTests (import ./tests { inherit pkgs cafeteriaLib; });
in
{
  formatting = fmtBuild.check self;
  unit-tests =
    if tests == [ ] then
      pkgs.runCommand "unit-tests" { } "touch $out"
    else
      throw "Tests failed: ${builtins.toJSON (map (t: t.name) tests)}";

  # ipfs-fetch-dagpb = cafeteriaLib.ipfs.fetchFromIpfs {
  #   ipfsCid = cidDagPb;
  #   inherit gateway;
  # };

  # ipfsFetchDagPbCar = cafeteriaLib.ipfs.fetchFromIpfsCar {
  #   carCid = "bafybeib3z6pvtz2h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4x7h4";
  #   blockCid = cidDagPb;
  #   inherit gateway;
  # };
}

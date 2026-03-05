{
  pkgs,
  fmtBuild,
  self,
  cafeteriaLib,
}:
let
  # constants = import ./tests/constants.nix;
  # inherit (constants) cidDagPb gateway;
  allTests = import ./tests { inherit pkgs cafeteriaLib; };
  tests = pkgs.lib.runTests allTests;
  totalCount = builtins.length (builtins.attrNames allTests);
  passed = builtins.removeAttrs allTests (map (t: t.name) tests);
  logPassed = builtins.foldl' (acc: name: builtins.trace "  ✓ ${name}" acc) null (
    builtins.attrNames passed
  );
  logHeader = builtins.trace "Running ${toString totalCount} unit tests..." logPassed;
in
{
  formatting = fmtBuild.check self;
  unit-tests = builtins.seq logHeader (
    if tests == [ ] then
      builtins.trace "All ${toString totalCount} tests passed." (
        pkgs.runCommand "unit-tests" { } "touch $out"
      )
    else
      throw (
        builtins.concatStringsSep "\n" (
          [ "${toString (builtins.length tests)} of ${toString totalCount} tests failed:\n" ]
          ++ map (t: ''
            ✗ ${t.name}
              expected: ${builtins.toJSON t.expected}
              got:      ${builtins.toJSON t.result}
          '') tests
        )
      )
  );

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

{
  pkgs,
  fmtBuild,
  self,
  cafeteriaLib,
}:
let
  constants = import ./tests/constants.nix;
  inherit (constants) cidRaw gateway;
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

  ipfs-fetch-dagpb = cafeteriaLib.ipfs.fetchFromIpfs {
    ipfsCid = cidRaw;
    inherit gateway;
  };

  ipfs-fetch-car =
    let
      testCar = pkgs.runCommand "test.car" { } ''
        echo "hello ipfs" > hello.txt
        ${pkgs.go-car}/bin/car create --file $out hello.txt
      '';
      inherit (cafeteriaLib.car) carInspect carList;
      grep = (pkgs.lib.getExe pkgs.gnugrep);
    in
    pkgs.runCommand "ipfs-fetch-car-check" { } ''
      echo "=== car inspect ==="
      cat ${carInspect testCar}
      echo "✓ car inspect succeeded"

      echo "=== car list ==="
      cat ${carList testCar}

      # Check that car list output contains at least one CID (starts with 'b')
      ${grep} -q '^b' ${carList testCar} \
        || (echo "FAIL: car list produced no CIDs" && exit 1)
      echo "✓ car list contains CIDs"

      echo "=== all checks passed ==="
      touch $out
    '';
}

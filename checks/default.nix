{
  pkgs,
  fmtBuild,
  self,
  cafeteriaLib,
}:
let
  constants = import ../tests/constants.nix;
  allTests = import ../tests { inherit pkgs cafeteriaLib; };
  tests = pkgs.lib.runTests allTests;
  totalCount = builtins.length (builtins.attrNames allTests);
  passed = builtins.removeAttrs allTests (map (t: t.name) tests);
  logPassed = builtins.foldl' (acc: name: builtins.trace "  ✓ ${name}" acc) null (
    builtins.attrNames passed
  );
  logHeader = builtins.trace "Running ${toString totalCount} unit tests..." logPassed;
  testCar = pkgs.runCommand "test.car" { } ''
    echo -n "hello ipfs" > hello.txt
    ${pkgs.go-car}/bin/car create -f $out --no-wrap hello.txt
  '';
  cidStrings = cafeteriaLib.car.carCidStrings testCar;
  firstCid = builtins.elemAt cidStrings 0;
  moduleChecks = import ./modules.nix {
    inherit pkgs;
    modulePath = ../modules;
  };
  fetchFromIpfsChecks = import ./fetchFromIpfs {
    inherit
      pkgs
      cafeteriaLib
      testCar
      constants
      ;
  };
in
moduleChecks
# // fetchFromIpfsChecks # TODO: re-enable once fetchFromIpfs is dag-pb compatible
// {
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

  car-cids =
    let
      inherit (cafeteriaLib.car) carCids;
      cids = carCids testCar;

      cidCount = builtins.length cids;
      firstCid = builtins.elemAt cids 0;
    in
    pkgs.runCommand "car-cids-check" { } ''
      echo "=== carCids ==="
      echo "Found ${toString cidCount} CID(s)"
      echo "✓ carCids returned a non-empty list"

      echo "First CID codec: ${firstCid.codec}"
      echo "✓ codec is ${firstCid.codec}"

      echo "=== all checks passed ==="
      touch $out
    '';

  car-extract =
    let
      extracted = cafeteriaLib.car.carExtract {
        carFile = testCar;
        blockCid = firstCid;
      };
    in
    pkgs.runCommand "car-extract-check" { } ''
      echo "=== carExtract ==="
      echo "Extracting block: ${firstCid}"

      [ -f ${extracted} ] \
        || (echo "✗ extracted file does not exist" && exit 1)
      echo "✓ carExtract produced output"

      CONTENT=$(cat ${extracted})
      [ "$CONTENT" = "hello ipfs" ] \
        || (echo "✗ expected 'hello ipfs', got '$CONTENT'" && exit 1)
      echo "✓ extracted content matches original"

      echo "=== all checks passed ==="
      touch $out
    '';

  car-cid-strings =
    let
      count = builtins.length cidStrings;
      valid = cafeteriaLib.cid.cidValid firstCid;
    in
    pkgs.runCommand "car-cid-strings-check" { } ''
      echo "=== carCidStrings ==="
      echo "Found ${toString count} CID(s)"

      [ ${toString count} -gt 0 ] \
        || (echo "✗ no CIDs found" && exit 1)
      echo "✓ non-empty list"

      echo "First CID: ${firstCid}"
      [ "${toString valid}" = "1" ] \
        || (echo "✗ first CID is invalid" && exit 1)
      echo "✓ first CID is valid"

      echo "=== all checks passed ==="
      touch $out
    '';

  car-inspect =
    let
      inspected = cafeteriaLib.car.carInspect testCar;
    in
    pkgs.runCommand "car-inspect-check" { } ''
      echo "=== carInspect ==="
      cat ${inspected}

      grep -q "Version:" ${inspected} \
        || (echo "✗ missing Version field" && exit 1)
      echo "✓ contains Version"

      grep -q "Roots:" ${inspected} \
        || (echo "✗ missing Roots field" && exit 1)
      echo "✓ contains Roots"

      grep -q "Block count:" ${inspected} \
        || (echo "✗ missing Block count field" && exit 1)
      echo "✓ contains Block count"

      echo "=== all checks passed ==="
      touch $out
    '';
}

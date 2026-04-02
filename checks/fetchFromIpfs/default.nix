{
  pkgs,
  cafeteriaLib,
  testCar,
  constants,
}:

let
  inherit (constants) gateway cidRaw;
  inherit (cafeteriaLib.ipfs) fetchFromIpfs;
in
{
  ipfs-fetch-dagpb = fetchFromIpfs {
    ipfsCid = cidRaw;
    inherit gateway;
  };

  ipfs-fetch-car =
    let
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

  fetchFromIpfs-helloWorld = pkgs.runCommand "fetchFromIpfs-helloWorld" { } ''
    set -euo pipefail

    # Use a stable, well-known small IPFS fixture.
    fetched="${
      fetchFromIpfs {
        ipfsCid = "bafkreifzjut3te2nhyekklss27nh3k72ysco7y32koao5eei66wof36n5e";
      }
    }"

    expected="hello world"
    actual="$(cat "$fetched")"

    if [ "$actual" != "$expected" ]; then
      echo "Unexpected content for known small IPFS fixture."
      echo "Expected: $expected"
      echo "Actual:   $actual"
      exit 1
    fi

    mkdir -p "$out"
    echo "ok" > "$out/result"
  '';
}

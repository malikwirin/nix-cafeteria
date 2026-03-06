{
  pkgs,
  go-car ? pkgs.go-car,
}:

let
  car = pkgs.lib.getExe go-car;
in
{
  /*
    Extracts a single block from a CAR file by its CID.

    Arguments:
      carFile  - Path to the CAR file (derivation or path)
      blockCid - CID string of the block to extract

    Returns:
      A derivation containing the extracted block.
  */
  carExtract =
    {
      carFile ? "$out",
      blockCid,
    }:
    pkgs.runCommand "car-extract-${blockCid}" { } ''
      ${car} extract --file ${carFile} --block ${blockCid} > $out
    '';

  /*
    Lists all CIDs contained in a CAR file.

    Arguments:
      carFile - Path to the CAR file (derivation or path)

    Returns:
      A derivation whose output contains one CID per line.
  */
  carList =
    carFile:
    pkgs.runCommand "car-ls" { } ''
      ${car} ls ${carFile} > $out
    '';

  /*
    Inspects a CAR file and returns its metadata
    (roots, version, block count).

    Arguments:
      carFile - Path to the CAR file (derivation or path)

    Returns:
      A derivation whose output contains the CAR metadata.
  */
  carInspect =
    carFile:
    pkgs.runCommand "car-inspect" { } ''
      ${pkgs.go-car}/bin/car inspect ${carFile} > $out
    '';
}

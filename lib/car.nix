{
  pkgs,
  yants,
}:

let
  inherit (yants)
    defun
    drv
    either
    list
    path
    string
    ;

  go-car = pkgs.lib.getExe pkgs.go-car;

  carFile = either path drv; # TODO: check that the drv or path is a CAR file

  /*
    Lists all CIDs contained in a CAR file.

    Arguments:
      carFile - Path to the CAR file (derivation or path)

    Returns:
      A derivation whose output contains one CID per line.
  */
  carList = defun [ carFile drv ] (
    carFile:
    pkgs.runCommand "car-ls" { } ''
      ${go-car} ls ${carFile} > $out
    ''
  );

  carCidStrings = defun [ carFile (list string) ] (
    carFile:
    with builtins;
    let
      raw = readFile (carList carFile);
    in
    filter (x: isString x && x != "") (split "\n" raw)
  );
in
{
  inherit carFile carList carCidStrings;
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
      carFile,
      blockCid,
    }:
    pkgs.runCommand "car-extract-${blockCid}" { } ''
      ${go-car} get-block ${carFile} ${blockCid} > $out
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
      ${go-car} inspect ${carFile} > $out
    '';

  /*
    Reads the output of carList and returns a Nix list of
    parsed CID attrsets. Requires IFD (import-from-derivation).

    Arguments:
      carFile - Path to the CAR file
      parseCid - CID parser function (from cid module)

    Returns:
      A list of parsed CID attrsets.
  */
  carCids = { carFile, parseCid }: builtins.map parseCid (carCidStrings carFile);
}

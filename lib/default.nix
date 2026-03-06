{
  pkgs,
  defaultGateway ? "https://ipfs.io",
}:

let
  cid = import ./cid { };
  car = import ./car.nix { inherit pkgs; };
in
{
  inherit car cid;
  ipfs = import ./ipfs.nix {
    inherit
      pkgs
      cid
      car
      defaultGateway
      ;
  };
}

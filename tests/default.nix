{
  pkgs ? import <nixpkgs> { },
  cafeteriaLib ? import ../lib { inherit pkgs; },
}:

let
  constants = import ./constants.nix;
  cid = import ./cid { inherit pkgs cafeteriaLib constants; };
  ipfs = import ./ipfs.nix { inherit pkgs cafeteriaLib constants; };
in
cid // ipfs

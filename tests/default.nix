{
  pkgs ? import <nixpkgs> { },
  cafeteriaLib ? import ../lib { inherit pkgs; },
}:

let
  cid = import ./cid.nix { inherit pkgs cafeteriaLib; };
  ipfs = import ./ipfs.nix { inherit pkgs cafeteriaLib; };
in
cid // ipfs

{
  pkgs ? import <nixpkgs> { },
  cafeteriaLib ? import ../lib { inherit pkgs; },
}:

let
  constants = import ./constants.nix;
  multiformats = import ./multiformats { inherit cafeteriaLib constants; };
  ipfs = import ./ipfs.nix { inherit pkgs cafeteriaLib constants; };
in
multiformats // ipfs

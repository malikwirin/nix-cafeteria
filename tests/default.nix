{
  pkgs ? import <nixpkgs> { },
  cafeteriaLib ? import ../lib { inherit pkgs; },
}:

(import ./cid.nix { inherit pkgs cafeteriaLib; })

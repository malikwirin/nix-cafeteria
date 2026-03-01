{
  pkgs ? import <nixpkgs> { },
}:

(import ./cid.nix { inherit pkgs; })

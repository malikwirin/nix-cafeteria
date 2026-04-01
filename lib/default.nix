{
  pkgs,
  defaultGateway ? "https://ipfs.io",
  yants ?
    pkgs.lib.yants or (import (builtins.fetchGit {
      url = "https://code.tvl.fyi/depot.git:/nix/yants.git";
      ref = "refs/heads/canon";
      rev = "efeb6dc11eb1a1e88d41dc2093fc5aa31f7abd35";
    }) { inherit (pkgs) lib; }),
}:

let
  cid = import ./cid { };
  car = import ./car.nix { inherit pkgs yants; };
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

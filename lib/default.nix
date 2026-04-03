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
  car = import ./car.nix { inherit pkgs cid yants; };
  cid = import ./cid { inherit encoding yants; };
  encoding = import ./encoding.nix { inherit yants; };
in
{
  inherit car cid encoding;
  ipfs = import ./ipfs.nix {
    inherit
      pkgs
      cid
      car
      defaultGateway
      encoding
      yants
      ;
  };
}

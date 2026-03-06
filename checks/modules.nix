{ pkgs, modulePath }:

{
  module-ipfs =
    let
      eval = pkgs.lib.evalModules {
        modules = [
          {
            options.nixpkgs = pkgs.lib.mkOption {
              type = pkgs.lib.types.submodule {
                freeformType = pkgs.lib.types.attrs;
              };
              default = { };
            };
          }
          (modulePath + /ipfs/common.nix)
          {
            config.nixpkgs.ipfs.gateway = "https://dweb.link";
          }
        ];
      };
    in
    pkgs.runCommand "module-ipfs-check" { } ''
      echo "=== NixOS Module: ipfs ==="

      [ "${eval.config.nixpkgs.ipfs.gateway}" = "https://dweb.link" ] \
        || (echo "✗ gateway not set correctly" && exit 1)
      echo "✓ gateway = https://dweb.link"

      echo "=== all checks passed ==="
      touch $out
    '';
}

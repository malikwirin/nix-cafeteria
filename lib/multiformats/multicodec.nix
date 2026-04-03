{ yants }:
let
  inherit (yants)
    defun
    restrict
    int
    string
    ;

  codecNames = {
    "0" = "identity"; # 0x00
    "85" = "raw"; # 0x55
    "112" = "dag-pb"; # 0x70
    "113" = "dag-cbor"; # 0x71
    "297" = "dag-json"; # 0x0129
  };

  codecType = restrict "codec" (v: codecNames ? ${toString v}) int;
  codecName = restrict "codecName" (v: builtins.elem v (builtins.attrValues codecNames)) string;

  getCodecName = defun [ codecType codecName ] (codec: codecNames.${toString codec});
in
{
  inherit codecType codecName getCodecName;
}

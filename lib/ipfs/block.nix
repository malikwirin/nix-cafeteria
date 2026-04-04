{ multiformats, yants }:
let
  inherit (cid) cidType;
  inherit (encoding) sriHash;
  inherit (multicodec) codecName;
  inherit (multiformats) cid encoding multicodec;
  inherit (yants)
    defun
    function
    option
    restrict
    string
    struct
    ;

  blockFetcher = function; # (block gateway -> derivation) FIXME: enforce signature

  /*
    Structured type representing a content-addressed IPFS block.
    Fields:
      cid     - Parsed CID identifying the block
      fetcher - Codec-specific fetch function (blockFetcher)
      path    - Optional sub-path within the block (UnixFS only)
  */
  block = struct "IPFSBlock" {
    cid = cidType;
    fetcher = blockFetcher;
    path = option string;
  };

  blockRestrict = defun [ codecName function ] (
    name: restrict "${name}Block" (b: b.cid.codec == name) block
  );

  # identityBlock = blockRestrict "identity";
  # rawBlock = blockRestrict "raw";
  dagPbBlock = blockRestrict "dag-pb";

  dagPbFileBlock = restrict "dagPbFileBlock" (b: b.path != null) dagPbBlock;
  # dagPbRootBlock = restrict "dagPbRootBlock" (b: b.path == null) dagPbBlock;
in
{
  inherit block blockFetcher dagPbFileBlock;
  getDagPbFileHash = defun [ dagPbFileBlock sriHash ] (
    b: throw "Getting hash from dagPbFile currently not supported"
  );
}

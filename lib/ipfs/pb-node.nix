{
  blocks,
  encoding,
  fetchers,
  yants,
}:

let
  inherit (blocks) dagPbBlock;
  inherit (fetchers) rawFetcher url;
  inherit (encoding) sriHash;
  inherit (yants) defun drv string;
  pbNodeDrv = drv; # FIXME
in
{
  pbNodeFromBlock = defun [ dagPbBlock url pbNodeDrv ] (
    b: gateway:
    # FIXME: rawFetcher is wrong because it would fetch the directory instead of the file reprrsanting the node
    rawFetcher b gateway
  );
  getHashFromPbNode = defun [ pbNodeDrv string sriHash ] (
    _node: _path: throw "getHashFromPbNode not yet implemented"
  );
}

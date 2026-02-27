# CID Structure

A Content Identifier (CID) encodes everything needed to verify content:

## CIDv0
- Base58btc-encoded SHA2-256 multihash
- Always starts with `Qm`
- Example: `QmZ4tDuvesekSs4qM5ZBKpXiZGun7S2CYtEZRB3DYXkjGx`

## CIDv1
- `<multibase-prefix> <version> <multicodec> <multihash>`
- multibase:  encoding prefix (e.g. `b` = base32)
- version:    `0x01`
- multicodec: content type (e.g. `0x70` = dag-pb, `0x55` = raw)
- multihash:  `<hash-function-code> <digest-length> <digest>`
  - e.g. `0x12 0x20` = SHA2-256 with 32-byte digest
- Example: `bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi`

## Relation to Nix hashes
A CIDv1 with SHA2-256 multihash contains the same digest
that Nix would express as `sha256-<base64>`.
The goal of cidToHash is to extract this digest and convert
it to the SRI format Nix expects.

## References
- https://github.com/multiformats/cid
- https://github.com/multiformats/multihash


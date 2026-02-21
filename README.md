# nix-cafeteria

Experimental playground for content-addressed fetchers in Nix.

The goal is to develop and test Nix functions such as `fetchFromIPFS`
and `fetchFromRadicle` that fetch sources via content-addressing protocols
rather than location-based URLs — with the long-term aim of contributing
them to nixpkgs.

This work is related to the [Pre-RFC: Generic content-addressed fetchers (IPFS, Radicle, etc.)](https://discourse.nixos.org/t/pre-rfc-generic-content-addressed-fetchers-ipfs-radicle-etc/)
on the NixOS Discourse.

## Status

Early experiment. Nothing here is production-ready.


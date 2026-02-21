---
id: decision-1
title: 'Scope: nixpkgs-only vs. changes to Nix itself'
date: '2026-02-21 19:02'
status: proposed
---
# Scope: nixpkgs-only vs. changes to Nix itself

## Status
Open

## Context
Content-addressed fetchers could be implemented at two levels:

- **nixpkgs-only**: Users configure preferred gateways via `nixpkgs.config`.
  No changes to Nix itself required. Lower barrier to contribution.
- **Nix-level**: Native built-in fetchers (`builtins.fetchIPFS` etc.) with
  first-class protocol support. More powerful, but requires upstream Nix changes.

## nixpkgs.config approach
Users could set e.g.:

    nixpkgs.config.ipfsGateway = "http://localhost:8080";

This keeps everything in Nix expressions and avoids touching the Nix evaluator.

## Open question: Bootstrapping
If the gateway is configured via nixpkgs, but nixpkgs itself needs to be
fetched first — does that create a chicken-and-egg problem?
This needs to be investigated before a decision can be made.

## Links
- [Pre-RFC discussion](https://discourse.nixos.org/t/pre-rfc-generic-content-addressed-fetchers-ipfs-radicle-etc/75367)


---
id: doc-1
title: motivation
type: other
created_date: '2026-02-21 18:16'
---

# Motivation

Fetching sources in Nix today is location-based. For example, fetching
from IPFS requires hardcoding a gateway:

    fetchurl {
      url = "https://ipfs-gateway.example.com/ipfs/QmXyz...";
      hash = "sha256-...";
    }

This has several problems:

- **Centralization**: The gateway becomes a single point of failure
- **Non-reproducibility**: If the gateway goes down, the build breaks
  even though the content exists elsewhere
- **User lock-in**: Different users may prefer different nodes/gateways
  (local daemon, LAN peers, public gateways)

Content-addressed fetchers solve this by identifying sources by *what*
they are, not *where* they live — making builds truly location-independent.

See also: [Pre-RFC: Generic content-addressed fetchers (IPFS, Radicle, etc.)](https://discourse.nixos.org/t/pre-rfc-generic-content-addressed-fetchers-ipfs-radicle-etc/75367)


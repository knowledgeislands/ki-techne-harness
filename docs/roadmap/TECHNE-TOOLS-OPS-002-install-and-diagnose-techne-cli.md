---
id: TECHNE-TOOLS-OPS-002
area: OPS
title: Install and diagnose Techne
theme: operations
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T06:48:20Z
updated_at: 2026-09-20T06:48:20Z
---

# Install and diagnose Techne

## Goal

Make `techne` installable from a local development checkout and as an immutable Homebrew release, while `techne doctor` and `techne diag` clearly explain the active installation and operating mode.

## Context

The CLI currently runs only through the repository package script. Knowledge Islands already has a proven local-development installation pattern in `tools-ki/install.sh --link`: a launcher in `~/.local/bin` executes the checkout source through Bun. The governed `homebrew-tap` repository requires a formula to point at a tagged immutable upstream source or release artifact with a matching checksum.

## Boundary

This work may add the local-link installer, installation provenance, version reporting, diagnostic output, mode-aware health checks, release packaging and verification in Techne Tools. The companion formula, checksum and tap documentation remain owned by `knowledgeislands/homebrew-tap` and must land through a separate tap-local work record after an immutable Techne release exists. Publishing a tag or release and changing the tap require explicit release authority.

## Discussion

### Installation modes

Local development should use an explicit `install.sh --link` flow with a `TECHNE_INSTALL_DIR` override and no download. Source execution is `local`; a compiled immutable artifact is `release`. Homebrew is a distribution channel for the release artifact, not a separate runtime architecture.

### Diagnostics

`techne diag` should report version, installation provenance, executable or source entrypoint, working directory and effective non-secret configuration without making network calls. `techne doctor` should turn those facts into actionable checks: Bun is required for a linked source installation, while AWS CLI, Session Manager and account checks remain capability checks for controller operations.

### Homebrew handoff

Do not add a placeholder or floating formula. First establish a reproducible versioned artifact and checksum contract in this repository; then create the corresponding formula and validation evidence in the tap repository.

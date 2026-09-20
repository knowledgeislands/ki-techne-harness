---
id: TECHNE-TOOLS-OPS-006
area: OPS
title: Extract standalone Techne CLI
theme: operations
horizon: triage
status: draft
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-005]
baseline_ref: null
created_at: 2026-09-20T10:52:33Z
updated_at: 2026-09-20T10:52:33Z
---

# Extract standalone Techne CLI

## Goal

Create `tools-techne` as the independent source and release home for the `techne` operator CLI so its installation and version lifecycle do not change whenever Techne harness applications or images change.

## Context

The prototype CLI, local-link installer, diagnostics and release packaging currently live in this product monorepo. That proves the command surface, but a repository-wide `v0.1.0` would version the CLI together with controller, image, manifest and infrastructure changes. Other standalone Knowledge Islands tools use one top-level `tools-*` repository and a companion Homebrew formula.

## Boundary

This extraction depends on `TECHNE-TOOLS-OPS-005` producing an explicit harness boundary and a cohesive operator-CLI source tree. The migration may move CLI source, tests, installer, versioning, release workflows and user-facing CLI documentation to `tools-techne`, then hand an immutable release to `homebrew-tap`. It must not duplicate mutable runtime payloads, publish from both repositories, introduce a package-registry dependency or leave two authoritative `techne` executables.

## Discussion

### Independent release units

`tools-techne` should own the operator binary, local-development installation, diagnostics, command contracts, semantic version, release archives and Homebrew handoff. The Techne harness should independently own controller and execution images, manifests, infrastructure templates and versioned runtime payload artifacts.

### Harness consumption

Commands that deploy or update the harness need an explicit artifact contract. A released CLI should consume immutable harness artifacts or an explicitly selected local harness checkout; it should not assume its own source repository contains controller code and deployment resources.

### Migration safety

Retain provenance while moving the accepted CLI implementation. Establish the new repository, tests and release path before removing the old command entrypoint. Cut the first public CLI release only from `tools-techne`, then add its verified checksums to `knowledgeislands/homebrew-tap`.

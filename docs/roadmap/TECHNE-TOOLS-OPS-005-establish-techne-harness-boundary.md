---
id: TECHNE-TOOLS-OPS-005
area: OPS
title: Establish Techne harness boundary
theme: operations
horizon: triage
status: draft
blocks: [TECHNE-TOOLS-OPS-006]
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T10:52:33Z
updated_at: 2026-09-20T10:52:33Z
---

# Establish Techne harness boundary

## Goal

Make this repository a clear Techne build-and-deployment harness whose applications, packages, infrastructure and runtime payloads have explicit ownership, with no ambiguous collection of operator-facing scripts.

## Context

The current repository is already a product monorepo for the controller, execution resources, Kubernetes manifests and AWS infrastructure, but its 19 top-level scripts mix four responsibilities: three repository checks, ten local operator workflows, five controller-host payloads and one target-host payload. Extracting the CLI before classifying those responsibilities would leave unclear ownership on both sides and make release coupling harder to remove.

## Boundary

This work should inventory every script, choose its durable owner and migrate or remove it before the standalone CLI extraction. It may reshape repository-local tooling and relocate host payloads beside their deployable applications or resources. It must not create `tools-techne`, publish a CLI release, update Homebrew, rename the GitHub repository or mutate live infrastructure without separately approved migration and operational authority.

## Discussion

### Proposed responsibility split

- Repository checks may remain development tooling, but should be visibly internal rather than presented as product commands.
- Local operator workflows should become typed `techne` commands with shared configuration, safety guards, diagnostics and boundary tests.
- Controller-host and target-host payloads are deployment artifacts. They should live beside the application or deployment resource that owns them and remain independently packageable without depending on a miscellaneous root script directory.
- Upload logic should package an explicit artifact boundary rather than enumerate unrelated source paths ad hoc.

### Harness identity

The working architectural interpretation is that this repository is the Techne harness: it builds controller and execution applications, packages their runtime materials and owns infrastructure/deployment verification. Whether its final repository name becomes `ki-techne-harness` is a durable naming and migration decision, not a prerequisite for cleaning the internal boundary.

### Sequencing

Complete and verify this responsibility cleanup before extracting the operator CLI. The cleanup should leave one cohesive directory tree that can move to `tools-techne` without copying controller runtime ownership with it.

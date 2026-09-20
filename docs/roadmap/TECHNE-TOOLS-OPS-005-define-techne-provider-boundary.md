---
id: TECHNE-TOOLS-OPS-005
area: OPS
title: Define Techne provider boundary
theme: operations
horizon: triage
status: draft
blocks: [TECHNE-TOOLS-OPS-006]
blocked_by: []
baseline_ref: null
created_at: 2026-09-20T10:52:33Z
updated_at: 2026-09-20T10:56:01Z
---

# Define Techne provider boundary

## Goal

Make this repository a coherent provider of deployable Techne implementations whose applications, packages, infrastructure and runtime payloads have explicit ownership, with no ambiguous collection of operator-facing scripts.

## Context

The current repository is already a product monorepo for the controller, fabric operator, execution resources, Kubernetes manifests and AWS infrastructure, but its 19 top-level scripts mix four responsibilities: three repository checks, ten local operator workflows, five controller-host payloads and one target-host payload. Extracting the CLI before classifying those responsibilities would leave unclear ownership on both sides and make release coupling harder to remove.

Techne Principal currently assigns this repository the runnable controller and fabric-operator implementations plus their provider adapters. Calling the repository a harness would collide with the distinct `ki-agentic-harness` authority for reusable agentic capabilities. A provider model may describe how `tools-techne` consumes these deployable implementations, but that role and its contract need to be made explicit before choosing a durable repository name.

## Boundary

This work should inventory every script, choose its durable owner and migrate or remove it before the standalone CLI extraction. It may reshape repository-local tooling, relocate host payloads beside their deployable applications or resources, and propose the provider contract and repository identity to Techne Principal. It must not create `tools-techne`, publish a CLI release, update Homebrew, rename the GitHub repository, redefine canonical Techne architecture locally or mutate live infrastructure without separately approved migration and operational authority.

## Discussion

### Proposed responsibility split

- Repository checks may remain development tooling, but should be visibly internal rather than presented as product commands.
- Local operator workflows should become typed `techne` commands with shared configuration, safety guards, diagnostics and boundary tests.
- Controller-host and target-host payloads are deployment artifacts. They should live beside the application or deployment resource that owns them and remain independently packageable without depending on a miscellaneous root script directory.
- Upload logic should package an explicit artifact boundary rather than enumerate unrelated source paths ad hoc.

### Provider identity

The working interpretation is that this repository provides deployable implementations of Techne's controller and fabric roles. It builds their applications, packages runtime materials and owns infrastructure, provider adapters and deployment verification. It is not the canonical source of reusable agentic capabilities, and an infrastructure provider such as AWS remains an adapter behind its portable boundary.

Before choosing between a name such as `ki-techne-provider` or `ki-techne-runtime`, define what the repository supplies to `tools-techne`: versioned artifacts, capability and compatibility metadata, configuration schemas, lifecycle operations and diagnostics. The durable role and name require a Techne Principal decision because the current canonical decision still describes one product monorepo.

### CLI relationship

`tools-techne` should be the independently released operator interface. This repository should expose stable, versioned implementation artifacts and a local-development mode rather than requiring the CLI to share its source tree or release cadence.

### Sequencing

Complete and verify this responsibility cleanup before extracting the operator CLI. The cleanup should leave one cohesive directory tree that can move to `tools-techne` without copying controller or fabric runtime ownership with it.

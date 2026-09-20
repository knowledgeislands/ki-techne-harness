---
id: TECHNE-TOOLS-OPS-005
area: OPS
title: Define Techne harness boundary
theme: operations
horizon: now
status: done
blocks: [TECHNE-TOOLS-OPS-006]
blocked_by: []
baseline_ref: e922be3cff7556d842e4c9441268e58ff53cf9d6
created_at: 2026-09-20T10:52:33Z
updated_at: 2026-09-20T12:13:15Z
---

# Define Techne harness boundary

## Goal

Make this repository a coherent Techne execution harness whose applications, packages, infrastructure and runtime payloads have explicit ownership, with no ambiguous collection of operator-facing scripts.

## Context

The current repository is already a product monorepo for the controller, fabric operator, execution resources, Kubernetes manifests and AWS infrastructure, but its 19 top-level scripts mix four responsibilities: three repository checks, ten local operator workflows, five controller-host payloads and one target-host payload. Extracting the CLI before classifying those responsibilities would leave unclear ownership on both sides and make release coupling harder to remove.

Techne Principal currently assigns this repository the runnable controller and fabric-operator implementations plus their provider adapters. Harness describes that integrated runnable system more accurately than provider: provider adapters are replaceable parts inside it, while the whole repository assembles the controller, execution fabric and deployment resources needed to run work. This Techne execution harness must remain distinct from `ki-agentic-harness`, which owns reusable agentic capabilities and harness-compatible semantics.

## Boundary

This work should inventory every script, choose its durable owner and migrate or remove it before the standalone CLI extraction. It may reshape repository-local tooling, relocate host payloads beside their deployable applications or resources, and propose the harness contract and repository identity to Techne Principal. It must not create `tools-techne`, publish a CLI release, update Homebrew, rename the GitHub repository, redefine canonical Techne architecture locally or mutate live infrastructure without separately approved migration and operational authority.

## Current state

The top-level `scripts/` directory contains 19 files with four distinct owners: three repository checks, ten local operator workflows, five controller-host payloads and one target-host payload. The obsolete controller-proof guide presents all four groups as one operator surface. Package scripts, upload archives, remote command paths and the current CLI bootstrap command depend on that mixed layout.

## Steps

- [x] Move repository checks under `tooling/checks/` and update package and workspace verification entry points.
- [x] Move local AWS and Telegram operator workflows under `operations/`, grouped by concern and retained only as harness lifecycle implementations intended to sit behind `techne` commands.
- [x] Move controller-host and target-host payloads under `deploy/runtime/`, beside the deployment resources that own them.
- [x] Update upload archives, remote invocation paths, internal root resolution, shell verification and CLI bootstrap integration for the owned locations.
- [x] Remove the obsolete controller-proof guide and replace its repository-map value with concise harness ownership and command-boundary guidance.
- [x] Verify repository gates and confirm no tracked reference still depends on the miscellaneous top-level `scripts/` layout.

## Files touched

- `scripts/`
- `tooling/checks/`
- `operations/`
- `deploy/runtime/`
- `apps/cli/src/aws.ts`
- `apps/cli/tests/cli.test.ts`
- `apps/controller/package.json`
- `AGENTS.md`
- `package.json`
- `README.md`
- `docs/guides/`
- `docs/roadmap/TECHNE-TOOLS-OPS-005-define-techne-harness-boundary.md`

## Verify

- `bun run test`
- `bunx turbo run typecheck`
- `bunx biome check .`
- `bunx rumdl check README.md docs/guides docs/roadmap/TECHNE-TOOLS-OPS-005-define-techne-harness-boundary.md`
- `ki repo audit --skill ki-work-roadmap --repo .`
- `rg -n 'scripts/' --glob '!docs/roadmap/**' .` returns no stale path reference.

## Dependencies / blocks

No work item blocks this cleanup. It must complete before `TECHNE-TOOLS-OPS-006` extracts the standalone CLI. The newly created `knowledgeislands/tools-techne` remote is intentionally not mutated by this item.

## Documentation impact

### Decision Records

Techne Principal's implementation-ownership decision will need a separately governed update after the split boundary is accepted; this item does not edit Principal authority.

### Specifications

No portable specification changes. The work classifies implementation ownership without standardising a cross-provider contract.

### Guides

Remove the controller-proof guide, update the guide index and root repository map, and document the distinction between the Techne Harness, its internal provider adapters and the independently released `tools-techne` operator interface.

### Roadmap

Record the verified boundary here so `TECHNE-TOOLS-OPS-006` can plan the standalone CLI extraction against it. No delegation is planned because the path moves, reference updates and verification are tightly coupled in one shared working tree.

## Review

### Delivered

Delivered the approved harness-boundary cleanup from immutable baseline `e922be3cff7556d842e4c9441268e58ff53cf9d6` in implementation commit `7a4bf22fc7823b67adc288aa0ef36e701f16739c`. The delivery did not mutate AWS, publish a release, rename the GitHub repository or write to the new `tools-techne` remote.

### Summary of changes

- Replaced the miscellaneous top-level `scripts/` directory with repository checks under `tooling/checks/`, local lifecycle implementations under `operations/` and host payloads under `deploy/runtime/`.
- Updated package scripts, controller verification, upload archives and the CLI bootstrap path for the owned locations.
- Removed the obsolete 371-line controller-proof guide and added concise ownership guidance for operations and runtime payloads.
- Described this repository as the Techne Harness while retaining the current repository and package identities until the approved split.

### Verification

- `bun run test` passed the root dependency-layout gate, both workspace test and typecheck tasks, 14 CLI tests, 14 controller tests and release-package verification.
- `bunx turbo run typecheck` passed both workspaces.
- `bunx biome check .` passed.
- `bunx rumdl check AGENTS.md README.md operations/README.md deploy/runtime/README.md docs/guides docs/roadmap/TECHNE-TOOLS-OPS-005-define-techne-harness-boundary.md` passed.
- `ki repo audit --skill ki-work-roadmap --repo .` passed.
- The stale-path search found no tracked non-roadmap reference to `scripts/`.

### Outstanding concerns

The CLI source, installer and release tooling intentionally remain in this repository until `TECHNE-TOOLS-OPS-006` is approved and implemented. Techne Principal still describes the current single product monorepo, and the current GitHub repository has not been renamed. Live CloudFormation validation remains separately tracked by `TECHNE-TOOLS-OPS-003`.

### Post-change review

The goal is met: every retained executable now has one visible owner, the obsolete proof-oriented guide is gone, packaging and bootstrap paths follow the new layout, and repository gates cover the moved files. The change is ready for human acceptance before the dependent CLI extraction begins.

### Mini recap

The Techne Harness now has an explicit internal boundary between development checks, local lifecycle operations and remote runtime payloads. The next proposed delivery is to extract the coherent `apps/cli`, installer and release surface into `knowledgeislands/tools-techne`; no additional learning route was identified beyond the existing Principal decision update.

## Done

Accepted 2026-09-20 by Kris Brown on the review packet above, with `TECHNE-TOOLS-OPS-006` selected as the next delivery and `tools-ki` named as its repository-shape reference.

## Discussion

### Proposed responsibility split

- Repository checks may remain development tooling, but should be visibly internal rather than presented as product commands.
- Local operator workflows should become typed `techne` commands with shared configuration, safety guards, diagnostics and boundary tests.
- Controller-host and target-host payloads are deployment artifacts. They should live beside the application or deployment resource that owns them and remain independently packageable without depending on a miscellaneous root script directory.
- Upload logic should package an explicit artifact boundary rather than enumerate unrelated source paths ad hoc.

### Harness identity

The working interpretation is that this repository is the Techne execution harness. It builds the controller and fabric applications, packages their runtime materials and owns infrastructure, provider adapters and deployment verification. It consumes compatible reusable agentic capabilities without becoming their canonical source. Infrastructure providers such as AWS remain replaceable adapters behind the harness boundary.

Before adopting a name such as `ki-techne-harness`, define what the repository supplies to `tools-techne`: versioned artifacts, capability and compatibility metadata, configuration schemas, lifecycle operations and diagnostics. The durable role and name require a Techne Principal decision because the current canonical decision still describes one product monorepo.

### CLI relationship

`tools-techne` should be the independently released operator interface. This repository should expose stable, versioned harness artifacts and a local-development mode rather than requiring the CLI to share its source tree or release cadence.

### Sequencing

Complete and verify this responsibility cleanup before extracting the operator CLI. The cleanup should leave one cohesive directory tree that can move to `tools-techne` without copying controller or fabric runtime ownership with it.

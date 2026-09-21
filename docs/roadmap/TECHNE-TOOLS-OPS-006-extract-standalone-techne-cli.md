---
id: TECHNE-TOOLS-OPS-006
area: OPS
title: Extract standalone Techne CLI
theme: operations
horizon: now
status: done
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-005]
baseline_ref: 283bed573bcfd60dce9169c4710bba7313f3dfc5
created_at: 2026-09-20T10:52:33Z
updated_at: 2026-09-21T23:55:41Z
---

# Extract standalone Techne CLI

## Goal

Create `tools-techne` as the independent source and release home for the `techne` operator CLI so its installation and version lifecycle do not change whenever Techne harness applications or images change.

## Context

The prototype CLI, local-link installer, diagnostics and release packaging currently live in this product monorepo. That proves the command surface, but a repository-wide `v0.1.0` would version the CLI together with controller, image, manifest and infrastructure changes. Other standalone Knowledge Islands tools use one top-level `tools-*` repository and a companion Homebrew formula.

## Boundary

This extraction depends on `TECHNE-TOOLS-OPS-005` producing an explicit harness boundary and a cohesive operator-CLI source tree. The migration may move CLI source, tests, installer, versioning, release workflows and user-facing CLI documentation to `tools-techne`, then hand an immutable release to `homebrew-tap`. It must not duplicate mutable runtime payloads, publish from both repositories, introduce a package-registry dependency or leave two authoritative `techne` executables.

## Current state

`TECHNE-TOOLS-OPS-005` is accepted and the harness now owns checks, lifecycle operations and runtime payloads explicitly. The CLI remains under `apps/cli/` with root-level installer and release assets coupled to the harness package and CI. `knowledgeislands/tools-techne` exists as a private repository; its local checkout has a clean, unpushed documentation-baseline commit `d38146c16bd5196e0d0f9996636be9e769a2d461` on top of the remote initial commit. `tools-ki` provides the accepted reference shape for a standalone KI CLI repository.

## Steps

- [x] Establish `tools-techne` as a flat Bun/TypeScript KI Project following `tools-ki`: root `src/`, `bin/techne`, package metadata, pinned toolchain, formatting, typechecking, tests, hooks, KI declarations and fixed working areas.
- [x] Move the accepted CLI implementation and tests from `apps/cli/`, adapting imports and test layout without changing the current public command grammar or AWS safety boundary.
- [x] Move local installation, release packaging and GitHub CI/release workflows; add a physical manual, changelog and release artifact checks appropriate to the current Techne surface.
- [x] Preserve the existing `tools-techne` documentation-baseline commit and record the source harness commit in extraction history rather than creating a provenance-document tree.
- [x] Verify the new repository independently, including local-link installation and a current-platform compiled archive smoke test, without publishing a tag or release.
- [x] Remove CLI source, installer and release ownership from the harness; update its package graph, CI, README and guidance to point at `tools-techne` while retaining harness runtime artifacts.
- [x] Verify the harness independently and confirm only `tools-techne` remains the authoritative `techne` executable source.

## Files touched

### `knowledgeislands/tools-techne`

- Existing `README.md` and `docs/guides/`
- Root KI repository and Bun/TypeScript toolchain files
- `src/`, `bin/techne`, `man/techne.1`
- `install.sh`, `release/`, `.github/workflows/`
- `CHANGELOG.md`, `ROADMAP.md`, `docs/roadmap/`

### `knowledgeislands/ki-techne-harness`

- `apps/cli/`
- `install.sh`, `release/`, `.github/workflows/`
- `package.json`, `bun.lock`, `turbo.json`
- `README.md`, `AGENTS.md`, `.gitignore`
- `docs/roadmap/TECHNE-TOOLS-OPS-006-extract-standalone-techne-cli.md`

## Verify

### `tools-techne`

- `bun install --frozen-lockfile`
- `bun run test`
- `bun run test:coverage`
- `bun run typecheck`
- `bun run build`
- `./install.sh --link` with an isolated install directory, followed by `techne --version` and `techne diag --json`
- Current-platform `release/package.sh` and archive smoke test
- `bunx biome check .`, `bunx rumdl check .`, `git diff --check`

### Techne Harness

- `bun install --frozen-lockfile`
- `bun run test`
- `bunx biome check .`
- `bunx rumdl check README.md AGENTS.md docs/roadmap/TECHNE-TOOLS-OPS-006-extract-standalone-techne-cli.md`
- `ki repo audit --skill ki-work-roadmap --repo .`
- Search confirms no non-roadmap source, installer, workflow or package entry still owns the `techne` executable.

## Dependencies / blocks

`TECHNE-TOOLS-OPS-005` is done. The existing local `tools-techne` documentation commit must be preserved. The repository is private, so public Homebrew distribution remains blocked until visibility and first-release authority are handled separately. This item must not tag, publish, release, update the Homebrew tap, rename the harness repository or mutate live infrastructure.

## Documentation impact

### Decision Records

Techne Principal's implementation-ownership decision requires a separately governed update after the extraction is accepted; this item records implementation evidence but does not edit Principal authority.

### Specifications

No portable specification changes. Existing CLI grammar, diagnostics and exit behaviour remain executable contracts in the extracted repository.

### Guides

Retain and update the existing `tools-techne` contributor guides, add the physical manual and remove installation guidance from the harness. User-facing command guidance belongs to `tools-techne`; harness guidance describes only runtime artifacts and operations.

### Roadmap

This item remains the migration record in the source repository. First publication remains separate future work and must be represented in the destination repository before release. No delegation is planned because the cross-repository move, source deletion and verification are sequentially coupled.

## Review

### Delivered

Established `knowledgeislands/tools-techne` as the standalone source and release home for the `techne` operator CLI, then removed the duplicate CLI, installer and release surface from Techne Harness.

### Summary of changes

- Preserved destination baseline `d38146c16bd5196e0d0f9996636be9e769a2d461` and committed the extracted implementation as `482353c660d9b892cb343f3ff16f56460db68465` with source provenance for accepted harness commit `e1422cad179aa2cc449f2b7b13def7aed7c7b42e`.
- Followed the `tools-ki` repository shape: a flat Bun/TypeScript source tree, `bin/techne`, local-link installer, physical manual, deterministic compiled archives, CI and release workflows, 100% coverage gates, KI declarations and fixed working areas.
- Registered the destination locally and aligned its private GitHub repository description, merge policy, feature toggles and Dependabot settings with the KI repository contract.
- Removed `apps/cli/`, root `install.sh`, `release/` and the release workflow from Techne Harness in `e577b306548e15e9ed8dc3ebae2a7dac42c5d46b`; updated the package graph, lockfile, checks and README without moving harness applications, operations or runtime payloads.

### Verification

- Destination: frozen Bun install; build; 37 tests; 100% statement, branch, function and line coverage; typecheck; isolated local installer tests; current-platform compiled archive smoke test; `mandoc`; Biome; rumdl; syncpack; knip; YAML parse; and `git diff --check` passed.
- Destination KI audit passes all 15 declared capabilities after the extracted implementation and MIT license reached `origin/main`.
- Harness: frozen Bun install with Bun 1.4.1, root dependency-layout check, controller typecheck and 14 controller tests, Biome, rumdl, `git diff --check` and the `ki-engineering` repository audit passed.
- A non-roadmap search found no remaining harness CLI source, installer, release packager, executable package script or release workflow.

### Outstanding concerns

- `tools-techne` remains private; public visibility, tags, GitHub releases and Homebrew publication remain explicitly outside this item.
- The destination records first publication as `TECHNE-TOOL-CLI-001`; the older harness release item still needs an explicit human disposition rather than an inferred merge.
- Techne Principal still requires a separately governed decision update for the accepted implementation-ownership split.

### Post-change review

The split leaves one authoritative `techne` executable while retaining deployable applications, provider operations and runtime payloads in Techne Harness. The extracted CLI still invokes the harness-owned controller bootstrap payload by its deployment path; no mutable runtime implementation was copied into the tool repository. No credentials, provider session material, tags, releases or Homebrew state were created.

### Mini recap

The key decision was to treat `tools-techne` as a release-independent operator tool and this repository as Techne Harness. The durable follow-up routes are the destination first-release work item and the existing Techne Principal decision process; no additional guide or provenance tree is needed.

## Done

Accepted 2026-09-21 after confirming the standalone `tools-techne` source and release boundary, the retained Techne Harness application and runtime boundary, the destination and harness verification evidence, and the explicit routing of publication and Principal ownership follow-up work.

## Discussion

### Independent release units

`tools-techne` should own the operator binary, local-development installation, diagnostics, command contracts, semantic version, release archives and Homebrew handoff. The Techne harness should independently own controller and execution images, manifests, infrastructure templates, provider adapters and versioned runtime payload artifacts.

### Harness consumption

Commands that deploy or update the harness need an explicit artifact contract. A released CLI should consume immutable harness artifacts or an explicitly selected local harness checkout; it should not assume its own source repository contains controller code and deployment resources.

### Migration safety

Retain provenance while moving the accepted CLI implementation. Establish the new repository, tests and release path before removing the old command entrypoint. Cut the first public CLI release only from `tools-techne`, then add its verified checksums to `knowledgeislands/homebrew-tap`.

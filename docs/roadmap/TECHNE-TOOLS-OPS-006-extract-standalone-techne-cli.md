---
id: TECHNE-TOOLS-OPS-006
area: OPS
title: Extract standalone Techne CLI
theme: operations
horizon: now
status: in-progress
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-005]
baseline_ref: 283bed573bcfd60dce9169c4710bba7313f3dfc5
created_at: 2026-09-20T10:52:33Z
updated_at: 2026-09-20T12:17:29Z
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

- [ ] Establish `tools-techne` as a flat Bun/TypeScript KI Project following `tools-ki`: root `src/`, `bin/techne`, package metadata, pinned toolchain, formatting, typechecking, tests, hooks, KI declarations and fixed working areas.
- [ ] Move the accepted CLI implementation and tests from `apps/cli/`, adapting imports and test layout without changing the current public command grammar or AWS safety boundary.
- [ ] Move local installation, release packaging and GitHub CI/release workflows; add a physical manual, changelog and release artifact checks appropriate to the current Techne surface.
- [ ] Preserve the existing `tools-techne` documentation-baseline commit and record the source harness commit in extraction history rather than creating a provenance-document tree.
- [ ] Verify the new repository independently, including local-link installation and a current-platform compiled archive smoke test, without publishing a tag or release.
- [ ] Remove CLI source, installer and release ownership from the harness; update its package graph, CI, README and guidance to point at `tools-techne` while retaining harness runtime artifacts.
- [ ] Verify the harness independently and confirm only `tools-techne` remains the authoritative `techne` executable source.

## Files touched

### `knowledgeislands/tools-techne`

- Existing `README.md` and `docs/guides/`
- Root KI repository and Bun/TypeScript toolchain files
- `src/`, `bin/techne`, `man/techne.1`
- `install.sh`, `release/`, `.github/workflows/`
- `CHANGELOG.md`, `ROADMAP.md`, `docs/roadmap/`

### `knowledgeislands/ki-techne-tools`

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

## Discussion

### Independent release units

`tools-techne` should own the operator binary, local-development installation, diagnostics, command contracts, semantic version, release archives and Homebrew handoff. The Techne harness should independently own controller and execution images, manifests, infrastructure templates, provider adapters and versioned runtime payload artifacts.

### Harness consumption

Commands that deploy or update the harness need an explicit artifact contract. A released CLI should consume immutable harness artifacts or an explicitly selected local harness checkout; it should not assume its own source repository contains controller code and deployment resources.

### Migration safety

Retain provenance while moving the accepted CLI implementation. Establish the new repository, tests and release path before removing the old command entrypoint. Cut the first public CLI release only from `tools-techne`, then add its verified checksums to `knowledgeislands/homebrew-tap`.

---
id: TECHNE-TOOLS-OPS-001
area: OPS
title: Establish Techne CLI
theme: operations
horizon: next
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-19T16:51:50Z
updated_at: 2026-09-19T17:33:43Z
---

# Establish Techne CLI

## Goal

Provide a `techne` command-line application as the single operator interface for checking and bootstrapping the retained controller, with consistent configuration, safety checks and terminal output.

## Context

The repository currently exposes controller operations through root package aliases and standalone Bash scripts. Those entry points repeat AWS account verification, region and stack configuration, CloudFormation output lookup and SSM session construction. The monorepo must retain `apps/` for independently runnable products, including containerized applications, while the CLI becomes another application rather than replacing that structure.

The first delivery should prove the application boundary with read-only diagnostics and the existing secure interactive bootstrap path before broader controller, target and container workflows migrate.

## Boundary

This item establishes the CLI application and migrates controller diagnostics and bootstrap orchestration. It does not containerize the controller, migrate target lifecycle commands, remove remote host bootstrap payloads, publish to a package registry, deploy infrastructure or mutate live controller state during verification.

## Current state

The repository has no `techne` executable or TypeScript application. Controller bootstrap is a standalone Bash package invoked through `bun run ki:controller:bootstrap`; it duplicates AWS configuration and lookup logic also present in operational scripts. The repository test gate passes, and the existing remote bootstrap payload already preserves the required private credential boundary.

## Steps

- [ ] Add a private Bun and TypeScript CLI application under `apps/cli` with a `techne` binary, root workspace command and repository-governance coverage for the new TypeScript surface.
- [ ] Implement typed non-secret configuration, shell-free process execution, AWS identity and controller-stack inspection, human and JSON output, and deterministic error handling.
- [ ] Implement `techne doctor`, `techne controller status` and `techne controller bootstrap`, retaining interactive SSM credential admission without placing secret values in arguments, configuration or logs.
- [ ] Replace the standalone bootstrap package and legacy root alias, then update repository orientation and the controller operations guide to use the CLI.
- [ ] Add unit and command-level tests using fake executable responses, then run the complete repository and governance gates without contacting live infrastructure.

## Files touched

- `apps/cli/**`
- `packages/bootstrap/**`
- `package.json`
- `bun.lock`
- `.ki.toml` and the managed engineering-skill projection selected by repository coverage
- `README.md`
- `docs/guides/controller-proof.md`
- this roadmap record

## Verify

Run `mise exec bun@1.4.1 -- bun run test`, `mise exec bun@1.4.1 -- bun run techne -- --help`, focused CLI tests, `ki repo audit --repo .` and `git diff --check`. All must pass without live AWS, Telegram, Kubernetes or network access.

## Dependencies / blocks

There are no work-item dependencies or external delivery blocks. Bun `1.4.1` is already installed through mise; dependency installation and lockfile changes remain repository-root operations.

## Documentation impact

### Decision Records

No Decision Record is needed: this delivery applies the agreed monorepo boundary without changing Techne Principal architecture or authority.

### Specifications

No standalone specification is needed for the first internal CLI surface; command behavior, exit codes and redaction requirements are executable in CLI tests.

### Guides

Update the repository README and controller operations guide so operator-facing examples use `techne`; do not expose internal runtime payload scripts as the primary workflow.

### Roadmap

Controller containerization and migration of the remaining controller and target lifecycle scripts stay outside this item and require separately captured work.

## Discussion

### Initial command surface

The first supported commands should be `techne doctor`, `techne controller status` and `techne controller bootstrap`. Bootstrap may open the existing private interactive SSM session, but credentials must remain confined to that session and must never enter CLI arguments, configuration, logs or retained test evidence.

### Application boundary

The CLI should live under `apps/` alongside the controller and future containerized applications. Shared packages should be introduced only when at least two applications need the same stable contract. Repository-only verification remains development tooling, while scripts executed on controller or target hosts remain private runtime payloads until a later delivery replaces them.

### Implementation direction

Use Bun and TypeScript for the local application. Centralize non-secret option resolution, external-process execution, AWS identity checks and redacted errors. Test orchestration with fake executables and deterministic fixtures; do not require live AWS, Telegram, Kubernetes or network access.

---
id: TECHNE-TOOLS-OPS-001
area: OPS
title: Establish Techne CLI
theme: operations
horizon: next
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: a17546aa15f6f0c914a32c0afdf1c46a15cef5ca
created_at: 2026-09-19T16:51:50Z
updated_at: 2026-09-19T17:47:51Z
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

- [x] Add a private Bun and TypeScript CLI application under `apps/cli` with a `techne` binary, root workspace command and repository-governance coverage for the new TypeScript surface.
- [x] Implement typed non-secret configuration, shell-free process execution, AWS identity and controller-stack inspection, human and JSON output, and deterministic error handling.
- [x] Implement `techne doctor`, `techne controller status` and `techne controller bootstrap`, retaining interactive SSM credential admission without placing secret values in arguments, configuration or logs.
- [x] Replace the standalone bootstrap package and legacy root alias, then update repository orientation and the controller operations guide to use the CLI.
- [x] Add unit and command-level tests using fake executable responses, then run the complete repository and governance gates without contacting live infrastructure.

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

Run `mise exec bun@1.4.1 -- bun run test`, `mise exec bun@1.4.1 -- bun run self:techne -- --help`, focused CLI tests, `ki repo audit --repo .` and `git diff --check`. All must pass without live AWS, Telegram, Kubernetes or network access.

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

## Review

### Delivered

Delivered the agreed first `techne` CLI slice from baseline `a17546aa15f6f0c914a32c0afdf1c46a15cef5ca`: local diagnostics, read-only controller status and the existing private interactive controller bootstrap path. No live infrastructure was contacted or mutated.

### Summary of changes

- Added the private Bun and TypeScript `apps/cli` application with typed configuration, shell-free process execution, human and JSON status output, AWS account protection and Session Manager bootstrap orchestration.
- Added deterministic command tests with fake subprocess responses, including proof that credential-like environment values never enter SSM arguments.
- Removed the standalone `packages/bootstrap` launcher and replaced its package alias with `bun run self:techne -- controller bootstrap`.
- Activated the repository engineering contract and its standard TypeScript, formatting, dependency-analysis and Git-hook configuration for the new source surface.
- Updated the README and controller operations guide to make `techne` the operator entry point while retaining deployable applications and remote runtime scripts.

### Verification

- `mise exec bun@1.4.1 -- bun run test` — passed all four Turborepo tasks; CLI tests passed 8/8 and controller tests passed 14/14.
- `mise exec bun@1.4.1 -- bun run self:techne -- --help` — passed without subprocess or network access.
- `mise exec bun@1.4.1 -- bun run self:techne -- controller status --help` — passed without contacting AWS.
- `mise exec bun@1.4.1 -- bun run --cwd apps/cli build` — bundled the CLI successfully.
- Biome, Knip and Syncpack checks — passed.
- `ki repo audit --repo .` — passed all 14 selected repository skills.
- `git diff --check` — passed.

### Outstanding concerns

The real AWS identity, CloudFormation response and interactive Session Manager path remain intentionally unexercised in automated verification. Controller containerization and migration of the remaining operational scripts are outside this record and need separate work items.

### Post-change review

The implementation stays within the approved boundary. Activating the engineering contract was a required consequence of adding the first TypeScript application; it did not change runtime architecture or live infrastructure.

### Mini recap

Techne now has a tested CLI application and a safe bootstrap command, with the obsolete local bootstrap package removed. Review should focus on the command surface, AWS safety guard and operator wording; follow-on planning should cover controller containerization and the remaining script inventory.

## Discussion

### Initial command surface

The first supported commands should be `techne doctor`, `techne controller status` and `techne controller bootstrap`. Bootstrap may open the existing private interactive SSM session, but credentials must remain confined to that session and must never enter CLI arguments, configuration, logs or retained test evidence.

### Application boundary

The CLI should live under `apps/` alongside the controller and future containerized applications. Shared packages should be introduced only when at least two applications need the same stable contract. Repository-only verification remains development tooling, while scripts executed on controller or target hosts remain private runtime payloads until a later delivery replaces them.

### Implementation direction

Use Bun and TypeScript for the local application. Centralize non-secret option resolution, external-process execution, AWS identity checks and redacted errors. Test orchestration with fake executables and deterministic fixtures; do not require live AWS, Telegram, Kubernetes or network access.

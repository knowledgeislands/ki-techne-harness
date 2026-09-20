---
id: TECHNE-TOOLS-OPS-002
area: OPS
title: Install and diagnose Techne
theme: operations
horizon: next
status: done
blocks: []
blocked_by: []
baseline_ref: fe59ff343d989f112240d620cd371305e66e961d
created_at: 2026-09-20T06:48:20Z
updated_at: 2026-09-20T07:59:32Z
---

# Install and diagnose Techne

## Goal

Make `techne` installable from a local development checkout and as an immutable Homebrew release, while `techne doctor` and `techne diag` clearly explain the active installation and operating mode.

## Context

The CLI currently runs only through the repository package script. Knowledge Islands already has a proven local-development installation pattern in `tools-ki/install.sh --link`: a launcher in `~/.local/bin` executes the checkout source through Bun. The governed `homebrew-tap` repository requires a formula to point at a tagged immutable upstream source or release artifact with a matching checksum.

## Boundary

This work may add the local-link installer, installation provenance, version reporting, diagnostic output, mode-aware health checks, release packaging and verification in Techne Tools. The companion formula, checksum and tap documentation remain owned by `knowledgeislands/homebrew-tap` and must land through a separate tap-local work record after an immutable Techne release exists. Publishing a tag or release and changing the tap require explicit release authority.

## Current state

`apps/cli` is a source-run Bun application at version `0.0.0`. It has controller commands and an AWS-oriented `doctor`, but no stable version command, offline diagnostic report, install script, compiled release contract or GitHub release workflow. The tap has no Techne formula.

## Steps

- [x] Add `v0.1.0` version and installation-provenance contracts, `techne --version`, offline `techne diag`, and mode-aware `techne doctor` output with deterministic tests.
- [x] Add an atomic `install.sh --link` development installer using `${TECHNE_INSTALL_DIR:-$HOME/.local/bin}` and verify the installed launcher against the checkout source.
- [x] Add reproducible per-platform compiled archive packaging and a guarded GitHub release workflow for macOS ARM64, macOS x64 and Linux x64, including checksum generation and installed-binary smoke tests.
- [x] Update repository orientation and controller guidance for local and released installation modes without presenting Homebrew as a separate runtime architecture.
- [x] Run the complete local, packaging, documentation and repository-governance gates without contacting AWS or publishing a release.

## Files touched

- `apps/cli/**`
- `install.sh`
- `release/**`
- `.github/workflows/**`
- `package.json`
- `bun.lock`
- `README.md`
- `docs/guides/controller-proof.md`
- this roadmap record

## Verify

Run `mise exec bun@1.4.1 -- bun run test`, focused installer tests, `techne --version`, offline human and JSON `techne diag`, a current-platform compiled archive smoke test, ShellCheck for new shell scripts, workflow YAML parsing, `ki repo audit --repo .` and `git diff --check`. Verification must not contact AWS, publish a tag or release, or modify the Homebrew tap.

## Dependencies / blocks

No local work-item dependency blocks implementation. Publishing `v0.1.0` follows human acceptance of this delivery. The tap-local formula record depends on that immutable release and its observed archive checksums.

## Documentation impact

### Decision Records

No Decision Record is required: this applies the already established Knowledge Islands local-link and immutable-release distribution pattern without changing Techne architecture.

### Specifications

Installation provenance, diagnostic fields, exit behaviour and archive shape remain executable contracts covered by command, installer and packaging tests.

### Guides

Update the root README with installation choices and the controller guide with mode-aware diagnostic and health-check usage.

### Roadmap

The companion Homebrew formula remains separate tap-owned work and must not be represented as delivered until `v0.1.0` exists and the tap verifies its checksums.

## Review

### Delivered

Delivered the approved local-link, diagnostics and release-packaging boundary from baseline `fe59ff343d989f112240d620cd371305e66e961d`. The local launcher is installed under `~/.local/bin/techne`; no AWS call, tag, GitHub release or tap mutation occurred.

### Summary of changes

- Added `techne --version`, offline human and JSON `techne diag`, explicit `local` and `release` provenance, and mode-aware Doctor checks.
- Added an atomic `install.sh --link` flow that resolves the checkout's mise-pinned Bun `1.4.1` executable and installs into `${TECHNE_INSTALL_DIR:-$HOME/.local/bin}`.
- Added deterministic installer and CLI tests, including non-secret diagnostics, release-mode runtime checks and local Bun-version mismatch reporting.
- Added compiled archive packaging for macOS ARM64, macOS x64 and Linux x64, plus guarded CI and manual release workflows that validate the tag, package version, checksums and artifacts.
- Updated the README and controller guide with local-link, Homebrew, diagnostic and Doctor workflows.

### Verification

- `mise exec bun@1.4.1 -- bun run test` — passed four Turborepo tasks, 14 CLI/installer tests, 14 controller tests and the current-platform compiled release smoke test.
- Installed `~/.local/bin/techne` through `./install.sh --link`; `techne diag --json` reported version `0.1.0`, installation `local` and runtime `Bun 1.4.1`.
- Current-platform release archive executed `--version` and offline `diag --json`, reporting installation `release`.
- ShellCheck passed for all new shell scripts; both GitHub workflow files parsed as YAML.
- Biome, Knip and Syncpack checks passed.
- `ki repo audit --repo .` passed all 14 selected skills.
- `git diff --check` passed.

### Outstanding concerns

The macOS x64 and Linux x64 binaries require their native GitHub Actions runners and have not run locally. CI, tag validation and GitHub release publication cannot execute until the reviewed commit is pushed and accepted. The tap formula remains correctly pending the published `v0.1.0` asset checksums.

### Post-change review

The implementation meets the approved source-repository boundary and keeps diagnostics non-secret and offline. The release workflow is manual, validates an existing exact semantic-version tag on the default-branch ancestry, and publishes only after all three platform jobs succeed. It is ready for human acceptance before publication.

### Mini recap

Techne is locally installed and can explain its installation and configuration without network access. The repository can produce and publish the three immutable `v0.1.0` archives; after acceptance, publish the release, observe its checksums, then implement and verify the tap-owned formula record.

## Done

Accepted 2026-09-20 by Kris Brown on the review packet above.

## Discussion

### Installation modes

Local development should use an explicit `install.sh --link` flow with a `TECHNE_INSTALL_DIR` override and no download. Source execution is `local`; a compiled immutable artifact is `release`. Homebrew is a distribution channel for the release artifact, not a separate runtime architecture.

### Diagnostics

`techne diag` should report version, installation provenance, executable or source entrypoint, working directory and effective non-secret configuration without making network calls. `techne doctor` should turn those facts into actionable checks: Bun is required for a linked source installation, while AWS CLI, Session Manager and account checks remain capability checks for controller operations.

### Homebrew handoff

Do not add a placeholder or floating formula. First establish a reproducible versioned artifact and checksum contract in this repository; then create the corresponding formula and validation evidence in the tap repository.

---
id: TECHNE-TOOLS-OPS-001
area: OPS
title: Establish Techne CLI
theme: operations
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-19T16:51:50Z
updated_at: 2026-09-19T16:51:50Z
---

# Establish Techne CLI

## Goal

Provide a `techne` command-line application as the single operator interface for checking and bootstrapping the retained controller, with consistent configuration, safety checks and terminal output.

## Context

The repository currently exposes controller operations through root package aliases and standalone Bash scripts. Those entry points repeat AWS account verification, region and stack configuration, CloudFormation output lookup and SSM session construction. The monorepo must retain `apps/` for independently runnable products, including containerized applications, while the CLI becomes another application rather than replacing that structure.

The first delivery should prove the application boundary with read-only diagnostics and the existing secure interactive bootstrap path before broader controller, target and container workflows migrate.

## Boundary

This item establishes the CLI application and migrates controller diagnostics and bootstrap orchestration. It does not containerize the controller, migrate target lifecycle commands, remove remote host bootstrap payloads, publish to a package registry, deploy infrastructure or mutate live controller state during verification.

## Discussion

### Initial command surface

The first supported commands should be `techne doctor`, `techne controller status` and `techne controller bootstrap`. Bootstrap may open the existing private interactive SSM session, but credentials must remain confined to that session and must never enter CLI arguments, configuration, logs or retained test evidence.

### Application boundary

The CLI should live under `apps/` alongside the controller and future containerized applications. Shared packages should be introduced only when at least two applications need the same stable contract. Repository-only verification remains development tooling, while scripts executed on controller or target hosts remain private runtime payloads until a later delivery replaces them.

### Implementation direction

Use Bun and TypeScript for the local application. Centralize non-secret option resolution, external-process execution, AWS identity checks and redacted errors. Test orchestration with fake executables and deterministic fixtures; do not require live AWS, Telegram, Kubernetes or network access.

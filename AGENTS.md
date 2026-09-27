# Techne Harness

The Techne Harness is the runnable personal-controller and execution-fabric implementation repository for the Knowledge Islands ecosystem. The independently released `tools-techne` repository owns the `techne` operator interface.

## Authority

Techne Principal owns the architecture, roles, invariants and decision criteria. This repository owns harness applications, packaging, deployment resources, runtime payloads, provider adapters and operational guidance. Do not duplicate or silently redefine canonical architecture here.

## Dependencies

Use Bun `1.4.1` from the repository root. Run dependency installation only at the root. Package manifests may declare tasks and dependencies, but package-local lockfiles and package-local `node_modules` directories are prohibited.

## Secrets and operational state

Never place credentials, kubeconfigs, raw Telegram updates, numeric operator identifiers or provider session material in Git, chat, command arguments, SSM Run Command parameters or retained test evidence. Interactive bootstrap may stream values directly into an authorised runtime secret store after its encryption-at-rest gate passes.

## Change management

Use the local roadmap under `docs/roadmap/` for prospective repository work. Preserve source provenance when moving implementation from another island. Do not push, publish, release or mutate live infrastructure without explicit authority.

## Techne execution hold

New Techné implementation, substantive architecture changes, branch integration and remote rollout are on hold. The programme hold and restart criteria are owned by `ki-techne-principal` in `AGENTS.md`, section `Techne holding position`. Existing Ready records and task approvals do not override the hold. Preserve branches, worktrees, work records and existing services; read-only inspection and explicitly scoped preservation or hold administration may continue. Resume only on the principal's explicit direction after the local Paperclip learning review and remote-delivery policy.

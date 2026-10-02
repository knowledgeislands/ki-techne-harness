# Techne Harness

The Techne Harness is the runnable personal-controller and execution-fabric implementation repository for the Knowledge Islands ecosystem. The independently released `tools-techne` repository owns the `techne` operator interface.

## Authority

Arcadia owns the architecture, roles, invariants and decision criteria. This repository owns harness applications, packaging, deployment resources, runtime payloads, provider adapters and operational guidance. Do not duplicate or silently redefine canonical architecture here. The [implementation ownership decision (ADR-TECHNE-003)](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-TECHNE-003-techne-implementation-ownership.md) defines this boundary.

## Dependencies

Use Bun `1.4.1` from the repository root. Run dependency installation only at the root. Package manifests may declare tasks and dependencies, but package-local lockfiles and package-local `node_modules` directories are prohibited.

## Secrets and operational state

Never place credentials, kubeconfigs, raw Telegram updates, numeric operator identifiers or provider session material in Git, chat, command arguments, SSM Run Command parameters or retained test evidence. Interactive bootstrap may stream values directly into an authorised runtime secret store after its encryption-at-rest gate passes.

## Change management

Use the local roadmap under `docs/roadmap/` for prospective repository work. Preserve source provenance when moving implementation from another island. Do not push, publish, release or mutate live infrastructure without explicit authority.

## Remote-environment hold

There is no general hold on local Techné implementation, architecture work, testing or branch integration. The hold concerns managing remote environments, including remote-agent or infrastructure rollout and changes to running services. Do not treat a Ready record or task approval as authority for remote-environment operations. Preserve existing remote services and state until the principal explicitly authorises their management under a remote-delivery policy. Arcadia owns the programme policy in [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md); that document still needs to be reconciled with this narrowed scope.

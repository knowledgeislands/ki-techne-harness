---
id: TECHNE-TOOLS-OPS-021
area: OPS
title: Owned-host provider
purpose: capability
project: agent-host
component: recipes
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T13:03:25Z
updated_at: 2026-10-08T13:03:25Z
---

# Owned-Host Provider

## Goal

The `direct-host` recipe can bind to a machine the owner already runs and reaches over the tailnet, such as an owned Mac Studio, with no provision step: rebuild resets the operator user's workspace and home over SSH, and withdraw removes the workspace and lists the tailnet device and account footprint for the owner to remove by hand.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) records the agent-host model for any target, cloud or owned, Linux or macOS, and [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) states rebuild and withdraw by intent, with the AWS stack and parameter details only for the AWS provider. The recipe has only `[providers.aws]`. A generic review on 2026-10-08 proposed an owned-host provider (proposal P11) and moving the provider-neutral scripts out of `operations/aws/agent-host/` (proposal P12); Kris approved capturing both the same day, with P12 folded into this record (Decision 12 in the Techne decisions log).

Running an owned host needs a governance decision on the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) first: GDR-KI-ARCADIA-004's exemption covers only the current host. That decision is raised in the `state-of-play` thread and is not decided here. Capture keeps the case in view for the design; plan this record only if an owned host becomes real and that decision is made.

## Boundary

- In scope: a `[providers.tailnet]` (or `owned`) section in `recipes/direct-host/recipe.toml` with no provision step; owned-host rebuild and withdraw scripts honouring the status contract and guard; moving the neutral scripts from `operations/aws/agent-host/` to `operations/direct-host/` (P12); making instance-sized settings such as `KNIP_DISABLE_RAW_TRANSFER` in `host/converge.sh` conditional or provider-supplied; the manifest check and stubbed cases for the new provider.
- Out of scope: the CLI adapter ([TECHNE-TOOL-CLI-007](https://github.com/knowledgeislands/tools-techne/blob/main/docs/roadmap/TECHNE-TOOL-CLI-007-owned-host-adapter.md) in `tools-techne`); the Techne Programme Hold decision; splitting the operator guide (TECHNE-TOOLS-OPS-020); and any remote action.

## Discussion

### Pairing

Paired with [TECHNE-TOOL-CLI-007](https://github.com/knowledgeislands/tools-techne/blob/main/docs/roadmap/TECHNE-TOOL-CLI-007-owned-host-adapter.md) in `tools-techne`, which adds the matching adapter. Neither blocks the other at capture; planning settles the order.

### P12 timing

The script move could land earlier, alongside TECHNE-TOOLS-OPS-019, if planning finds it simpler; it is folded here so it is not lost.

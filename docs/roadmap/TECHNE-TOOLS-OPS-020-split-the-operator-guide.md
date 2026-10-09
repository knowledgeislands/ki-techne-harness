---
id: TECHNE-TOOLS-OPS-020
area: OPS
title: Split the operator guide
purpose: debt
project: agent-host
component: operations
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T13:03:25Z
updated_at: 2026-10-08T13:03:25Z
---

# Split the Operator Guide

## Goal

The agent-host operator guide reads as a guide to the general `agent-host` recipe, with each provider's steps in its own guide and no one binding owner's deployment values in the shared repository.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) and [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) in `ki-arcadia-principal` describe the agent host as a general design: any binding owner, a cloud instance or an owned machine, Linux or macOS. `docs/guides/operator/agent-host.md` still mixes three things: the recipe's general operation, the AWS provider's steps, and Kris's own deployment values (account, region, profile and host names). A generic review on 2026-10-08 proposed splitting it (proposal P10), and Kris approved capturing it the same day (Decision 12 in the Techne decisions log).

## Boundary

- In scope: a generic `agent-host` recipe guide; an AWS provider guide, with placeholders for an owned-host provider guide; moving one binding owner's deployment values out of the shared repository, to that owner's personal configuration source or to Arcadia; updating the operator guide index and the diagrams' references.
- Out of scope: changing the recipe or scripts (TECHNE-TOOLS-OPS-019 removes their person-specific defaults); the owned-host provider itself ([TECHNE-TOOLS-OPS-021](https://github.com/knowledgeislands/ki-techne-harness/blob/main/docs/roadmap/TECHNE-TOOLS-OPS-021-owned-host-provider.md)); and any remote action.

## Discussion

### Sequencing

Best done after TECHNE-TOOLS-OPS-019, which removes the same values from the scripts, so the guides and the scripts change their wording once. That is ordering, not a dependency.

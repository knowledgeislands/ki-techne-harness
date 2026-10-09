---
id: TECHNE-TOOLS-OPS-019
area: OPS
title: Person-neutral recipe defaults
purpose: debt
project: agent-host
component: operations
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T08:55:00Z
updated_at: 2026-10-09T15:19:58Z
---

# Person-Neutral Recipe Defaults

## Goal

The `agent-host` recipe and its scripts carry no one person's values: every person-specific value comes from the binding through the CLI, or from an explicit test fixture, so a second binding owner can run setup with their own repositories, payload and shell without editing the recipe. The recipe states how a binding personalises it: the binding names a profile payload source and a shell, and the recipe applies them without naming any person.

## Context

A generic review of the agent-host design on 2026-10-08 found that the scripts default every value to one binding (account, region, profile names, host name), and that `tooling/checks/recipe-manifest.py`'s `check_binding_defaults` requires each default to equal that live binding's value, while [ADR-KI-ARCADIA-006](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-006-techne-implementation-ownership.md) forbids person-specific defaults. One person's repository selection and workspace layout are the recipe's defaults (`host/repositories.txt`, `[parameters.workspace]`), and `setup.sh` requires `chezmoi` on the operator's workstation, renders a fixed list of personal instruction files (`AGENT_HOST_INSTRUCTIONS`) with `chezmoi cat`, and says whose instructions they are. Kris approved the change on 2026-10-08 as proposal P8, with the note that the shell is a per-binding choice whose recipe default is zsh.

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the general model: the recipe applies a binding owner's profile payload if one is supplied, without naming any person, and the interactive shell comes from an optional binding field `shell`.

## Boundary

- In scope: removing person-specific defaults from `setup.sh`, `provision.sh`, `stop.sh`, `status.sh`, `destroy.sh` and `recipe.toml`; changing `check_binding_defaults` to check a fixture binding rather than a live one; shipping `repositories.txt` as an example; declaring optional binding fields `repositories`, `profile` (the payload source) and `shell` (default zsh) in the recipe, with a short note in the recipe and the operator guide on how a binding uses them to personalise a host; and the operator guide's matching lines.
- Out of scope: removing the `AGENT_HOST_INSTRUCTIONS` list, the `chezmoi cat` path and the `chezmoi` requirement from `setup.sh`, together with the payload hook and its contract (TECHNE-TOOLS-OPS-015); the shell hand-off (TECHNE-TOOLS-OPS-015) and the provider's login shell (TECHNE-TOOLS-OPS-017); the binding schema and CLI in `tools-techne`, which needs a paired record for the new fields; splitting the operator guide or moving the neutral scripts out of `operations/aws/` (TECHNE-TOOLS-OPS-020 and TECHNE-TOOLS-OPS-021); and any remote action.

## Discussion

### Sequencing

It starts after TECHNE-TOOLS-OPS-013, which edits the same scripts, is accepted; that is ordering, not a dependency.

### Pairing

TECHNE-TOOLS-OPS-015 owns the `chezmoi cat` removal, so that it lands with the payload hook and personal instructions always have one route; Kris confirmed this split on 2026-10-09 (Decision 24(c) in the Techne decisions log). This record keeps the binding fields and the other person-specific defaults, and its `profile` field names the payload source that TECHNE-TOOLS-OPS-015's hook applies. Neither record blocks the other: if this record lands first, `setup.sh` keeps its current personal-instruction route until TECHNE-TOOLS-OPS-015 replaces it. The new binding fields need a paired `tools-techne` binding-schema record, to be handed off when this record is planned.

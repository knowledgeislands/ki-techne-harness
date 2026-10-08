---
id: TECHNE-TOOLS-OPS-017
area: OPS
title: Binding shell at rebuild
purpose: debt
project: agent-host
component: infra
status: triage
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-015]
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-08T08:55:00Z
---

# Binding Shell at Rebuild

## Goal

The agent host's `techne` user has the binding's chosen shell (zsh by default) as its login shell from the provider itself, so the guarded `.bashrc` hand-off can be retired.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 4, as generalised on 2026-10-08 (generic-review proposal P6, approved by Kris with zsh as the default), makes the interactive shell a per-binding choice: the binding's optional `shell` field names it and the recipe's default is zsh. The workstation pilot (TECHNE-TOOLS-OPS-015) delivers it now through a guarded hand-off from `.bashrc`; where the provider sets the login shell, it sets the binding's shell at the next rebuild that happens for another reason.

On the AWS provider the stack creates `techne` with `/bin/bash`, hard-coded, and the user cannot `chsh`. A rebuild costs a fresh Tailscale key and removal of the old device, so no rebuild is made for this change alone.

## Boundary

- In scope: the AWS stack's boot script creating the `techne` user with the binding's shell (default zsh) rather than a hard-coded one, passed through the provider's parameters; retiring the hand-off guard once a rebuilt host runs the binding's shell as its login shell; and the shell-path tests carried over from the pilot.
- Out of scope: triggering a rebuild, which the binding owner runs; the binding field itself (TECHNE-TOOLS-OPS-019); a login-shell change for any other provider.

## Discussion

Folded into the next rebuild that happens for another reason; until then it stays in triage.

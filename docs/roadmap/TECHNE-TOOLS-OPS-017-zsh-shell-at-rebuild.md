---
id: TECHNE-TOOLS-OPS-017
area: OPS
title: Zsh shell at rebuild
purpose: debt
project: agent-host
component: infra
status: triage
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-015]
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-08T07:32:00Z
---

# Zsh Shell at Rebuild

## Goal

The agent host's `techne` user has zsh as its login shell from the stack itself, so the guarded `.bashrc` hand-off can be retired.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 4 makes zsh the interactive shell now through a guarded hand-off from `.bashrc` to `zsh -l`, delivered in the workstation pilot (TECHNE-TOOLS-OPS-015), and sets `--shell /bin/zsh` in the stack at the next rebuild that happens for another reason.

The stack creates `techne` with `/bin/bash` and the user cannot `chsh`. A rebuild costs a fresh Tailscale key and removal of the old device, so no rebuild is made for this change alone.

## Boundary

- In scope: `--shell /bin/zsh` for the `techne` user in the stack's boot script, retiring the hand-off guard once a rebuilt host runs zsh as its login shell, and the shell-path tests carried over from the pilot.
- Out of scope: triggering a rebuild; the binding owner runs every live rebuild.

## Discussion

Folded into the next rebuild that happens for another reason; until then it stays in triage.

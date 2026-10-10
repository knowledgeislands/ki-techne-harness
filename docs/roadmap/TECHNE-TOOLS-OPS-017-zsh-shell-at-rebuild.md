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
updated_at: 2026-10-10T16:41:47Z
---

# Binding Shell at Rebuild

## Goal

The agent host's `techne` user has the binding's chosen shell (zsh by default) as its login shell from the provider itself, so the guarded `.bashrc` hand-off can be retired. The same rebuild renames the host to `vega` and removes the record identifiers that remain in the host's live artefacts.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 4, as generalised on 2026-10-08 (generic-review proposal P6, approved by Kris with zsh as the default), makes the interactive shell a per-binding choice: the binding's optional `shell` field names it and the recipe's default is zsh. The workstation pilot (TECHNE-TOOLS-OPS-015) delivers it now through a guarded hand-off from `.bashrc`; where the provider sets the login shell, it sets the binding's shell at the next rebuild that happens for another reason.

On the AWS provider the stack creates `techne` with `/bin/bash`, hard-coded, and the user cannot `chsh`. A rebuild costs a fresh Tailscale key and removal of the old device, so no rebuild is made for this change alone.

On 2026-10-09 Kris named the AWS agent host `vega` under his machine-naming convention: physical machines take solar-system names, peripherals are moons, and a non-physical host takes its own star system (Decision 29(a) in the Techne thread's decisions log). Setting the OS hostname needs root, which the `techne` user lacks, and a new Tailscale name means a new device, so the rename lands at the same rebuild. Until then the bundle carries no `target_host` (TECHNE-TOOLS-OPS-015).

Record identifiers also sit in live artefacts that outlast their records, and records are pruned. `converge.sh` writes and searches for a start-up marker that names TECHNE-TOOLS-OPS-011 in `.profile`, `.bashrc` and the Husky start-up file. The instance's boot script names TECHNE-TOOLS-OPS-022 in comments, in an apt configuration file it writes and in the reboot unit's description. The stack's `ki-work-item` tags and its description, `provision.sh`, the recipe's provider tags and the operator guide name KI-ARCADIA-GOV-020, and the guide also names KI-ARCADIA-GOV-023. Tags and the description change only through a stack update and the boot script only on a new instance, so their removal waits for this rebuild.

## Boundary

- In scope: the AWS stack's boot script creating the `techne` user with the binding's shell (default zsh) rather than a hard-coded one, passed through the provider's parameters; retiring the hand-off guard once a rebuilt host runs the binding's shell as its login shell; and the shell-path tests carried over from the pilot.
- In scope: renaming the host to `vega` everywhere the name lives — the OS hostname, the Tailscale device name, the operator's SSH alias and its known_hosts file, the AWS `Name` tag, the binding's host name, and the personal bundle's manifest with its `target_host`. Parts owned by another repository, such as the binding and SSH configuration in chezmoi, go there as handoffs.
- In scope: removing those identifiers from the agent-host stack (resource tags, description, boot script and reboot unit), `provision.sh`, the recipe, `converge.sh`'s start-up marker, the offline checks and the operator guide. The new marker names no record. `converge.sh` still recognises the old marker, and the hand-made `mise shims` block, by pattern rather than by the record's name, so on a host converged before the rebuild it replaces the old block instead of adding a second; the rebuilt host only ever carries the new marker.
- Out of scope: triggering a rebuild, which the binding owner runs; the binding field itself (TECHNE-TOOLS-OPS-019); a login-shell change for any other provider.

## Discussion

Folded into the next rebuild that happens for another reason; until then it stays in triage.

---
id: TECHNE-TOOLS-OPS-015
area: OPS
title: Agent-host workstation pilot
kind: deliver
purpose: capability
project: agent-host
component: operations
horizon: next
status: draft
blocks: [TECHNE-TOOLS-OPS-017]
blocked_by: [TECHNE-TOOLS-OPS-013, TECHNE-TOOLS-OPS-014]
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-08T08:55:00Z
---

# Agent-Host Workstation Pilot

## Goal

A session on the agent host works like the binding owner's own workstation for a first, minimal slice: the recipe applies the owner's profile payload when one is supplied, the owner's personal tools install through Rig with one tool first, interactive sessions run the binding's chosen shell (zsh by default) with the host environment, and both Claude and Codex follow instructions that match what the host can do.

## Context

This is the harness half of the agent-host workstation pilot, paired for the current binding with DOTFILES-UE-073, Kris's Cheztoi record in a chezmoi source, which supplies the payload this record applies. The record names no person: any binding owner's payload uses the same hook. [ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the workstation model; Kris Brown approved it on 2026-10-08, accepting all seven recommended decisions, and on the same day approved the generic-review proposals P6 and P9, which make the shell a per-binding choice with zsh as the recipe default and the payload hook the only route for personal instructions.

- **Payload contract.** The harness applies "the binding owner's profile payload if one is supplied", naming no person. The payload carries a revision, file ownership and permissions, removal of files dropped from the allowlist, and validation of rendered contents for secrets, paths invalid on the target OS and managed resources, refusing a Rig fragment that declares any. Delivery is pull-on-demand through `techne host setup`. The hook is the only route for personal instructions: `setup.sh`'s `chezmoi cat` rendering of `AGENT_HOST_INSTRUCTIONS` is removed, not generalised beside it.
- **Personal tools through Rig.** After stage 1 (TECHNE-TOOLS-OPS-014) installs Rig at a pinned tag, `rig apply` installs the owner's profile from the delivered `conf.d` fragment, one tool first; for the current binding that is `mgit`, which works by discovery only on the host, because its workspace manifests are not delivered.
- **Shell (decision 4, P6).** The interactive shell is a per-binding choice: the binding's optional `shell` field names it and the recipe's default is zsh. The recipe installs the chosen shell, keeps `env.sh` sourceable from any shell, and adds a guarded hand-off from `.bashrc` to the chosen shell as a login shell, whose startup files source `env.sh`; when the chosen shell is bash, no hand-off is made. Login, interactive, non-interactive SSH and Git-hook shells, and mise environments, are each tested. The provider's own login-shell change waits for the next rebuild (TECHNE-TOOLS-OPS-017).
- **Instructions.** The Claude and Codex instruction files come from the payload; the delegation instructions are the host variant without detached agents (decision 5).
- **No new binaries but Rig (decision 6).** Neither `techne` nor any personal-configuration tool is installed on the host.

## Boundary

- In scope: the person-neutral payload hook in `setup.sh` and `converge.sh` with the contract above; `rig apply` for the owner's delivered fragment; the binding's shell with the zsh default, the guarded hand-off and its shell-path tests; personal-tool drift in `status.sh`; operator guide corrections - recovery of profile and runtime state by re-running setup from the operator's workstation, and removal of references to the retired `techne-agent-host` helper.
- Out of scope: the Cheztoi allowlist and renderer (DOTFILES-UE-073); the recipe's Rig profile and drift check (TECHNE-TOOLS-OPS-014); the `ki` provider (TECHNE-TOOLS-OPS-016) and moving `converge.sh`'s installs to Rig (TECHNE-TOOLS-OPS-018); the provider's login-shell change (TECHNE-TOOLS-OPS-017); the remaining person-specific defaults and the binding fields themselves (TECHNE-TOOLS-OPS-019); passing a profile through `techne host setup` and showing personal-tool drift in `techne host status` in `tools-techne`; any credential, unattended process or writing-checkout marker; and any remote action, which is the binding owner's alone.

## Current state

Captured and selected as the workstation pilot on 2026-10-08 under Kris's grant; not yet planned. Reshaped on 2026-10-08 for the generic-review proposals P6 and P9; still not planned. `setup.sh` renders `AGENT_HOST_INSTRUCTIONS` into `~/.claude` with `chezmoi cat`, and no other personal payload reaches the host. The stack creates `techne` with `/bin/bash`, and `converge.sh` writes `.profile` and `.bashrc`. Rig is not on the host until stage 1. The operator guide still refers to the retired `techne-agent-host` helper.

## Steps

- [ ] Define the person-neutral payload contract and hook in `setup.sh` and `converge.sh`: revision, ownership and permissions, removal, content validation against the target OS and refusal of managed resources; remove the `chezmoi cat` path so the hook is the only route for personal instructions.
- [ ] Apply the owner's delivered Rig fragment with `rig apply` and report personal-tool drift in `status.sh`.
- [ ] Read the binding's `shell` (default zsh), install it, add the guarded `.bashrc` hand-off to it as a login shell, source `env.sh` from its startup files, and test login, interactive, non-interactive SSH, Git-hook and mise-environment shells for zsh and for bash.
- [ ] Update the operator guide: recovery of profile and runtime state by re-running setup, and removal of the retired helper's references.
- [ ] Add offline checks with stubs for payload apply, removal, validation refusal (including a path invalid on the target OS) and the shell paths.

## Files touched

- `operations/aws/agent-host/setup.sh`, `operations/aws/agent-host/host/converge.sh`, `operations/aws/agent-host/host/status.sh` and the host's shell startup material
- `recipes/direct-host/recipe.toml`
- `tooling/checks/` scripts and fixtures for the new cases
- `docs/guides/operator/agent-host.md`
- This record

## Verify

- `bun run test` and the repository's checks pass, including the new stubbed payload and shell cases.
- `ki repo audit --repo .` passes.
- On the host, after the binding owner runs setup with a DOTFILES-UE-073 payload: the payload's first tool (`mgit` for the current binding) is installed through Rig, a new SSH session lands in the binding's shell (zsh by default) with the host environment, and status reports no personal-tool drift.

## Dependencies / blocks

Blocked by TECHNE-TOOLS-OPS-013, the durability pilot, and TECHNE-TOOLS-OPS-014, which installs Rig. Paired for the current binding with DOTFILES-UE-073 in Kris's chezmoi source. Blocks TECHNE-TOOLS-OPS-017. Lands together with TECHNE-TOOLS-OPS-019's removal of the person-specific instruction defaults; neither blocks the other.

## Documentation impact

### Decision Records

None in this repository: ADR-KI-ARCADIA-003 in `ki-arcadia-principal` records the model.

### Specifications

The payload contract is a new contract between the harness and the binding owner's source, carried by `recipe.toml`; no separate specification.

### Guides

`docs/guides/operator/agent-host.md`, as listed in Steps.

### Roadmap

The pilot's lessons are written into TECHNE-TOOLS-OPS-016 and TECHNE-TOOLS-OPS-018 before they start.

## Discussion

### Sequencing

Selected as the workstation pilot on 2026-10-08 under Kris's grant. It starts after the durability pilot, TECHNE-TOOLS-OPS-013, which edits `converge.sh`, `status.sh` and the rebuild path, and after stage 1 in TECHNE-TOOLS-OPS-014. It is planned and delivered together with DOTFILES-UE-073; the wider allowlist waits for its lessons.

### Open for planning

Whether `techne host setup` needs a profile argument, and therefore a `tools-techne` record, is settled when this record is planned.

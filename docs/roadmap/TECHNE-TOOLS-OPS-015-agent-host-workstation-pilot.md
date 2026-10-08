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
updated_at: 2026-10-08T07:32:00Z
---

# Agent-Host Workstation Pilot

## Goal

A session on the agent host works like the binding owner's own machine for a first, minimal slice: the recipe applies the owner's profile payload when one is supplied, the owner's personal tools install through Rig with `mgit` first, interactive sessions run zsh with the host environment, and both Claude and Codex follow instructions that match what the host can do.

## Context

This is the harness half of the agent-host workstation pilot, paired with the chezmoi Cheztoi record DOTFILES-UE-073 in the binding owner's chezmoi source, which supplies the payload this record applies. [ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the workstation model; Kris Brown approved it on 2026-10-08, accepting all seven recommended decisions.

- **Payload contract.** The harness applies "the binding owner's profile payload if one is supplied", naming no person. The payload carries a revision, file ownership and permissions, removal of files dropped from the allowlist, and validation of rendered contents for secrets, Mac-only paths and managed resources, refusing a Rig fragment that declares any. Delivery is pull-on-demand through `techne host setup`; `setup.sh` already renders `AGENT_HOST_INSTRUCTIONS` with `chezmoi cat`, and that `claude/` payload generalises into the profile payload.
- **Personal tools through Rig.** After stage 1 (TECHNE-TOOLS-OPS-014) installs Rig at a pinned tag, `rig apply` installs the owner's profile from the delivered `conf.d` fragment, `mgit` first. `mgit` works by discovery only on the host, because its workspace manifests are not delivered.
- **Shell (decision 4).** A guarded hand-off from `.bashrc` to `zsh -l` for interactive sessions, with zsh's startup files sourcing `env.sh`. Login, interactive, non-interactive SSH and Git-hook shells, and mise environments, are each tested. The stack's own `--shell /bin/zsh` waits for the next rebuild (TECHNE-TOOLS-OPS-017).
- **Instructions.** The Claude and Codex instruction files come from the payload; the delegation instructions are the host variant without detached agents (decision 5).
- **No new binaries but Rig (decision 6).** Neither `techne` nor `chezmoi` is installed on the host.

## Boundary

- In scope: the person-neutral payload hook in `setup.sh` and `converge.sh` with the contract above; `rig apply` for the owner's delivered fragment; the guarded zsh hand-off and its shell-path tests; personal-tool drift in `status.sh`; operator guide corrections - recovery of profile and runtime state by re-running setup from the Mac, and removal of references to the retired `techne-agent-host` helper.
- Out of scope: the Cheztoi allowlist and renderer (DOTFILES-UE-073); the recipe's Rig profile and drift check (TECHNE-TOOLS-OPS-014); the `ki` provider (TECHNE-TOOLS-OPS-016) and moving `converge.sh`'s installs to Rig (TECHNE-TOOLS-OPS-018); the stack's shell change (TECHNE-TOOLS-OPS-017); passing a profile through `techne host setup` and showing personal-tool drift in `techne host status` in `tools-techne`; any credential, unattended process or writing-checkout marker; and any remote action, which is the binding owner's alone.

## Current state

Captured and selected as the workstation pilot on 2026-10-08 under Kris's grant; not yet planned. `setup.sh` renders `AGENT_HOST_INSTRUCTIONS` into `~/.claude` with `chezmoi cat`, and no other personal payload reaches the host. The stack creates `techne` with `/bin/bash`, and `converge.sh` writes `.profile` and `.bashrc`. Rig is not on the host until stage 1. The operator guide still refers to the retired `techne-agent-host` helper.

## Steps

- [ ] Define the person-neutral payload contract and hook in `setup.sh` and `converge.sh`: revision, ownership and permissions, removal, content validation and refusal of managed resources.
- [ ] Apply the owner's delivered Rig fragment with `rig apply` and report personal-tool drift in `status.sh`.
- [ ] Add the guarded `.bashrc` hand-off to `zsh -l`, source `env.sh` from zsh's startup files, and test login, interactive, non-interactive SSH, Git-hook and mise-environment shells.
- [ ] Update the operator guide: recovery of profile and runtime state by re-running setup, and removal of the retired helper's references.
- [ ] Add offline checks with stubs for payload apply, removal, validation refusal and the shell paths.

## Files touched

- `operations/aws/agent-host/setup.sh`, `operations/aws/agent-host/host/converge.sh`, `operations/aws/agent-host/host/status.sh` and the host's shell startup material
- `recipes/direct-host/recipe.toml`
- `tooling/checks/` scripts and fixtures for the new cases
- `docs/guides/operator/agent-host.md`
- This record

## Verify

- `bun run test` and the repository's checks pass, including the new stubbed payload and shell cases.
- `ki repo audit --repo .` passes.
- On the host, after the binding owner runs setup with a DOTFILES-UE-073 payload: `mgit` is installed through Rig, a new SSH session lands in zsh with the host environment, and status reports no personal-tool drift.

## Dependencies / blocks

Blocked by TECHNE-TOOLS-OPS-013, the durability pilot, and TECHNE-TOOLS-OPS-014, which installs Rig. Paired with DOTFILES-UE-073 in the binding owner's chezmoi source. Blocks TECHNE-TOOLS-OPS-017.

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

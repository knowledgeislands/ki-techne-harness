---
id: TECHNE-TOOLS-OPS-014
area: OPS
title: Agent-host pins and expiries
status: triage
blocks: [TECHNE-TOOLS-OPS-015, TECHNE-TOOLS-OPS-018]
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T20:50:00Z
updated_at: 2026-10-08T08:55:00Z
---

# Agent-Host Pins and Expiries

## Goal

The agent host can be reproduced with known tool versions from the host alone, the operator sees approaching credential expiries without looking for them, both Claude and Codex on the host follow the recipe's own working rules, and the host is marked as a checkout that must not write roadmap records.

## Context

This is the harness's wave-2 record in the agent-host durability rollout. Kris Brown approved the design on 2026-10-07; [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) in `ki-arcadia-principal` records it, with the merged report and decisions in that collection's `references/agent-host-durability-*` files.

- **Pins (decision 7).** One harness file - the recipe's Rig fragment, below - declares exact versions for `ki`, mise, Bun, Node and Codex and a minimum for Claude Code, bumped by ordinary commits, with `ki` moving to the current release. `converge.sh` applies the global pins and leaves each repository's `mise.toml` alone. `status.sh` reports drift from the pins and, when run from the operator's workstation, from that machine's versions as a signal only. `converge.sh` currently selects Node by major version only.
- **Rig profile (workstation stage 1).** [ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal`, approved by Kris Brown on 2026-10-08, folds the first stage of the workstation model into this record. The pin file is the recipe's Rig fragment declaring the `direct-host` profile with a variant for each target OS (Linux for the current host, macOS when an owned Mac is a target) and no managed resources, and the recipe names it. `converge.sh` installs Rig at a pinned tag and keeps installing the tools itself, at the declared pins; `status.sh` reports drift through `rig status --profile direct-host --format json`. This is Rig's first proof on a real Linux host, the current host's OS: its Linux coverage today is Bats with faked native commands, and how the mise pins are expressed - Rig locators or the native mise manifest Rig observes - is settled when this record is planned. Moving the installs themselves to `rig apply` is TECHNE-TOOLS-OPS-018.
- **Expiries.** The status run writes a cached expiry file covering the GitHub token, the Tailscale key and pin drift. An interactive login prints a banner from the cache with no network or credential call. The exemption review-date line is removed from `host/status.sh`: the exemption has no fixed review date, so host status shows none.
- **Recipe instructions (P7).** `setup.sh` renders the binding owner's personal `~/.claude` files and no Codex `AGENTS.md`, so the working rules reach only one of the host's two runtimes, and only when the owner supplies them. The recipe itself renders a small host-instructions file for both Claude and Codex carrying the two-checkout rule and the writing-checkout rule, as [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) now records, so a host without a personal payload still carries them. The binding owner's personal source adds only its own wording.
- **Host marker (decision 6).** The checkout on the operator's workstation is the designated roadmap writing checkout for every Knowledge Islands repository. `converge.sh` sets a host marker that `ki` honours; until `tools-ki` enforces it, the rule sits in the recipe's host instructions.

## Boundary

- In scope: the declared pin file as the recipe's `direct-host` Rig fragment, its application, installing Rig at a pinned tag, drift reporting through `rig status`, the cached expiry file and login banner, removing the review-date line from host status, the recipe's own host instructions for both Claude and Codex, and the host marker.
- Out of scope: the status contract, guards and operations (TECHNE-TOOLS-OPS-013, the pilot, which goes first); the `ki` refusal itself, which belongs to `tools-ki`; the binding owner's personal wording of the rules (for Kris, DOTFILES-UE-072); installing personal tools, and the owner's profile payload and instructions it carries (the workstation pilot, TECHNE-TOOLS-OPS-015); `rig apply` for the shared tools (TECHNE-TOOLS-OPS-018); the `techne` binary and any personal-configuration tool, which the host does not get; and any remote action.

## Discussion

### Sequencing

This record starts only after the pilot, TECHNE-TOOLS-OPS-013, is delivered and its lessons are written into this brief. It may split into a pins record and an expiries-and-instructions record when planned.

### Review date

The exemption review it was to show, `KI-ARCADIA-GOV-021`, was decided early as keep and is accepted. Kris decided on 2026-10-07 (Decision 6 of the Techne run's decisions log) that the exemption has no fixed review date and is revisited when the Techne Programme Hold is reshaped, so host status stops showing a review date rather than reading one from the binding.

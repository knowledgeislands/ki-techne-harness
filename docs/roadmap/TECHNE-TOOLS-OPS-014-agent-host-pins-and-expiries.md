---
id: TECHNE-TOOLS-OPS-014
area: OPS
title: Agent-host pins and expiries
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T20:50:00Z
updated_at: 2026-10-08T07:22:00Z
---

# Agent-Host Pins and Expiries

## Goal

The agent host can be reproduced with known tool versions from the host alone, the operator sees approaching credential expiries without looking for them, both Claude and Codex on the host follow the same working rules, and the host is marked as a checkout that must not write roadmap records.

## Context

This is the harness's wave-2 record in the agent-host durability rollout. Kris Brown approved the design on 2026-10-07; [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) in `ki-arcadia-principal` records it, with the merged report and decisions in that collection's `references/agent-host-durability-*` files.

- **Pins (decision 7).** One harness file declares exact versions for `ki`, mise, Bun, Node and Codex and a minimum for Claude Code, bumped by ordinary commits, with `ki` moving to the current release. `converge.sh` applies the global pins and leaves each repository's `mise.toml` alone. `status.sh` reports drift from the pins and, when run from the Mac, from the Mac's versions as a signal only. `converge.sh` currently selects Node by major version only.
- **Expiries.** The status run writes a cached expiry file covering the GitHub token, the Tailscale key and pin drift. An interactive login prints a banner from the cache with no network or credential call. The exemption review-date line is removed from `host/status.sh`: the exemption has no fixed review date, so host status shows none.
- **Codex instructions.** `setup.sh` renders five `~/.claude` files and no Codex `AGENTS.md`, so the operator's rules reach only one of the host's two runtimes, and the rendered files carry Mac-only tooling.
- **Host marker (decision 6).** The Mac checkout is the designated roadmap writing checkout for every Knowledge Islands repository. `converge.sh` sets a host marker that `ki` honours; until `tools-ki` enforces it, the rule sits in the host's rendered instructions.

## Boundary

- In scope: the declared pin file and its application, drift reporting, the cached expiry file and login banner, removing the review-date line from host status, Codex instructions rendered by `setup.sh`, and the host marker.
- Out of scope: the status contract, guards and operations (TECHNE-TOOLS-OPS-013, the pilot, which goes first); the `ki` refusal itself, which belongs to `tools-ki`; the two-checkout rule's text in the operator's chezmoi source; installing `mgit`, `techne` or chezmoi on the host, which awaits Kris's decision; and any remote action.

## Discussion

### Sequencing

This record starts only after the pilot, TECHNE-TOOLS-OPS-013, is delivered and its lessons are written into this brief. It may split into a pins record and an expiries-and-instructions record when planned.

### Review date

The exemption review it was to show, `KI-ARCADIA-GOV-021`, was decided early as keep and is accepted. Kris decided on 2026-10-07 (Decision 6 of the Techne run's decisions log) that the exemption has no fixed review date and is revisited when the Techne Programme Hold is reshaped, so host status stops showing a review date rather than reading one from the binding.

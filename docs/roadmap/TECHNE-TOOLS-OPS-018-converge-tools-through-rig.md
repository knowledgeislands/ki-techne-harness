---
id: TECHNE-TOOLS-OPS-018
area: OPS
title: Converge tools through Rig
purpose: debt
project: agent-host
component: operations
status: triage
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-016]
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-09T18:25:06Z
---

# Converge Tools Through Rig

## Goal

The agent host's shared tools - Bun, Node, Codex and `ki` - are installed by `rig apply --profile agent-host` from the recipe's one declaration, rather than by `converge.sh`'s own install steps.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 2 stages Rig: stage 1 (TECHNE-TOOLS-OPS-014) declares the `agent-host` profile and observes drift through `rig status`; the pilot installs personal tools through Rig; this record is stage 3.

This record is gated. It starts only when both conditions hold:

1. Rig can install `ki`'s signed release, through the provider in TECHNE-TOOLS-OPS-016.
2. Stage 1's `rig status` has reported clean on the host through at least one pin bump.

`converge.sh` keeps bootstrapping Rig and mise at pinned versions, because Rig does not bootstrap the managers it drives. Claude Code stays installed by the stack's boot script and observed against its declared minimum.

## Boundary

- In scope: replacing `converge.sh`'s Bun, Node, Codex and `ki` installs with `rig apply --profile agent-host`; generating or checking the global mise manifest from the same declaration so one file stays authoritative; offline tests; the operator guide.
- Out of scope: Rig and mise bootstrap; Claude Code's install; Git settings, startup files, the repository set, `ki bootstrap`, the registry and projections, and Claude settings, which are not tool installs and stay in `converge.sh`; any live remote action.

## Discussion

This record stays in triage until both gate conditions hold; the lessons of the pilot and of stage 1 are written into it before it is adopted.

Lessons from the workstation pilot, TECHNE-TOOLS-OPS-015, on 2026-10-09: `rig apply` counts a tool it only re-verifies as completed, so its `completed=` summary cannot tell a change from none. `converge.sh` reads `rig status --profile <profile> --format json` before the apply and reports a change only when a tool was not already present; the shared tools should follow the same pattern. Run Rig with `RIG_PROGRESS=never` and stdin closed, as the pilot does, so its output stays parseable over SSH.

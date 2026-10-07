---
id: TECHNE-TOOLS-OPS-010
area: OPS
title: Diagram the agent-host runbook
theme: operations
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T05:00:00Z
updated_at: 2026-10-07T05:00:00Z
---

# Diagram the Agent-Host Runbook

## Goal

The agent-host runbook shows what is built and how one working session runs, as two diagrams embedded and explained in `docs/guides/operator/agent-host.md`, each with its editable source beside it.

## Context

During the `KI-ARCADIA-GOV-020` work four Archify diagrams were drafted outside any repository. On 2026-10-07 Kris asked for them to be filed, and approved in principle this split: the concept map and the rollout in `ki-arcadia-principal` (`KI-ARCADIA-GOV-022`), and the architecture and the session sequence here, beside the runbook they illustrate. Kris's instruction is the approval to enact this record.

The architecture draft was updated after operator access became an account-local IAM role, `ki-techne-agent-host-operator`, matching the runbook's "Operator access" section.

## Boundary

- In scope: the architecture and session diagrams as Archify JSON sources and SVG exports in `docs/guides/operator/`, and two short sections in the runbook that embed and explain them.
- Out of scope: any change to the stack, scripts, checks or the runbook's procedures; the generated Archify HTML, which is not committed; the concept map and rollout, which Arcadia files; any AWS, Tailscale or GitHub call.

## Current state

The runbook is text only. Nothing in the repository depicts the agent host.

## Steps

- [ ] Add `agent-host-architecture.archify.json` and `agent-host-architecture.svg` beside the runbook, from the current draft.
- [ ] Add `agent-host-session.archify.json` and `agent-host-session.svg` beside the runbook, from the current draft.
- [ ] Add an "At a glance" section after the runbook's introduction embedding the architecture, and a "A working session" section after "Credentials on the host" embedding the session, each explaining its diagram.
- [ ] Run the local gates.

## Files touched

- `docs/guides/operator/agent-host-architecture.archify.json` (new)
- `docs/guides/operator/agent-host-architecture.svg` (new)
- `docs/guides/operator/agent-host-session.archify.json` (new)
- `docs/guides/operator/agent-host-session.svg` (new)
- `docs/guides/operator/agent-host.md`
- This record

## Verify

`archify finalize` passes every gate from both committed sources; `bun run test`, `bunx biome check .`, `bunx rumdl check .`, `ki repo audit --repo .` and `git diff --check` pass; the runbook diff adds the two sections only.

## Dependencies / blocks

None. `KI-ARCADIA-GOV-022` in `ki-arcadia-principal` files the other two diagrams independently.

## Documentation impact

### Decision Records

None.

### Specifications

None.

### Guides

The operator runbook gains two embedded diagrams with explanations.

### Roadmap

None beyond this record.

## Discussion

### Placement - 2026-10-07

The images sit beside the runbook they illustrate, so the guide embeds them by relative path and they render on GitHub and in any Markdown viewer. The SVG exports follow the reader's light or dark theme and embed their font.

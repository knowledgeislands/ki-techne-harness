---
id: TECHNE-TOOLS-OPS-010
area: OPS
title: Diagram the agent-host runbook
theme: operations
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: f0e7fa031b72c72346986210099d87497c0ee8b2
created_at: 2026-10-07T05:00:00Z
updated_at: 2026-10-07T06:32:16Z
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

- [x] Add `agent-host-architecture.archify.json` and `agent-host-architecture.svg` beside the runbook, from the current draft.
- [x] Add `agent-host-session.archify.json` and `agent-host-session.svg` beside the runbook, from the current draft.
- [x] Add an "At a glance" section after the runbook's introduction embedding the architecture, and a "A working session" section after "Credentials on the host" embedding the session, each explaining its diagram.
- [x] Run the local gates.

## Files touched

- `docs/guides/operator/agent-host-architecture.archify.json` (new)
- `docs/guides/operator/agent-host-architecture.svg` (new)
- `docs/guides/operator/agent-host-session.archify.json` (new)
- `docs/guides/operator/agent-host-session.svg` (new)
- `docs/guides/operator/agent-host.md`
- `biome.json` (added during delivery; see Change Summary)
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

## Review

### Delivered

The approved boundary: the architecture and session diagrams beside the runbook, as Archify sources and SVG exports, and two runbook sections that embed and explain them. Excluded, as planned: any change to the stack, scripts, checks or procedures, the generated HTML, and the concept map and rollout, which `KI-ARCADIA-GOV-022` files in Arcadia. Baseline `f0e7fa031b72c72346986210099d87497c0ee8b2` (the ready plan); delivery in the commit that moves this record to `awaiting-review`.

### Change Summary

- `docs/guides/operator/agent-host-architecture.archify.json` and `agent-host-session.archify.json`: the current drafts, with `meta.output` set to a local file name and Biome's JSON formatting applied. The architecture draft already shows the account-local operator role and no management-account component.
- `docs/guides/operator/agent-host-architecture.svg` and `agent-host-session.svg`: the viewer's "SVG Auto" export of each draft, which embeds its font and follows the reader's light or dark theme; trailing whitespace stripped so `git diff --check` stays clean. About 160 KB each.
- `docs/guides/operator/agent-host.md`: "At a glance" after the introduction and "A working session" before "Kill switch". No other line changed.
- `biome.json`: `!**/*.svg` added to `files.includes`. Deviation from the plan: Biome 2 lints SVG files, and the generated exports fail its accessibility rule (`role="button"` on focusable groups) and its CSS parser (nested `:has(>)` selectors). They are generated artefacts, not authored markup, so they are excluded rather than edited.
- This record: plan ticked, lifecycle and review packet.

### Verification

All local; nothing contacted AWS, Tailscale or GitHub.

- `archify finalize` from both committed sources (copied to a scratch folder): validate, deliver, check and browser-check pass at `showcase` quality.
- `bun run test`: pass. `bunx biome ci .`: pass. `bunx rumdl check .`: no issues. `git diff --check`: clean.
- `ki repo audit --repo .`: PASS, 18 skills.
- Both SVGs parse as XML after whitespace stripping; the rendered images were inspected by eye as PNG exports of the same render.
- No en-dash or em-dash in any added line.

### Outstanding concerns

- **The SVG omits the viewer's cards.** Archify's canonical export carries the diagram and legend but not the HTML viewer's cards, so the runbook carries that content in prose (the two AWS profiles, the session rules).
- **Export is a viewer step.** Archify has no command-line SVG export; the SVGs were exported by driving the viewer's own export in headless Chrome, locally.
- **Biome exclusion is repository-wide for SVG.** Any future hand-authored SVG would also go unlinted. None exists today.

### Post-change review

The goal is met: the runbook shows what is built and how a session runs, with editable sources beside it. Scope held, apart from the one-line Biome exclusion recorded above. Regression risk is low: no procedure text changed. The review was the implementing agent's own rereading against the drafts, the runbook and the gates, not an independent reviewer.

### Mini recap

OPS-010 filed the architecture and session diagrams beside the agent-host runbook and explained them in two new sections, with a Biome exclusion for generated SVGs. Every gate passes. Proposed learning route: how to export Archify diagrams for Markdown, to the `archify` guidance through its own record.

## Done

Accepted 2026-10-07 by Kris Brown on the review packet above.

## Discussion

### Placement - 2026-10-07

The images sit beside the runbook they illustrate, so the guide embeds them by relative path and they render on GitHub and in any Markdown viewer. The SVG exports follow the reader's light or dark theme and embed their font.

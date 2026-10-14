---
id: KI-TECHNE-OPS-025
area: OPS
title: Agentic-rig roles folder
purpose: debt
project: agent-host
component: recipes
status: cancelled
resolution: merged
resolution_target: KI-TECHNE-OPS-018
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T22:53:48Z
updated_at: 2026-10-14T06:52:32Z
---

# Agentic-Rig Roles Folder

## Goal

The agentic-rig role profile, today the Rig `agent-host` profile in `recipes/agent-host/rig.toml`, lives in a recipe-independent `roles/` folder in this repository. The `agent-host` recipe refers to it rather than owning it, so a second recipe, and an owned host such as `sol`, can include the same role without copying it or reaching into another recipe's folder.

## Context

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted all ten decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md); the plain-language summary is [Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md). Decision 3 chose option (a): the role profile's home is this repository, in a `roles/` folder outside any recipe. Decision 2 keeps the recipe called `agent-host`, described as "the AWS base for a remote agentic rig". Decision 4 sets the version policy per role: exact pins for rebuildable hosts such as `vega`, newest through Homebrew for workstations, with the role declaring minimums both satisfy.

Today the path `recipes/agent-host/rig.toml` is named by `recipe.toml` (`pins`), `recipes/agent-host/rig-pins.sh`, `operations/aws/agent-host/setup.sh`, `status.sh` and `host/converge.sh`, `tooling/checks/agent-host-workspace.sh` and the operator guide. `tools-techne` does not read the pin path, so the move needs nothing there.

## Boundary

- In: moving the profile and its observe-only pins provider to `roles/`, the profile's name (whether it becomes `agentic-rig` is this repository's choice), updating every reference above, offline checks and the operator guide.
- Out: any remote action or host rebuild; the version-policy minimums for workstations, which follow once `sol` includes the role; Rig's signed-release install kind and any Rig change for sharing a role across sources, which `tools-rig` delivers.

## Cancelled

Kris approved this closure on 14 October 2026, as written in the state-of-play thread's triage burn-down, under Kris's instruction to burn the roadmap down. Merged into KI-TECHNE-OPS-018, which carries this record's Goal and Boundary in its Discussion and widens its Boundary to include them; that record is held until vega is rebuilt and will be reshaped then. No change is outstanding here.

## Discussion

Origin: `ki-principal`, state-of-play thread, under Kris Brown's acceptance of the audit decisions. Capture only; adoption, priority and plan belong to this repository.

### Dependencies at capture

Not blocked. It is the sequencing prerequisite for KI-TECHNE-OPS-024's pin-bump tool, which waits for the profile's lasting path. `tools-rig` is separately asked for a way for one agentic-rig role to serve both `sol` and `vega`; this move does not wait for that.

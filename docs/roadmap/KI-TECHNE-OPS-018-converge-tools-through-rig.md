---
id: KI-TECHNE-OPS-018
area: OPS
title: Converge tools through Rig
purpose: debt
project: agent-host
component: operations
kind: deliver
status: draft
horizon: hold
hold:
  reason: waiting-for
  condition: Rig installs a signed ki release, and vega is rebuilt so rig status can be shown clean through a pin bump
  review: 2026-11-12
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-12T19:56:25Z
---

# Converge Tools Through Rig

## Goal

The agent host's shared tools - Bun, Node, Codex and `ki` - are installed by `rig apply --profile agent-host` from the recipe's one declaration, rather than by `converge.sh`'s own install steps.

## Context

[ADR-KI-PRINCIPAL-003](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) in `ki-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 2 stages Rig: stage 1 (TECHNE-TOOLS-OPS-014) declares the `agent-host` profile and observes drift through `rig status`; the pilot installs personal tools through Rig; this record is stage 3.

This record is gated. It starts only when both conditions hold:

1. Rig can install `ki`'s signed release, through the provider this record now carries (merged from KI-TECHNE-OPS-016 on 2026-10-12).
2. Stage 1's `rig status` has reported clean on the host through at least one pin bump.

`converge.sh` keeps bootstrapping Rig and mise at pinned versions, because Rig does not bootstrap the managers it drives. Claude Code stays installed by the stack's boot script and observed against its declared minimum.

## Boundary

- In scope: a small custom provider under `rig-provider-v1`, beside the recipe's own `rig.toml` (never in an owner's payload), that installs an exact `ki` version through `ki`'s own signed installer into the user's home without root and reports the installed version for `rig status`; the provider must keep `ki`'s signature check over its signed archives and checksum manifest, never falling back to a SHA-256-only download or mise's GitHub-release backend; replacing `converge.sh`'s Bun, Node, Codex and `ki` installs with `rig apply --profile agent-host`; generating or checking the global mise manifest from the same declaration so one file stays authoritative; offline tests; the operator guide.
- Out of scope: a release-archive install kind in `tools-rig`, taken up only if a second archive-shipped tool needs Rig; any change to `ki`'s installer or release signing; Rig and mise bootstrap; Claude Code's install; Git settings, startup files, the repository set, `ki bootstrap`, the registry and projections, and Claude settings, which are not tool installs and stay in `converge.sh`; any live remote action.

## Discussion

This record stays in triage until both gate conditions hold; the lessons of the pilot and of stage 1 are written into it before it is adopted.

Lessons from the workstation pilot, TECHNE-TOOLS-OPS-015, on 2026-10-09: `rig apply` counts a tool it only re-verifies as completed, so its `completed=` summary cannot tell a change from none. `converge.sh` reads `rig status --profile <profile> --format json` before the apply and reports a change only when a tool was not already present; the shared tools should follow the same pattern. Run Rig with `RIG_PROGRESS=never` and stdin closed, as the pilot does, so its output stays parseable over SSH.

Merged from KI-TECHNE-OPS-016 on 2026-10-12: [ADR-KI-PRINCIPAL-003](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) decision 3 chooses the custom provider that wraps `ki`'s signed installer. Rig's built-in `direct-download` `executable` kind covers a single binary checked by SHA-256 but not `ki`'s signed `tar.gz` archives, and the payload validator refuses a custom provider in an owner's fragment, so the provider ships with the recipe and needs no `tools-rig` release.

### Adoption

On 12 October 2026 Kris approved the triage review's proposal as written (state-of-play thread, Decision 147): adopted as `deliver / Hold`. Its existing gates are the hold condition: Rig must install a signed `ki` release, and `rig status` must stay clean through a pin bump. vega has been deleted and is not yet rebuilt, so the second gate cannot clear now. Remote work stays within the Techne Programme Hold. Adoption grants no implementation, acceptance or remote authority.

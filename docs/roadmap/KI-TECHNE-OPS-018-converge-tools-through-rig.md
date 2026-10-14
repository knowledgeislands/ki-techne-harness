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
updated_at: 2026-10-14T06:52:32Z
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
- Merged from KI-TECHNE-OPS-025 on 2026-10-14: the role-profile move to a `roles/` folder, with the Goal and Boundary carried into Discussion below.
- Merged from KI-TECHNE-OPS-026 on 2026-10-14: the tailnet-only listener firewall declaration, with the Goal and Boundary carried into Discussion below.

## Discussion

This record stays in triage until both gate conditions hold; the lessons of the pilot and of stage 1 are written into it before it is adopted.

Lessons from the workstation pilot, TECHNE-TOOLS-OPS-015, on 2026-10-09: `rig apply` counts a tool it only re-verifies as completed, so its `completed=` summary cannot tell a change from none. `converge.sh` reads `rig status --profile <profile> --format json` before the apply and reports a change only when a tool was not already present; the shared tools should follow the same pattern. Run Rig with `RIG_PROGRESS=never` and stdin closed, as the pilot does, so its output stays parseable over SSH.

Merged from KI-TECHNE-OPS-016 on 2026-10-12: [ADR-KI-PRINCIPAL-003](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) decision 3 chooses the custom provider that wraps `ki`'s signed installer. Rig's built-in `direct-download` `executable` kind covers a single binary checked by SHA-256 but not `ki`'s signed `tar.gz` archives, and the payload validator refuses a custom provider in an owner's fragment, so the provider ships with the recipe and needs no `tools-rig` release.

### Adoption

On 12 October 2026 Kris approved the triage review's proposal as written (state-of-play thread, Decision 147): adopted as `deliver / Hold`. Its existing gates are the hold condition: Rig must install a signed `ki` release, and `rig status` must stay clean through a pin bump. vega has been deleted and is not yet rebuilt, so the second gate cannot clear now. Remote work stays within the Techne Programme Hold. Adoption grants no implementation, acceptance or remote authority.

### Boundary audit handoff

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted the decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md) ([Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md) summarises them). Decision 5 replaces this record's harness signed-release provider with a built-in signed-release install kind in `tools-rig`, and ADR-KI-PRINCIPAL-003 decision 3 is amended to match. The audit also moves Claude Code's install from the boot script into this record's scope, as a self-updating `minimum` tool. The Boundary above still describes the harness provider; reshaping it is this repository's to do when the record is next planned. Gate 1 then reads "Rig's signed-release install kind installs `ki`", which `tools-rig` delivers. Nothing here changes the record's status, horizon or hold.

### Merged from KI-TECHNE-OPS-025 on 2026-10-14

Kris approved merging KI-TECHNE-OPS-025 into this record on 14 October 2026, in the state-of-play thread's triage burn-down, because it matters only to this record's role-profile reshape when vega is rebuilt. Its Goal and Boundary, carried as written:

**Goal.** The agentic-rig role profile, today the Rig `agent-host` profile in `recipes/agent-host/rig.toml`, lives in a recipe-independent `roles/` folder in this repository. The `agent-host` recipe refers to it rather than owning it, so a second recipe, and an owned host such as `sol`, can include the same role without copying it or reaching into another recipe's folder.

**Boundary.**

- In: moving the profile and its observe-only pins provider to `roles/`, the profile's name (whether it becomes `agentic-rig` is this repository's choice), updating every reference named below, offline checks and the operator guide.
- Out: any remote action or host rebuild; the version-policy minimums for workstations, which follow once `sol` includes the role; Rig's signed-release install kind and any Rig change for sharing a role across sources, which `tools-rig` delivers.

**References to update, from its Context.** Today the path `recipes/agent-host/rig.toml` is named by `recipe.toml` (`pins`), `recipes/agent-host/rig-pins.sh`, `operations/aws/agent-host/setup.sh`, `status.sh` and `host/converge.sh`, `tooling/checks/agent-host-workspace.sh` and the operator guide. `tools-techne` does not read the pin path, so the move needs nothing there.

**Dependencies at merge.** Not blocked. It is the sequencing prerequisite for KI-TECHNE-OPS-024's pin-bump tool, which waits for the profile's lasting path. `tools-rig` is separately asked for a way for one agentic-rig role to serve both `sol` and `vega`; this move does not wait for that.

### Merged from KI-TECHNE-OPS-026 on 2026-10-14

Kris approved merging KI-TECHNE-OPS-026 into this record on 14 October 2026, in the state-of-play thread's triage burn-down, because it matters only to this record's role-profile reshape when vega is rebuilt. Its Goal and Boundary, carried as written:

**Goal.** The `agent-host` recipe declares Rig's tailnet-only firewall for the listeners its agents start, so a development server, preview or tool port on the host is reachable only from loopback and the tailnet. The AWS stack keeps opening no public inbound port. Kris's Macs and the agent host then share one firewall model.

**Boundary.**

- In: a `linux-nftables` firewall declaration in the recipe's Rig profile for its agents' listener ports; adding `nftables` to the host's package install; moving the Rig pin to a release that contains the provider; an offline check that the stack keeps no public ingress rule; the operator guide's rollback (`sudo systemctl disable --now LOCATOR.service` and `sudo nft delete table inet rig_NAME`).
- Out: any `rig apply`, host rebuild or AWS change. Applying the firewall to the running host waits for the Techne Programme Hold to allow remote-environment management. Rig's provider itself, its review and release belong to `tools-rig`.

**Dependencies at merge.** Not blocking anything. It depends on a Rig release containing KI-TOOL-RIG-CORE-051, after that record is reviewed and accepted, and on the Techne Programme Hold for any change to the running host. KI-TECHNE-OPS-025 may move the profile to `roles/` first; the declaration then belongs wherever the role profile lives.

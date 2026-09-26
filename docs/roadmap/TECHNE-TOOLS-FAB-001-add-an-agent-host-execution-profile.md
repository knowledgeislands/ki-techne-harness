---
id: TECHNE-TOOLS-FAB-001
area: FAB
title: Add agent-host profile
theme: execution-fabric
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T15:55:00Z
updated_at: 2026-09-26T15:55:00Z
---

# Add Agent-Host Profile

## Goal

Add a second, additive execution profile that can host an interactive or long-running agent session, without relaxing any of the constraints that make the existing deterministic execution profile trustworthy.

## Context

The current execution profile is correct for the deterministic dispatch work it was built for, and every one of its constraints is load-bearing for that purpose: an empty egress allowance for the namespace, an active deadline that terminates a job after five minutes, a read-only root filesystem with no mounted volumes, and a restart policy and backoff limit that make pod termination final.

Each of those is also a reason an agent session cannot run under that profile. With no egress there is no model API, so an agent cannot make its first call. A five-minute deadline terminates precisely the sessions whose purpose is to outlive a connection. A read-only root with no volumes leaves nowhere to check out a repository and nothing to restore on reattach. A terminal restart policy leaves nothing to reattach to at all.

The correct response is not to loosen the deterministic profile. It is to add a separate profile, so that the existence of one does not weaken the other.

## Boundary

This item does not change the deterministic execution profile, widen its egress, raise its deadline, or grant it a volume. It does not deploy an agent host, install an agent runtime, or authorise any spend. It designs and declares the additive profile and the guard that keeps the two apart.

## Discussion

### Named differences from the deterministic profile

The agent-host profile needs a scoped egress allowance rather than an open one, naming the model API and the repository hosts it is authorised to reach. It needs a writable workspace with a stated per-worker allocation rather than one shared root. It needs no fixed active deadline, but does need a stated maximum lifetime and an idle reaper, because a session with no ceiling is a standing bill. It needs a declared behaviour on pod termination, which the deterministic profile answers by making termination final.

### Non-regression is the acceptance test

The deliverable is only acceptable if the deterministic profile is demonstrably unchanged: same empty egress, same deadline, same read-only root, same terminal restart policy. A shared default that both profiles inherit is the most likely way for this to regress silently, so the two profiles should not share a mutable base for any of those four fields.

### Cost per idle hour

An agent host that runs while nothing is assigned is a standing charge. The profile should prefer a wake-on-demand shape, and if it cannot, it must state the idle cost explicitly so that the choice is made rather than inherited.

### Open questions

- Which exact egress destinations does an agent session require, and can they be expressed as a policy rather than an open allowance?
- How is a workspace allocated per session so that two sessions never write one repository root?
- What idle timeout and maximum lifetime are acceptable, and who is notified when one fires?
- Does the substrate have the capacity to host a session at all, given the measured node size and free disk recorded in `TECHNE-TOOLS-OPS-008`?

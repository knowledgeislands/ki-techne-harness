---
id: TECHNE-TOOLS-CTRL-001
area: CTRL
title: Link tasks to roadmap
theme: controller
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-24T22:34:01Z
updated_at: 2026-09-24T22:34:01Z
---

# Link tasks to roadmap

## Goal

Let Paperclip tasks reference canonical KI roadmap items so coordinated agent activity remains traceable to governed work without making Paperclip the roadmap authority.

## Context

Paperclip supports direct task conversations and supplies agents with a runtime skill for creating, updating, delegating and reporting work through its control plane. A person may also talk directly with a Techne agent and have that agent invoke Paperclip only when shared coordination is useful.

KI roadmap records already own work adoption, priority, readiness, dependencies, review and acceptance. Paperclip tasks instead own assignees, conversations, runs, costs and operational dispositions. Linking them would allow an agent team to coordinate execution while preserving the repository as the durable source of governed work.

## Boundary

This item does not adopt Paperclip, implement a complete Paperclip provider, synchronise the two lifecycle models, or make Paperclip tasks canonical KI knowledge. It does not require every direct question, routine or agent conversation to have a roadmap item.

## Discussion

### Authority boundary

The KI roadmap item remains authoritative for adoption and delivery lifecycle. A Paperclip task may report `done` while its roadmap item still requires integration, verification, review and human acceptance. Paperclip status changes must not automatically promote, ready, accept or close KI work.

### Direct interaction

Paperclip is a coordination capability rather than a mandatory conversational gateway. A direct Techne agent session may use the Paperclip skill to create or attach to a task, delegate a bounded activity, or report progress. Tasks originating in Paperclip may reach the same agent through its normal runtime adapter.

### Link contract

The minimum association should name the KI repository, roadmap identifier and admitted repository revision. Prefer structured Paperclip task metadata over description text when a stable extension point exists. One roadmap item may link to several Paperclip tasks, while each task should identify at most one governing roadmap item.

The roadmap item may record relevant Paperclip task references during planning or review, but should not mirror their comment history, run state or cost ledger. Paperclip execution results become evidence for the roadmap review packet.

### Intake

Transient Paperclip tasks need no roadmap record. When an agent discovers substantive prospective work, the Paperclip skill should route it through the KI intake process as unadopted Triage rather than treating task creation as adoption authority.

### Open questions

- Which Paperclip extension point can carry repository, roadmap and revision fields without maintaining a fork?
- How should a direct agent session decide whether to create a new task, attach to an existing task or remain outside Paperclip?
- How should several Paperclip tasks associated with one roadmap item be discovered and presented without bidirectional status synchronisation?
- Which evidence should flow back into the KI roadmap review packet when a Paperclip task finishes?

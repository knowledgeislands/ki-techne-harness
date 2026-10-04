---
id: TECHNE-TOOLS-CTRL-001
area: CTRL
title: Link tasks to roadmap
theme: controller
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-24T22:34:01Z
updated_at: 2026-10-04T11:40:00Z
---

# Link tasks to roadmap

## Goal

Let Paperclip tasks reference canonical KI roadmap items so coordinated agent activity remains traceable to governed work without making Paperclip the roadmap authority.

## Context

Paperclip supports direct task conversations and supplies agents with a runtime skill for creating, updating, delegating and reporting work through its control plane. A person may also talk directly with a Techne agent and have that agent invoke Paperclip only when shared coordination is useful.

KI roadmap records already own work adoption, priority, readiness, dependencies, review and acceptance. Paperclip tasks instead own assignees, conversations, runs, costs and operational dispositions. Linking them allows an agent team to coordinate execution while preserving the repository as the durable source of governed work.

When this item was first shaped, no link contract existed anywhere, so the plan designed one locally: a reserved Paperclip issue document under the key `ki-governing-work`, a two-way contradiction checker reading those documents, and a local governance Decision Record. That contract has since been decided and delivered portably, in a different shape, so this item now applies the portable contract here rather than inventing a parallel one.

## Boundary

This item does not adopt Paperclip, implement a Paperclip provider, synchronise the two lifecycle models, or make Paperclip tasks canonical KI knowledge. It does not require every direct question, routine or agent conversation to have a roadmap item.

It does not change the portable `ki-agent-coordination-paperclip` or `ki-work-roadmap` standards in `knowledgeislands/ki-agentic-harness`, or the roadmap parser in `knowledgeislands/tools-ki`.

It makes no write to Paperclip. Task-side prose backlinks, which the portable standard places in each task description, are owner follow-up rather than repository work, and recording them is outside this item. It performs no remote execution or remote-environment management under the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md).

## Current state

- **Portable contract delivered.** `knowledgeislands/ki-agentic-harness` commit `a98cce65` added the optional, provider-qualified `task_links` front-matter map to the `Task links` section of `skills/change-management/ki-work-roadmap/references/standards-work-item-format.md`. The `Task-to-work relationship` section of `standards-agent-coordination-paperclip.md` now makes the item's own `task_links` the durable structured association, makes the task side an ordinary-prose backlink in the task description, and forbids inventing a Paperclip custom field or a shared writable lookup table.
- **Parser delivered.** `knowledgeislands/tools-ki` commit `c0857d5652060d644fecc7c2f20a308f59feec7c` parses and validates `task_links` (`parseTaskLinks` in `src/core/work/items.ts`), so `ki repo audit --skill ki-work-roadmap` rejects a malformed map.
- **Owner direction recorded.** Paperclip task `KIS-5` records the human's request for an authoritative map on each roadmap item, prose task-side backlinks, and no shared lookup table, writable index, mandatory reverse document or bidirectional synchronisation.
- **Covering tasks, read-only evidence of 2026-10-04.** Company `KIS` (`558dd49e-7615-409f-b7b2-7f19e22171d9`) at `http://127.0.0.1:3100`: `KIS-4` (`dc04354e-d2ed-455d-b415-88bbef0d7270`, `done`) shaped this item; `KIS-5` (`b76a4ec9-be48-4a3c-8568-7885b5e6789b`, `backlog`) owns the per-item task-link field in `tools-ki`; `KIS-6` (`7afd7214-386e-455f-83bd-6ac4c9f1bf7f`, `blocked`) brings the company's existing tasks under governed work.
- **This repository.** No roadmap record declares `task_links`. `docs/decisions/`, `tooling/checks/governing-work.sh` and a `check:governing-work` script are absent and are no longer planned.

## Steps

- [ ] Record `task_links.paperclip` in this item's front matter for `KIS-4` (`evaluation`), `KIS-5` (`related`) and `KIS-6` (`coordination`), each with the admitted instance `authority`, the company UUID as `scope`, the task UUID as `id`, the current `key`, and the company-prefixed issue `url`, re-verified read-only against Paperclip immediately before writing.
- [ ] Run the positive verification and the negative check below, restoring the record after the negative check.
- [ ] Record the superseded carrier, checker and Decision Record under Discussion, citing the portable standard and `KIS-5`, so the withdrawal is explicit rather than silent.
- [ ] Record owner follow-up: ordinary-prose backlinks in the descriptions of `KIS-4`, `KIS-5` and `KIS-6` naming this repository, this item, an admitted revision and the task's purpose.

## Files touched

- `docs/roadmap/TECHNE-TOOLS-CTRL-001-link-tasks-to-roadmap.md` (this record only)

## Verify

```bash
ki repo audit --skill ki-work-roadmap --repo .                  # PASS, task_links accepted
ki repo audit --skill ki-repo-project --repo .                  # PASS, repository shape still conforms
ki repo audit --skill ki-agent-coordination-paperclip --repo .  # PASS
ki repo roadmap list --json                                     # this item projects three Paperclip taskLinks
```

Negative check, which must fail: temporarily set one link's `relation` to a value outside the admitted vocabulary, re-run `ki repo audit --skill ki-work-roadmap --repo .`, and require a failure naming this item. Restore the record and require PASS again. A link contract that cannot be made to fail has not been verified.

## Dependencies / blocks

Nothing blocks this item. The portable contract and its parser are delivered. Writing task-side backlinks into Paperclip is owner follow-up, not a prerequisite.

## Delegation

Delivery is one small record edit in the designated primary checkout, which the coordination standard requires for every `docs/roadmap/` write. It is not delegated.

## Documentation impact

### Decision Records

None. The link contract is a portable governance decision now recorded in `ki-agentic-harness`; a local Decision Record would restate a rejected carrier or duplicate the portable one, so `[skills.ki-decision-records]` is not declared for this item.

### Specifications

No behaviour-level contract in this repository changes. The controller ships nothing new.

### Guides

No human guidance changes.

### Roadmap

The two follow-ons originally planned are both delivered and need no capture: the portable task-link rule in `knowledgeislands/ki-agentic-harness` (`a98cce65`) and the front-matter field in `knowledgeislands/tools-ki` (`c0857d56`).

## Discussion

### Authority boundary

The KI roadmap item remains authoritative for adoption and delivery lifecycle. A Paperclip task may report `done` while its roadmap item still requires integration, verification, review and human acceptance. Paperclip status changes must not automatically promote, ready, accept or close KI work.

### Direct interaction

Paperclip is a coordination capability rather than a mandatory conversational gateway. A direct Techne agent session may use the Paperclip skill to create or attach to a task, delegate a bounded activity, or report progress. Tasks originating in Paperclip may reach the same agent through its normal runtime adapter.

A direct session stays outside Paperclip when the exchange leaves no durable artefact, attaches to an existing task when the work falls inside that task's stated purpose, and creates a task otherwise. Creating a task adopts nothing: absent a governing item, the work goes to KI Triage through `ki-next` first.

### Superseded carrier

The original plan's carrier was a reserved Paperclip issue document under the key `ki-governing-work`, holding one fenced TOML block with `repository`, `item`, `revision`, `purpose` and `recorded_at`, enforced by a `tooling/checks/governing-work.sh` contradiction checker and recorded in a local `GDR-TECHNE-TOOLS-001`. It is withdrawn, not deferred. The portable `Task-to-work relationship` standard places the durable structured association in the item's own `task_links` and the task side in ordinary prose, forbids inventing a Paperclip custom field, and `KIS-5` records the owner's rejection of a mandatory reverse document. Consistency between the two sides is now a `COORD-3` judgement under `ki-agent-coordination-paperclip`, reconciled before assigning or releasing work, rather than a repository-local checker.

### Intake

Transient Paperclip tasks need no roadmap record. When an agent discovers substantive prospective work, the Paperclip skill should route it through the KI intake process as unadopted Triage rather than treating task creation as adoption authority.

### Planning history

- 2026-09-27: shaped to Ready around the `ki-governing-work` carrier (`593a971`); a pickup checkpoint then recorded the delivered `task_links` contract and required reconciliation before implementation.
- 2026-10-04: returned to draft and replanned against the delivered portable contract and the owner direction recorded on `KIS-5`, under the owner's delegated roadmap authority for the 2026-10-04 estate push. An independent judgement review recommended this disposition and the narrowed scope; the item was then set Ready again.

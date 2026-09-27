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
updated_at: 2026-09-27T05:17:00Z
---

# Link tasks to roadmap

## Goal

Let Paperclip tasks reference canonical KI roadmap items so coordinated agent activity remains traceable to governed work without making Paperclip the roadmap authority.

## Context

Paperclip supports direct task conversations and supplies agents with a runtime skill for creating, updating, delegating and reporting work through its control plane. A person may also talk directly with a Techne agent and have that agent invoke Paperclip only when shared coordination is useful.

KI roadmap records already own work adoption, priority, readiness, dependencies, review and acceptance. Paperclip tasks instead own assignees, conversations, runs, costs and operational dispositions. Linking them would allow an agent team to coordinate execution while preserving the repository as the durable source of governed work.

No link exists today. Every Paperclip task coordinating work on this repository is traceable to governed work only through prose a reader must believe, so there is nothing an audit can fail.

## Boundary

This item does not adopt Paperclip, implement a complete Paperclip provider, synchronise the two lifecycle models, or make Paperclip tasks canonical KI knowledge. It does not require every direct question, routine or agent conversation to have a roadmap item.

It does not change the portable `ki-agent-coordination-paperclip` standard in `knowledgeislands/ki-agentic-harness`, and it does not change roadmap front matter in `knowledgeislands/tools-ki`. Both are named as follow-on work under Documentation impact. It delivers the decided contract and a working checker for this repository only.

## Current state

`docs/roadmap/` holds three records: this one, `TECHNE-TOOLS-FAB-001` and `TECHNE-TOOLS-OPS-008`, both captured as unadopted Triage. `_ISSUES.md` reserves `CTRL` through `001`, so this item needs no ledger advance and shaping it allocates no identifier.

`.ki.toml` declares `[skills.ki-agent-coordination-paperclip]`, so the coordination doctrine is active here, but the standard's _Task-to-work relationship_ section records the task side only, and its _Roadmap records are the exception_ section names the primary checkout as the write locus for every roadmap write in this repository.

Two gaps keep the decision from being recorded where an audit can reach it. `docs/decisions/` does not exist; this repository has no Decision Record collection. `.ki.toml` does not declare `[skills.ki-decision-records]`, so a record written into `docs/decisions/` today would be an ungoverned file that no audit reads. Declaring the skill is therefore part of this item, not a follow-on.

No mechanism records a governing item on a Paperclip task, and no check would fail if a task claimed the wrong one.

Governing coverage, in the interim prose form the coordination standard prescribes until a covering-task field is admitted by `ki-work-roadmap`: Paperclip task `KIS-4` shapes this item; `KIS-5` delivers the item-side front-matter field in `knowledgeislands/tools-ki`; `KIS-6` brings the company's existing tasks under the resulting contract.

## Steps

- [ ] Declare `[skills.ki-decision-records]` in `.ki.toml`, create `docs/decisions/` and its `README.md` index carrying an ordered list with one entry per record.
- [ ] Write `docs/decisions/GDR-TECHNE-TOOLS-001-paperclip-governing-work-link.md` with the required frontmatter pair `decision_type: governance` and `decision_type_url: https://knowledgeislands.info/specifications/decision-records/gdr`, and the `## Context`, `## Decision` and `## Consequences` sections. It records the carrier, the TOML grammar and its five field rules, the direction of authority, the staleness rule, and the five-item evidence set.
- [ ] Add `tooling/checks/governing-work.sh`: read the covering-task enumeration from every item in `docs/roadmap/`, read each Paperclip task's `ki-governing-work` document, assert agreement in both directions, and resolve every recorded revision with `git cat-file -e <revision>^{commit}`.
- [ ] Make the checker report four distinct outcomes and exit on them: `0` no contradiction; `1` one or more contradictions, each printed as `<rule> <item-id> <task-key>`; `2` credentials absent, reported as unverifiable rather than passing; `3` the repository cannot resolve a revision because the clone is shallow or unfetched.
- [ ] Have the checker run task-side-only while no covering-task field is admitted to roadmap front matter, printing one explicit line naming that degradation. It must not fall silent, and it must not write the field into front matter, which `ki repo audit --skill ki-work-roadmap` would reject as an unsupported field.
- [ ] Add the `check:governing-work` script entry to `package.json` and wire it into the existing `tooling/checks` invocation path.
- [ ] Write this repository's own `ki-governing-work` document onto `KIS-4`, `KIS-5` and `KIS-6`, then run the checker and record its output.

## Files touched

- `.ki.toml` (one skill declaration)
- `docs/decisions/README.md` (new; the ordered index the Decision Records standard requires)
- `docs/decisions/GDR-TECHNE-TOOLS-001-paperclip-governing-work-link.md` (new)
- `tooling/checks/governing-work.sh` (new)
- `package.json` (one script entry)
- `docs/roadmap/TECHNE-TOOLS-CTRL-001-link-tasks-to-roadmap.md` (this record)

## Verify

```bash
ki repo audit --skill ki-work-roadmap --repo .                  # PASS, front-matter shape unchanged
ki repo audit --skill ki-decision-records --repo .              # PASS, the new collection and index are well-formed
ki repo audit --skill ki-repo-project --repo .                  # PASS, repository shape still conforms
ki repo audit --skill ki-agent-coordination-paperclip --repo .  # PASS
bash tooling/checks/governing-work.sh --repo .                  # exit 0, prints "contradictions: 0"
```

Negative check, which must fail: edit the `item` value in one task's `ki-governing-work` document to a roadmap identifier that does not exist in `docs/roadmap/`, re-run the checker, and require exit `1` naming that task and the `unknown_item` rule. Restore the document afterwards and require exit `0` again. A checker that cannot be made to fail has not been verified.

## Dependencies / blocks

Nothing blocks this item. The carrier needs no Paperclip change, and the checker's task side works against the current API. `ki-decision-records` is provided by the already declared harness `knowledgeislands/ki-agentic-harness`, so declaring it adds no new dependency.

The item side of the two-way link depends on a covering-task field being admitted to roadmap front matter in `knowledgeislands/tools-ki`; that is separate work, coordinated as `KIS-5`. Until it lands the checker runs task-side-only and says so. This item must not pre-empt it by writing the field, because the front-matter parser rejects unknown fields and would fail the whole repository audit. That is sequencing preference rather than build order, so `blocked_by` stays empty.

## Delegation

Delivery is an engineering change and goes to one worker. The boundary is the six files under Files touched; no file outside this repository may be edited. Every write under `docs/roadmap/` is made in this repository's designated primary checkout rather than the worker's isolated checkout, as the coordination standard requires; the remaining files are written in the worker's own checkout. The gate between shaping and delivery is this record at `status: ready`. The final review — running all five Verify commands plus the negative check, and reconciling the result against the Decision Record text — stays with the orchestrator and does not transfer with the work.

## Documentation impact

### Decision Records

One new governance Decision Record in this repository, named under Files touched, recording the carrier choice, the grammar, the staleness rule and the evidence set. It is a `GDR-` because the decision is about process, authority and change mechanism rather than component structure. It is the first record in the `TECHNE-TOOLS` scope, so it takes serial `001`, and it arrives together with the `[skills.ki-decision-records]` declaration and the ordered index that make the collection auditable. The portable home of the task-to-work rule remains `ki-agent-coordination-paperclip`; the record cites it rather than restating it.

### Specifications

No behaviour-level contract in this repository changes. The controller ships nothing new. The link grammar is a governance contract, recorded as a Decision Record, and its portable specification belongs to `ki-agentic-harness`, captured as follow-on work below.

### Guides

No human guidance changes. The Decision Record carries the contract and the checker carries its own usage; a guide would be a third copy to drift.

### Roadmap

Two follow-on items to capture through `ki-next` as unadopted Triage, neither of which this item may deliver:

- `knowledgeislands/ki-agentic-harness` — fold the `ki-governing-work` grammar into the _Task-to-work relationship_ section of `standards-agent-coordination-paperclip.md` and add the matching AUDIT rule, so the contract is portable and every declaring repository is checked rather than only this one.
- `knowledgeislands/tools-ki` — admit an optional covering-task field to roadmap front matter. Coordinated in Paperclip as `KIS-5`.

## Discussion

### Authority boundary

The KI roadmap item remains authoritative for adoption and delivery lifecycle. A Paperclip task may report `done` while its roadmap item still requires integration, verification, review and human acceptance. Paperclip status changes must not automatically promote, ready, accept or close KI work.

### Direct interaction

Paperclip is a coordination capability rather than a mandatory conversational gateway. A direct Techne agent session may use the Paperclip skill to create or attach to a task, delegate a bounded activity, or report progress. Tasks originating in Paperclip may reach the same agent through its normal runtime adapter.

A direct session decides between three outcomes. It stays outside Paperclip when the exchange leaves no durable artefact. It attaches to an existing task when the work falls inside the scope that task's `ki-governing-work` purpose already attests to. It creates a task otherwise — and creating a task adopts nothing: absent a governing item, the work goes to KI Triage through `ki-next` first, and the document is written against the resulting Triage item.

### Link contract

The minimum association names the KI repository, roadmap identifier and admitted repository revision. One roadmap item may link to several Paperclip tasks, while each task identifies at most one governing roadmap item.

The carrier is a reserved Paperclip issue document under the key `ki-governing-work`, holding one fenced TOML block with `repository`, `item`, `revision`, `purpose` and `recorded_at`. The item identifier uses the grammar the roadmap parser already enforces; the revision uses the forty-character lowercase hexadecimal rule `baseline_ref` enforces; `recorded_at` uses the canonical UTC-second shape of the timestamp pair. Borrowing the validators rather than inventing parallel ones is what keeps the two halves from diverging.

A document key is unique per issue, so "at most one governing item" is a property of the storage rather than a rule someone must remember. The document is revisioned, so re-pointing a task appends a claim instead of erasing one. It is bindable as an interaction target, so re-pointing can be put to a human as a card. And the documents route takes an unconstrained key with a two-field body, so the grammar is KI-owned data inside a generic first-party API — no Paperclip schema change, no fork, and nothing an upgrade can take away short of removing the documents API.

The roadmap item may record relevant Paperclip task references during planning or review, but should not mirror their comment history, run state or cost ledger. Paperclip execution results become evidence for the roadmap review packet.

### Rejected carriers

A billing code is one flat string for three values with no revision history, and it belongs to billing; an unrelated billing edit would destroy the link. A company label is capped at forty-eight characters, leaving no room for a revision beside an identifier, and adds a third place to drift. Work products admit only a workspace-file resource reference in their metadata, so the association would degrade into prose. External objects are read-only with no create route. Task description prose — the interim form — is unrevisioned and rewritten by anyone editing the description.

### Discovery from the repository side

The repository never asks Paperclip what covers it. The item's own front matter enumerates its covering tasks, and the task's document attests to its governing item; neither writes the other. The contradiction detector is what makes the link two-way rather than two one-way links that drift: for each task it asserts that the named item enumerates that task, and for each enumerated task it asserts that the task's document names this repository and this item. Any disagreement is reported, never repaired by writing, and no bidirectional status synchronisation of any kind is introduced.

The field is optional rather than required. Requiring it on every item would force an edit to every existing record across the estate at adoption, and the exception granted to avoid that would never expire. An optional field, checked for consistency wherever it is present, with a later rule that new Ready items must declare it, costs one narrow gap now instead of a permanent one.

### Evidence into the review packet

When a Paperclip task finishes, five things are cited into the item's `## Awaiting review` packet: the task identifier and URL; the terminal Paperclip status and its timestamp; the task's pull-request, commit and branch work products as access paths; the `ki-governing-work` revision in force at completion together with the revision it recorded; and the identifier of the comment carrying the outcome. They are cited, never mirrored, and they are not acceptance — `ki-accept` still requires its human review gate.

### Stale revisions

A recorded revision that no longer resolves makes the link stale, not void. The task is not orphaned and is never silently re-pointed. The correction is to re-read the item at the current tip, confirm or restate the scope, and append a new document revision naming the new commit and the superseded one. A shallow or unfetched clone yields an unverifiable rather than an unresolvable revision, which is reported separately and is not a contradiction.

### Intake

Transient Paperclip tasks need no roadmap record. When an agent discovers substantive prospective work, the Paperclip skill should route it through the KI intake process as unadopted Triage rather than treating task creation as adoption authority.

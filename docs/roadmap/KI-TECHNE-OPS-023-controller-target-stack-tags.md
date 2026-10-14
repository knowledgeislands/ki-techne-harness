---
id: KI-TECHNE-OPS-023
area: OPS
title: Controller and target tags
purpose: debt
component: infra
kind: deliver
status: cancelled
resolution: rejected
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-11T01:24:30Z
updated_at: 2026-10-14T13:20:34Z
---

# Controller and Target Tags

## Goal

The controller and disposable-target AWS stacks carry no work-record identifier in their tags or scripts, because records are pruned while the stacks and their tags outlast them. A durable governance tag, or none, replaces `ki-work-item`, and the target destroy guard recognises its stacks by something that does not name a record.

## Context

Captured on 2026-10-11 while settling [KI-TECHNE-OPS-017](KI-TECHNE-OPS-017-zsh-shell-at-rebuild.md). Kris decided that record removes every record identifier from the agent-host stack and that the other stacks' `ki-work-item` tags go to a separate triage record, because they are not that host.

- `infra/aws/controller-stack.yaml` and `infra/aws/target-stack.yaml` tag every resource `ki-work-item: TECHNE-OPS-007`, an identifier from a retired numbering.
- `operations/aws/controller/provision.sh` and `operations/aws/target/provision.sh` pass `--tags ki-work-item=TECHNE-OPS-007`.
- `operations/aws/target/destroy.sh` reads the stack's `ki-work-item` tag and refuses to delete a stack unless it equals `TECHNE-OPS-007`. The tag is therefore a safety guard, not only a label: changing it needs a replacement guard, such as the `ki-lifecycle=disposable-target` tag, and a transition for target stacks created under the old tag.

Tags change only through a stack update, so removal from live stacks needs a remote-environment change that the Techne programme hold does not currently authorise. Repository changes can land first.

## Boundary

- In scope: the controller and target stack templates, their `provision.sh` tags, the target `destroy.sh` guard, and any offline checks and guides that name the tag.
- Out of scope: the agent-host stack, which [KI-TECHNE-OPS-017](KI-TECHNE-OPS-017-zsh-shell-at-rebuild.md) covers; updating live stacks, which waits for remote-environment authority.

## Cancelled

Cancelled 2026-10-14 as rejected (parked), approved by Kris Brown in the state-of-play run ('RC-ALL: approve all' to the roadmap census): removing the tag from live stacks needs a remote stack update the Techne Programme Hold does not authorise. The finding, including that `operations/aws/target/destroy.sh` uses the tag as its safety guard, is kept as an idea in the agent-host Project (`ki-principal`, `Streams/Projects/agent-host/agent-host.md`); Git history keeps the full record. It leaves no outstanding change.

## Discussion

Not adopted. Open questions for planning: whether the replacement is `ki-authority` naming a durable decision record, as Kris chose for the agent host, or no tag; and which tag `destroy.sh` keys on.

### Adoption

On 12 October 2026 Kris approved the triage review's proposal as written (state-of-play run, 'TRIAGE-APPROVE (all 13 proposals)'): adopted as `deliver / Future`. Live stack updates need remote authority the Techne Programme Hold does not grant, and the replacement tag name is Kris's decision during planning. Adoption grants no implementation, acceptance or remote authority.

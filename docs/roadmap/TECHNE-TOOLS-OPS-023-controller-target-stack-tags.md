---
id: TECHNE-TOOLS-OPS-023
area: OPS
title: Controller and target tags
purpose: debt
component: infra
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-11T01:24:30Z
updated_at: 2026-10-11T01:24:30Z
---

# Controller and Target Tags

## Goal

The controller and disposable-target AWS stacks carry no work-record identifier in their tags or scripts, because records are pruned while the stacks and their tags outlast them. A durable governance tag, or none, replaces `ki-work-item`, and the target destroy guard recognises its stacks by something that does not name a record.

## Context

Captured on 2026-10-11 while settling [TECHNE-TOOLS-OPS-017](TECHNE-TOOLS-OPS-017-zsh-shell-at-rebuild.md). Kris decided that record removes every record identifier from the agent-host stack and that the other stacks' `ki-work-item` tags go to a separate triage record, because they are not that host.

- `infra/aws/controller-stack.yaml` and `infra/aws/target-stack.yaml` tag every resource `ki-work-item: TECHNE-OPS-007`, an identifier from a retired numbering.
- `operations/aws/controller/provision.sh` and `operations/aws/target/provision.sh` pass `--tags ki-work-item=TECHNE-OPS-007`.
- `operations/aws/target/destroy.sh` reads the stack's `ki-work-item` tag and refuses to delete a stack unless it equals `TECHNE-OPS-007`. The tag is therefore a safety guard, not only a label: changing it needs a replacement guard, such as the `ki-lifecycle=disposable-target` tag, and a transition for target stacks created under the old tag.

Tags change only through a stack update, so removal from live stacks needs a remote-environment change that the Techne programme hold does not currently authorise. Repository changes can land first.

## Boundary

- In scope: the controller and target stack templates, their `provision.sh` tags, the target `destroy.sh` guard, and any offline checks and guides that name the tag.
- Out of scope: the agent-host stack, which [TECHNE-TOOLS-OPS-017](TECHNE-TOOLS-OPS-017-zsh-shell-at-rebuild.md) covers; updating live stacks, which waits for remote-environment authority.

## Discussion

Not adopted. Open questions for planning: whether the replacement is `ki-authority` naming a durable decision record, as Kris chose for the agent host, or no tag; and which tag `destroy.sh` keys on.

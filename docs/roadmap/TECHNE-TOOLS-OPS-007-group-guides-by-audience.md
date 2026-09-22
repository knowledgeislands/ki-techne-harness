---
id: TECHNE-TOOLS-OPS-007
title: Group guides by audience
area: OPS
theme: operations
horizon: now
status: ready
blocks: []
blocked_by: []
transferred_from: ki-website
baseline_ref: null
created_at: 2026-09-21T17:20:00Z
updated_at: 2026-09-22T05:41:35Z
---

## Goal

The guide collection routes by the audience that reads it, so an operator and a developer each find their own material rather than a flat list.

## Context

`docs/guides/` declares `[skills.ki-guides]` and holds exactly two files: the collection index and `telegram-commands.md`, which sits flat at the root outside any audience directory. Nothing else is in the collection.

This repository owns the controller and execution-fabric implementation, verification, packaging, bootstrap, and deployment resources. That is a substantial operational surface with no operator guides, while `tools-techne` owns the operator interface separately — so the boundary between what is documented here and what is documented there is unstated.

KI Website now declares, for every page it publishes under `apps/site/src/guidance/`, the exact upstream document and pinned ref that page was written from, and a `verify:guidance --network` sweep reports the pages whose source has moved. The site intends to derive public guidance for this project from this repository's own guides and cite them at a pinned ref, so the quality and stability of `docs/guides/` here directly determines the quality of what the site can publish.

That is a pull, not an obligation: KI Website derives, it does not own. This repository decides what its guides say and when they change.

Separately, `ki-guides` is being asked to require audience directories under `docs/guides/` rather than permitting a flat collection (`ki-agentic-harness` `KI-HARNESS-GOV-083`). If that lands, this repository's collection has to satisfy it.

## Boundary

Adopted into `Now` and approved for delivery. This repository owns the collection and its sequencing; KI Website may derive and cite the resulting guides but has no approval authority over them.

KI Website derives and cites; it does not own this collection and must not be given approval rights over it. Nothing here requires a guide to be written for the website's benefit — if a guide would not serve this repository's own readers, it should not exist.

## Planning decisions

- Use two audiences: operators and developers. Provider-adapter authors are developers until distinct procedures justify another audience.
- Place `telegram-commands.md` under operators because it explains the behaviour of the deployed controller rather than the `techne` command-line interface.
- Keep CLI installation, authentication, command grammar and bootstrap invocation in `tools-techne`; keep deployed-controller behaviour, runtime resources and infrastructure recovery in Techne Harness.
- Establish the audience structure and honest entry points now. Do not invent a deployment tutorial while the public operator path remains the independently released CLI.

## Current state

`docs/guides/` contains an index and one flat document, `telegram-commands.md`. No audience directory exists. `.ki.toml` declares `[skills.ki-guides]`, so the collection is gated for the checks that exist, none of which require audience grouping today.

## Steps

- [ ] Name the audiences this repository has, and reject any nobody is writing for.
- [ ] Create one directory per audience, each with its own index.
- [ ] Move `telegram-commands.md` under the audience that needs it.
- [ ] Record the documentation boundary with `tools-techne` where the operator interface is concerned.
- [ ] Sweep `README.md` and the deployment resources for practical instruction that belongs in the collection.
- [ ] Run the guides audit and repair what it reports.

## Files touched

- `docs/guides/README.md`
- `docs/guides/operator/README.md`
- `docs/guides/operator/telegram-commands.md`
- `docs/guides/developer/README.md`
- `docs/guides/telegram-commands.md`
- `README.md`

## Verify

- `ki repo audit --skill ki-guides --repo .`
- `ki repo audit --skill ki-authoring --repo .`
- `bunx rumdl check README.md docs/guides docs/roadmap/TECHNE-TOOLS-OPS-007-group-guides-by-audience.md`
- `git diff --check`

## Delegation

Keep the guide move, indexes, boundary wording and link repair in one lane because they form one small information architecture. No delegation is needed.

## Dependencies / blocks

Nothing blocks this. `KI-HARNESS-GOV-083` in `ki-agentic-harness` proposes making audience directories a `ki-guides` requirement: if it lands first this collection satisfies it by construction, and if it lands later this collection already conforms. KI Website intends to derive public guidance from these guides and cite them at a pinned ref, but it derives rather than owns and its schedule does not gate this work.

## Documentation impact

### Decision Records

No decision record is needed. Audience-centric grouping is the house arrangement `ki-guides` already encodes, so adopting it here is conformance rather than a new decision. One becomes owed only if this repository concludes it needs an exception.

### Specifications

No behaviour-level contract changes. This item changes only where instructions live and who they are written for.

### Guides

This item is entirely guide impact: it establishes or completes the collection, its audience directories, and their indexes.

### Roadmap

No further roadmap change is expected. If writing the guides exposes behaviour that cannot honestly be explained, that is a separate item raised at the time.

## Discussion

Shaping settles how far this goes, not whether it happens. The prompting question is whether a reader who has never opened this repository can do what it is for without reading source.

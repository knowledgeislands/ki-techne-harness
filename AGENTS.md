# Knowledge Islands Techne Harness

The Techne Harness is the runnable personal-controller and execution-fabric implementation repository for the Knowledge Islands ecosystem. The independently released `tools-techne` repository owns the `techne` operator interface.

## Authority

Arcadia owns the architecture, roles, invariants and decision criteria. This repository owns harness applications, packaging, deployment resources, runtime payloads, provider adapters and operational guidance. Do not duplicate or silently redefine canonical architecture here. The [implementation ownership decision (ADR-KI-PRINCIPAL-006)](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-006-techne-implementation-ownership.md) defines this boundary.

## Dependencies

Use Bun `1.4.2` from the repository root. Run dependency installation only at the root. Package manifests may declare tasks and dependencies, but package-local lockfiles and package-local `node_modules` directories are prohibited.

## Secrets and operational state

Never place credentials, kubeconfigs, raw Telegram updates, numeric operator identifiers or provider session material in Git, chat, command arguments, SSM Run Command parameters or retained test evidence. Interactive bootstrap may stream values directly into an authorised runtime secret store after its encryption-at-rest gate passes.

## Change management

Use the local roadmap under `docs/roadmap/` for prospective repository work. Preserve source provenance when moving implementation from another island. Do not push, publish, release or mutate live infrastructure without explicit authority.

## Cross-repository choreography

- Knowledge Islands Principal, the KI Agentic Harness, `tools-ki`, KI Specifications, the KI Website, the Techne Harness, and `tools-techne` may add a concrete handoff item to one another's Stream or roadmap. The receiving repository owns its priority, plan, and execution.
- A handoff names the originating repository, states the need in plain terms, and says in plain words whether it blocks work there. Link only durable documentation, such as guides, specifications or manifests; never link to or cite another repository's roadmap record or its identifier, because records are pruned and such links break.
- Prefer independently executable, non-blocking work. Mark an item as blocking only when it is a genuine prerequisite; otherwise let the receiving repository schedule it in its own horizon.
- A handoff transfers no ownership: ADR-KI-PRINCIPAL-006 still decides what this repository owns.

## Remote-environment focus

Techné carries no programme hold. Local implementation, architecture work, testing and branch integration serve the two hosts in focus: the agent host `vega` and the owned Mac Studio `sol`. Keep the harness building and current with its declared KI engineering and repository standards. Managing remote environments, including remote-agent or infrastructure rollout and changes to running services, is limited to those two hosts within the focus's operating bounds, and the binding owner runs every live operation. Do not treat a Ready record or task approval as authority for remote-environment operations. Every other remote environment, including the controller and its services, is kept as an idea and left as it stands until the principal takes it up. Arcadia owns the focus, its operating bounds and how an idea is taken up in [Techne Programme Focus](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Focus.md).

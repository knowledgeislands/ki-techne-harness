# Paperclip as prior art for Techne

- **Status:** Working analysis
- **Reviewed:** 2026-09-24

This note records an initial comparison between [Paperclip](https://github.com/paperclipai/paperclip) and Techne. It is design input, not an adoption decision or a change to Techne's canonical architecture.

## Working thesis

Paperclip is a plausible coordination system for the agents used by Techne. It should sit below Techne's personal controller and above individual agent runtimes:

```text
person and interfaces
        |
Techne controller: why, context, authority and admission
        |
Paperclip: who does what, delegation, scheduling and review flow
        |
Techne Fabric: where and under which execution constraints
        |
Hermes, Codex or another runtime: how one bounded task is performed
        |
evidence and proposed durable changes return through Techne
```

Alongside that execution path, KI repositories remain the authority for what is known, decided and governed. Paperclip, Hermes and other agents may hold operational state or caches, but none becomes the canonical knowledge owner.

## Conclusion

Paperclip is close to the operational-controller part of Techne, but it begins from a different centre.

Paperclip is an AI-organisation control plane. Its main abstraction is a company containing goals, a hierarchy of persistent AI employees, tasks, budgets, approvals and scheduled execution. Techne is a person-centred governed-work architecture. Its main abstraction is one enduring persona acting through explicit working contexts and dispatching bounded mechanical, agentic or hybrid executions.

Paperclip therefore looks like a concrete agent-coordination subsystem within the Techne vision rather than a replacement for Techne as a whole. It is valuable prior art and a candidate implementation for delegation, scheduling, cost controls, approval routing and coordinated agent work.

## Shared ground

- **Persistent control plane.** Paperclip places a persistent management system above replaceable agents and runtimes. Techne's personal controller similarly owns continuity, policy, admission, supervision and result integration rather than delegating these responsibilities to a worker.

- **Governed units of work.** Paperclip decomposes goals into tasks with explicit ownership and lifecycle state. Task checkout prevents duplicate execution. Techne requires an admitted execution to bind an objective, context, authority, target and evidence destination before consequential work begins.

- **Replaceable runtimes.** Paperclip connects Claude Code, Codex, Cursor, HTTP agents and other runtimes through adapters. Techne separates controller placement, task environment, worker, agent runtime and model placement so each remains independently replaceable.

- **Human authority.** Paperclip routes strategy, hiring and selected task completion through approvals. Its execution policies enforce review and approval transitions rather than trusting an agent to remember them. Techne likewise requires deterministic admission and explicit authority around probabilistic work.

- **Scheduled and event-driven execution.** Paperclip heartbeats wake agents on schedules, task assignments, mentions and approval resolution. This is a practical implementation reference for Techne's persistent supervised and unattended work modes.

- **Cost control.** Paperclip tracks costs at several organisational levels and can pause work at a budget limit. Techne treats cost and resource limits as explicit context, footprint and target-selection concerns.

- **Isolation.** Paperclip can provision a Git worktree and runtime context for a task. Its low-trust mode intersects restrictions from the agent, project, task and run, fails closed when a concrete boundary cannot be resolved, and requires isolated execution. These mechanisms closely resemble Techne's bounded authority and deterministic eligibility model.

## Fundamental differences

### Organisational centre

Paperclip's primary relationship is:

```text
company -> CEO -> managers -> agents -> tasks -> heartbeats
```

Techne's primary relationship is:

```text
person -> persona -> working context -> governed request -> execution -> worker
```

Paperclip models an autonomous organisation. Techne models the continuing relationship between a person and their controller across personal, organisational and professional capacities.

### Identity

In Paperclip, an agent is a durable employee with a role, manager, runtime configuration and budget. Paperclip does distinguish that agent from an individual heartbeat run and from its runtime adapter.

Techne makes a finer distinction between persona, controller session, workload, execution, task environment and worker. A pod, model process, sandbox or agent runtime cannot own the person's identity, the execution's authority or the durable outcome. An execution can recover into another environment without becoming a different execution.

### Context and tenancy

A Paperclip company is a strong organisational and data-isolation boundary. Multiple companies can coexist in one deployment without sharing their goals, agents, tasks or budgets.

A Techne working context is not another persona or merely a tenant. It binds the capacity in which the person is acting, including purpose, knowledge, repositories, credentials, data handling, eligible capabilities, approval rules and resource limits. Switching context cannot redirect an existing execution or silently widen its authority.

### Scope of work

Paperclip is primarily designed to organise AI agents. Its task, heartbeat and org-chart model assumes that agent employees perform the work.

Techne deliberately admits mechanical, agentic and hybrid work through the same controller. A deterministic program should perform stable work when reasoning adds no value. Recurring agentic behaviour can be progressively converted into named workloads and eventually deterministic controller operations.

### Durable authority and state

Paperclip's server and database are the first-class operational home for companies, agents, tasks, approvals, activity and costs. Its execution workspaces preserve code changes in Git worktrees and leave review and merging to the operator.

Techne explicitly keeps Git and the selected change-management process authoritative for durable work and evidence. Controller state, environment checkpoints and provider snapshots have separate authorities and must not become the only recoverable copy of an outcome.

### Architectural breadth

Paperclip combines server, database, UI, CLI, scheduling, connectors, agent adapters and workspaces into one product control plane.

Techne separates canonical architecture, harness implementation and operator tooling. Its fabric is not defined as one service, cluster, provider or executable. This costs integration effort but prevents the first working provider or controller implementation from becoming the architecture by accident.

## What Techne should learn from Paperclip

- Use its dashboard and attention model as interaction-design prior art: show what is happening, what needs intervention and what action is available.
- Study atomic task checkout, event-triggered wake-ups and retained execution context.
- Treat cost ledgers, warning thresholds and hard stops as first-class controller behaviour.
- Enforce review and approval routing in runtime state transitions rather than instructions alone.
- Study its low-trust scope intersection and fail-closed rules as an implementation reference for authority admission.
- Use isolated Git workspaces and their inspection lifecycle as evidence for Techne task-environment design.
- Preserve clear audit trails across requests, executions, comments, approvals, costs and results.

## What Techne should not inherit unchanged

- Do not make the company, CEO or employee metaphor foundational to every kind of governed work.
- Do not let a durable agent role collapse persona, execution identity, worker and runtime into one object.
- Do not require all work to pass through an AI agent when a deterministic operation is sufficient.
- Do not let a product database replace Git or the selected governed-work process as authority for durable repository outcomes.
- Do not make one integrated control-plane implementation the definition of the provider-neutral fabric.

## Proposed relationship

Paperclip is useful as both prior art and a candidate coordination service. The boundary must prevent it and Techne from becoming competing authorities. Techne owns persona, context, admission and integration; Paperclip owns the coordination of an admitted team of agents.

A bounded experiment could treat Paperclip as a replaceable agentic coordination backend:

```text
Techne persona, context and authority
                |
       admitted bounded workload
                |
     Paperclip task coordination
                |
        evidence and outcome
                |
      Techne review and integration
```

Under that boundary, Techne would retain ownership of persona continuity, context selection, authority admission, credentials, canonical evidence and result integration. Paperclip would coordinate only the organisation-scoped work admitted to it.

The Paperclip company and org chart could represent the agent team available within one working context, but must not itself grant access. An agent's Paperclip role describes coordination responsibility; the Techne execution contract still determines what that agent may do for each execution.

The first proof should use one narrowly scoped Paperclip company, one governed KI repository and one remote Hermes worker. It should demonstrate that a fresh worker can recover the work from the repository baseline and Paperclip task state without relying on private knowledge retained only by the previous agent.

## Direct sessions and the Paperclip skill

Paperclip need not mediate every human-agent conversation. A person can talk directly to a Hermes, Codex or other Techne agent, while that agent uses the Paperclip skill as a coordination capability when the conversation produces work involving the wider team.

The required Paperclip runtime skill teaches an agent how to inspect assignments, create and update tasks, report progress, delegate work and communicate with other agents through the control-plane API. Paperclip also provides task threads and Ask mode when the desired interaction begins inside Paperclip.

This creates two valid entry paths:

```text
person -> Paperclip task or chat -> assigned agent

person -> direct Techne agent session -> Paperclip skill -> coordinated work
```

Both paths should converge on the same context, authority and governed-work checks before consequential execution. The second path is especially important for Techne: conversational continuity can remain with the person's chosen agent while Paperclip supplies shared task state only when coordination is useful.

## Linking Paperclip tasks to KI roadmap items

A Paperclip task should be able to reference a canonical KI roadmap item without replacing it. The two records serve different purposes:

- The KI roadmap item owns the governed intent, adoption, priority, dependencies, readiness, review and acceptance lifecycle.
- The Paperclip task owns one coordinated unit of agent activity, its assignee, conversation, run history, cost and operational disposition.
- One roadmap item may produce several Paperclip tasks for planning, research, implementation, review or specialist delegation.
- A Paperclip task may remain unlinked for a transient question or routine operation. Substantive new work discovered there should be captured into KI Triage rather than silently becoming adopted roadmap work.
- Completing a Paperclip task does not complete or accept the roadmap item. Its result becomes evidence consumed by the KI review path.

The minimum link should name the KI repository, canonical roadmap identifier and admitted repository revision. Paperclip should carry that link in structured task metadata if its extension model permits it, rather than relying only on text in the description. The roadmap record may cite relevant Paperclip tasks in its plan or review evidence once the work is selected, without mirroring Paperclip's operational history.

This association should be durable but deliberately not a bidirectional status synchronisation. Each system retains its own lifecycle authority.

## KI knowledge boundary

The central invariant is: **repositories hold knowledge; agents consume, apply and propose changes to it**.

- A KI repository revision supplies the approved architecture, decisions, work records, skills and operating guidance relevant to an execution.
- Techne binds the repository revision and working context before Paperclip dispatches the task.
- Paperclip tasks, comments, decisions and artifacts are coordination state and execution evidence. They become durable KI knowledge only through an explicit promotion or change-management path.
- Hermes memory, model context and session history are runtime aids. They must never be the sole source of a decision, reusable skill, repository fact or recoverable work outcome.
- Agent-authored learning is a proposal. It returns as a repository change, work record or governed knowledge contribution for review before becoming authoritative.
- Paperclip-managed and Hermes-managed skills should be versioned projections of KI-owned skills where applicable. Local copies must identify their source revision and be replaceable rather than drifting into independent truth.
- Replacing an agent or rebuilding its environment must not erase organisational knowledge. Given the same admitted context, repository baseline and retained execution evidence, a replacement worker should be able to continue.
- Cross-context information cannot be recovered from an agent's memory merely because the same agent role or runtime is reused elsewhere.

This preserves a useful distinction: Paperclip remembers the coordination history, an agent may remember execution details, but KI owns the durable knowledge.

## Hermes on a VM

The video's remote Hermes setup is a useful Techne target pattern. Paperclip remains on its controller host while it wakes Hermes through the Hermes API server on another machine. The demonstration uses several independently hosted Hermes agents and has Paperclip coordinate their reporting lines and tasks.

In Techne terms:

- The VM is a worker target, not an identity or knowledge store.
- Hermes is an agent runtime available on that target.
- The Paperclip agent record is a coordination role, not the execution's authority.
- Each Paperclip wake should correspond to a bounded Techne execution or a traceable continuation of one.
- The VM should be reproducible from a versioned image or bootstrap profile, with repositories checked out at admitted revisions.
- Persistent Hermes memory and sessions may support continuity, but must be scoped, exportable where required and non-authoritative.
- Provider, Hermes API and Paperclip credentials must remain distinct and narrowly scoped.
- A real deployment should use private networking and authenticated encrypted transport. The demonstration's explicit insecure-HTTP override is suitable only for a disposable private-network proof.

The simplest proof topology is one Paperclip service plus one Hermes VM dedicated to one low-risk working context. Later proofs can test multiple Hermes profiles, stronger sandboxing, disposable task VMs and elastic targets without changing the coordination contract.

## Questions to revisit

- Does Techne need a first-class multi-agent organisation abstraction, or are named workloads and roles sufficient?
- Which Paperclip state transitions should inform the portable Techne execution lifecycle?
- Should cost accounting be part of every execution evidence envelope?
- Can Paperclip's low-trust boundary resolution be generalised into Techne's authority-envelope admission rules?
- Which heartbeat triggers belong in the controller, and which belong in individual workload definitions?
- What is the smallest contract between Techne admission and Paperclip task creation?
- Which Paperclip entities should carry KI repository, revision, context and authority references?
- What structured Paperclip extension point should carry a KI roadmap link?
- When should a direct agent conversation create or attach to a Paperclip task?
- How should one roadmap item enumerate several Paperclip execution tasks without copying their state?
- How should Paperclip and Hermes skills be projected from KI-owned sources and checked for drift?
- Which Hermes state may persist across executions, and how is it scoped to a working context?
- Should the first Hermes VM be persistent and rebuildable, or disposable for every task?
- How should a controller present an operator attention queue without adopting the entire company metaphor?

## Sources

### Paperclip

- [Paperclip repository and product overview](https://github.com/paperclipai/paperclip)
- [Paperclip concepts: companies, agents, tasks and heartbeats](https://docs.paperclip.ing/guides/welcome/key-concepts/)
- [Paperclip execution policies](https://docs.paperclip.ing/guides/power/execution-policy/)
- [Paperclip execution workspaces](https://docs.paperclip.ing/guides/projects-workflow/workspaces/)
- [Paperclip trust and low-trust review](https://docs.paperclip.ing/administration/trust-and-low-trust-review/)
- [Paperclip work modes](https://docs.paperclip.ing/guides/day-to-day/work-modes/)
- [Paperclip chat-style tasks](https://docs.paperclip.ing/experimental/task-chat/)
- [Paperclip runtime skill](https://github.com/paperclipai/paperclip/blob/master/skills/paperclip/SKILL.md)
- [Paperclip skills and repository-backed sources](https://docs.paperclip.ing/guides/org/skills/)

### Demonstration and Hermes

- [NetworkChuck's Paperclip demonstration](https://www.youtube.com/watch?v=7RVf25Rg0Mc)
- [Companion guide: Paperclip as a meta-harness](https://github.com/theNetworkChuck/paperclip-guide)
- [Companion guide: remote Hermes agents](https://github.com/theNetworkChuck/paperclip-guide/blob/main/guide/04-hire-remote-hermes-agents.md)
- [Official Hermes adapter for Paperclip](https://github.com/NousResearch/hermes-paperclip-adapter)
- [Hermes API server documentation](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/api-server.md)

### Techne Principal

- [Governed Work Controller](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Governed%20Work%20Controller.md)
- [Techne Fabric](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Pillars/Engineering%20Practice/Architecture/AI%20Execution%20Fabric.md)
- [Techne Fabric Execution Contract](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Techne%20Fabric%20Execution%20Contract.md)
- [ADR-TECHNE-001: Provider-neutral isolated agent execution](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Admin/Governance/Decisions/ADR-TECHNE-001-provider-neutral-isolated-agent-execution.md)
- [ADR-TECHNE-002: One persona across explicit working contexts](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Admin/Governance/Decisions/ADR-TECHNE-002-one-persona-across-explicit-working-contexts.md)

# Paperclip as prior art for Techne

- **Status:** Working analysis
- **Reviewed:** 2026-09-24

This note records an initial comparison between [Paperclip](https://github.com/paperclipai/paperclip) and Techne. It is design input, not an adoption decision or a change to Techne's canonical architecture.

## Conclusion

Paperclip is close to the operational-controller part of Techne, but it begins from a different centre.

Paperclip is an AI-organisation control plane. Its main abstraction is a company containing goals, a hierarchy of persistent AI employees, tasks, budgets, approvals and scheduled execution. Techne is a person-centred governed-work architecture. Its main abstraction is one enduring persona acting through explicit working contexts and dispatching bounded mechanical, agentic or hybrid executions.

Paperclip therefore looks like a concrete implementation of part of the Techne vision rather than a replacement for Techne as a whole. It is valuable prior art for controller interaction, scheduling, cost controls, approval routing and isolated execution.

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

## Possible relationship

Paperclip is most useful immediately as prior art and a behavioural benchmark. Integrating the complete product would create two overlapping control planes, both attempting to own tasks, scheduling, policy, approvals and execution state.

A bounded experiment could instead treat Paperclip as a replaceable agentic coordination backend:

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

The likely first step should be to reproduce selected Paperclip patterns in small Techne proofs before attempting an adapter for the whole product.

## Questions to revisit

- Does Techne need a first-class multi-agent organisation abstraction, or are named workloads and roles sufficient?
- Which Paperclip state transitions should inform the portable Techne execution lifecycle?
- Should cost accounting be part of every execution evidence envelope?
- Can Paperclip's low-trust boundary resolution be generalised into Techne's authority-envelope admission rules?
- Which heartbeat triggers belong in the controller, and which belong in individual workload definitions?
- Would a Paperclip adapter add useful capability, or mostly duplicate the Techne controller?
- How should a controller present an operator attention queue without adopting the entire company metaphor?

## Sources

### Paperclip

- [Paperclip repository and product overview](https://github.com/paperclipai/paperclip)
- [Paperclip concepts: companies, agents, tasks and heartbeats](https://docs.paperclip.ing/guides/welcome/key-concepts/)
- [Paperclip execution policies](https://docs.paperclip.ing/guides/power/execution-policy/)
- [Paperclip execution workspaces](https://docs.paperclip.ing/guides/projects-workflow/workspaces/)
- [Paperclip trust and low-trust review](https://docs.paperclip.ing/administration/trust-and-low-trust-review/)

### Techne Principal

- [Governed Work Controller](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Governed%20Work%20Controller.md)
- [Techne Fabric](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Pillars/Engineering%20Practice/Architecture/AI%20Execution%20Fabric.md)
- [Techne Fabric Execution Contract](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Techne%20Fabric%20Execution%20Contract.md)
- [ADR-TECHNE-001: Provider-neutral isolated agent execution](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Admin/Governance/Decisions/ADR-TECHNE-001-provider-neutral-isolated-agent-execution.md)
- [ADR-TECHNE-002: One persona across explicit working contexts](https://github.com/knowledgeislands/ki-techne-principal/blob/main/Admin/Governance/Decisions/ADR-TECHNE-002-one-persona-across-explicit-working-contexts.md)

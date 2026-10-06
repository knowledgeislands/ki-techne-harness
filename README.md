# Techne Harness

Techne Harness is the product monorepo for runnable personal-controller and execution-fabric implementations in the Knowledge Islands ecosystem. The independently released [`tools-techne`](https://github.com/knowledgeislands/tools-techne) repository owns the `techne` operator interface.

Arcadia remains the authority for engineering architecture, role boundaries and decision criteria. This repository owns implementation source, verification, packaging, bootstrap, deployment resources and provider adapters. It does not store credentials or canonical operational state. The [implementation ownership decision (ADR-TECHNE-003)](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-TECHNE-003-techne-implementation-ownership.md) defines this boundary.

## Repository map

- `apps/controller/` — dependency-free Telegram-to-Kubernetes controller and tests.
- `deploy/kubernetes/` — controller and execution-target resources.
- `infra/aws/` — replaceable AWS proof infrastructure.
- `operations/` — harness lifecycle implementations intended to sit behind `techne` commands.
- `deploy/runtime/` — controller-host and target-host payloads packaged with deployments.
- `tooling/checks/` — repository-only verification helpers.
- `docs/guides/` — operator and developer instructions grouped by audience.
- `docs/roadmap/` — local product work queue.

## Operator CLI

Install and run the operator command from [`knowledgeislands/tools-techne`](https://github.com/knowledgeislands/tools-techne). That repository owns the command grammar, local installer, diagnostics, manual and release artifacts. This harness retains the applications, operations and deployable resources those commands operate.

## Guides

- [Operator guides](docs/guides/operator/README.md) cover deployed-controller behaviour and harness-owned recovery.
- [Developer guides](docs/guides/developer/README.md) cover the local toolchain, ownership boundaries and verification workflow.

## Workspace

Use Bun `1.4.2` at the repository root:

```sh
bun install
bun run test
```

Turborepo coordinates package tasks. Install dependencies only at the root; package-local `node_modules`, Bun lockfiles and other package-manager lockfiles fail the repository test gate.

Remote-environment management remains on hold pending the principal's authorisation and a remote-delivery policy. Local implementation and candidate integration may proceed under ordinary repository approvals. Arcadia maintains canonical engineering knowledge in [Engineering Practice](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Pillars/Engineering%20Practice/Engineering%20Practice.md) and defines the remote boundary in its [Techné programme policy](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md).

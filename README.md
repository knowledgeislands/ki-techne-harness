# Techne Harness

Techne Harness is the product monorepo for runnable personal-controller and execution-fabric implementations in the Knowledge Islands ecosystem. The independently released [`tools-techne`](https://github.com/knowledgeislands/tools-techne) repository owns the `techne` operator interface.

Techne Principal remains the authority for engineering architecture, role boundaries and decision criteria. This repository owns implementation source, verification, packaging, bootstrap, deployment resources and provider adapters. It does not store credentials or canonical operational state.

## Repository map

- `apps/controller/` — dependency-free Telegram-to-Kubernetes controller and tests.
- `deploy/kubernetes/` — controller and execution-target resources.
- `infra/aws/` — replaceable AWS proof infrastructure.
- `operations/` — harness lifecycle implementations intended to sit behind `techne` commands.
- `deploy/runtime/` — controller-host and target-host payloads packaged with deployments.
- `tooling/checks/` — repository-only verification helpers.
- `docs/roadmap/` — local product work queue.

## Operator CLI

Install and run the operator command from [`knowledgeislands/tools-techne`](https://github.com/knowledgeislands/tools-techne). That repository owns the command grammar, local installer, diagnostics, manual and release artifacts. This harness retains the applications, operations and deployable resources those commands operate.

## Workspace

Use Bun `1.4.1` at the repository root:

```sh
bun install
bun run test
```

Turborepo coordinates package tasks. Install dependencies only at the root; package-local `node_modules`, Bun lockfiles and other package-manager lockfiles fail the repository test gate.

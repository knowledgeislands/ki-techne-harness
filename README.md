# Techne Tools

Techne Tools is the product monorepo for runnable personal-controller and execution-fabric tooling in the Knowledge Islands ecosystem.

Techne Principal remains the authority for engineering architecture, role boundaries and decision criteria. This repository owns implementation source, verification, packaging, bootstrap, deployment resources and provider adapters. It does not store credentials or canonical operational state.

## Repository map

- `apps/cli/` — typed `techne` operator command-line application.
- `apps/controller/` — dependency-free Telegram-to-Kubernetes controller and tests.
- `deploy/kubernetes/` — controller, execution and target resources.
- `infra/aws/` — replaceable AWS proof infrastructure.
- `scripts/` — repository checks and bounded operational helpers.
- `docs/roadmap/` — local product work queue.

## Workspace

Use Bun `1.4.1` at the repository root:

```sh
bun install
bun run test
bun run self:techne -- --help
```

Turborepo coordinates package tasks. Install dependencies only at the root; package-local `node_modules`, Bun lockfiles and other package-manager lockfiles fail the repository test gate.

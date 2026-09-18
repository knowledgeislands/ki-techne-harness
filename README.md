# Techne Tools

Techne Tools is the product monorepo for runnable personal-controller and execution-fabric tooling in the Knowledge Islands ecosystem.

Techne Principal remains the authority for engineering architecture, role boundaries and decision criteria. This repository owns implementation source, verification, packaging, bootstrap, deployment resources and provider adapters. It does not store credentials or canonical operational state.

## Repository map

- `apps/controller/` — dependency-free Telegram-to-Kubernetes controller and tests.
- `packages/bootstrap/` — interactive, non-retaining operator entry points.
- `deploy/kubernetes/` — controller, execution and target resources.
- `infra/aws/` — replaceable AWS proof infrastructure.
- `scripts/` — repository checks and bounded operational helpers.
- `docs/roadmap/` — local product work queue.

## Workspace

Use Bun `1.4.1` at the repository root:

```sh
bun install
bun run test
```

Turborepo coordinates package tasks. Install dependencies only at the root; package-local `node_modules`, Bun lockfiles and other package-manager lockfiles fail the repository test gate.

## Controller proof

The initial controller proof migrated from Techne Principal work item `TECHNE-OPS-007`. It retains a long-running single-node K3s controller and uses separately registered execution targets. See [the provenance record](docs/provenance/TECHNE-OPS-007.md) and [controller operations guide](docs/guides/controller-proof.md).

Credential admission is deliberately interactive. Before a Telegram credential can enter Kubernetes, the retained cluster must report K3s Secret encryption enabled with rotation stage `reencrypt_finished`. The bootstrap opens an interactive SSM session; it does not put credential values into Git, a command argument or an SSM Run Command parameter.

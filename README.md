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

## Install the CLI

Link a development checkout into `${TECHNE_INSTALL_DIR:-$HOME/.local/bin}` without downloading or copying its source:

```sh
./install.sh --link
techne --version
techne diag
```

The launcher requires Bun and continues to run this checkout, so source edits are immediately visible. `techne diag` reports `installation: local` and resolves only local, non-secret configuration.

Install an immutable release through the Knowledge Islands Homebrew tap:

```sh
brew install knowledgeislands/tap/techne
techne diag
```

Homebrew installs a compiled release artifact, so Bun is not a runtime dependency and diagnostics report `installation: release`.

## Workspace

Use Bun `1.4.1` at the repository root:

```sh
bun install
bun run test
bun run self:techne -- --help
```

Turborepo coordinates package tasks. Install dependencies only at the root; package-local `node_modules`, Bun lockfiles and other package-manager lockfiles fail the repository test gate.

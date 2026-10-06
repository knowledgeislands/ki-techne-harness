# Develop Techne Harness

Use this guide when changing the controller application, Kubernetes resources, AWS templates, lifecycle operations or remote runtime payloads in Techne Harness. Changes to the `techne` executable, its installation or release lifecycle belong in `knowledgeislands/tools-techne`.

## Prepare the workspace

Use Bun `1.4.2` from the repository root and install dependencies only there:

```sh
bun install --frozen-lockfile
```

Package-local `node_modules`, Bun lockfiles and other package-manager lockfiles are prohibited.

## Choose the owning surface

- `apps/controller/` owns the Telegram-to-Kubernetes controller and its tests.
- `deploy/kubernetes/` owns controller and execution-target resources.
- `infra/aws/` owns replaceable AWS proof infrastructure.
- `operations/` owns local lifecycle implementations used behind the operator CLI.
- `deploy/runtime/` owns payloads that execute on controller or target hosts.
- `tooling/checks/` owns repository-only verification helpers.

Preserve the boundary with Techne Principal: this repository implements accepted architecture but does not redefine canonical roles or invariants locally.

## Execution profiles

Two execution profiles exist, each a separate literal with no shared base:

- The deterministic profile, built by `build_job()` and mirrored in `deploy/kubernetes/execution/job.example.json`, runs `/run` dispatch: no egress, a 300-second deadline, a read-only root with no volumes and a terminal restart policy.
- The agent-host profile, built by `build_agent_host_job()` and mirrored in `deploy/kubernetes/execution/agent-host.job.example.json`, is declared for interactive or long-running agent sessions: an eight-hour deadline, a per-session `/workspace` volume and DNS plus TCP 443 egress through `agent-host-network-policy.yaml`. It is not wired to dispatch.

Adding or changing the agent-host profile must never change the deterministic profile's egress, deadline, read-only root or restart policy; `test_deterministic_profile_fields_are_unchanged` enforces this. The idle reaper (`IDLE_TIMEOUT_SECONDS`) and operator-chat notification are declared, not yet implemented.

## Verify a change

Run the repository-local gate:

```sh
bun run test
bunx biome check .
ki repo audit --repo .
git diff --check
```

Run `bun run self:aws:validate` when AWS templates change and current authenticated read-only validation is authorised. Live deployment, provider mutation and credential admission require separate operational authority.

Before committing, stage only the intended paths and keep unrelated shared-tree changes unstaged.

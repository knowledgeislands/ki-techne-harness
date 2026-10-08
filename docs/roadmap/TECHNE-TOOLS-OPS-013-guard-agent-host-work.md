---
id: TECHNE-TOOLS-OPS-013
area: OPS
title: Guard agent-host work
kind: deliver
purpose: capability
project: agent-host
component: operations
horizon: next
status: draft
blocks: [TECHNE-TOOLS-OPS-015]
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T20:50:00Z
updated_at: 2026-10-08T07:32:00Z
---

# Guard Agent-Host Work

## Goal

Stopping, rebuilding or withdrawing the agent host never silently discards work that no remote holds. The host reports one clear safe, at-risk or unknown verdict, stop warns but always works, and rebuild and withdraw are separate operations that refuse while work is at risk unless the operator discards it by name.

## Context

This is the pilot of the agent-host durability rollout. Kris Brown approved the design on 2026-10-07; [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) in `ki-arcadia-principal` records it, with the merged report and Kris's decisions in that collection's `references/agent-host-durability-*` files. Decisions 1 to 4 and 8 apply here: only work in Git on a remote is safe; stop warns and never refuses while teardown fails closed with two overrides; no EBS snapshot route; rebuild and withdraw are two operations through the recipe's destroy path; and this harness record is the one pilot, delivered before the wave.

The gaps it closes, from the report: `host/status.sh` runs under `set -euo pipefail`, so one broken repository aborts the report, and it suppresses discovery errors, so an empty or missing workspace still reaches a normal summary; its `.git` match also finds worktree and submodule `.git` files. `stop.sh` and `destroy.sh` do not read the status at all, rebuild and withdrawal are one destroy path with a hand workaround to keep the GitHub token, and the operator guide understates the operator role, which may terminate the tagged instance under the `KI-ARCADIA-GOV-020` policy but cannot delete the stack.

The report's timing, "land the pilot before Kris's pending rebuild", is overtaken: the host was rebuilt on 2026-10-07 by a stack-only delete that kept the GitHub token, and setup re-converged. The pilot proceeds as the first record; the next live rebuild or withdrawal, run by the binding owner, is its live test.

Kris also rotated the GitHub token on 2026-10-07 with a 90-day expiry and decided that the operator guide's 30-day guidance changes to 90 days. That guide change is carried here because this record already rewrites the guide.

## Boundary

- In scope: the versioned status report with its exit statuses, per-repository tolerance, fail-closed inventory and read-only `--fetch`; the stop warning with a timeout and `--now`; rebuild and withdraw with the guard, both overrides, the same-host check and idempotent clean-up; the `recipe.toml` and manifest-test changes these need; offline checks with stubs; and the operator guide's protection boundary, sequences, corrected operator-role summary and 90-day token expiry.
- Out of scope: the `techne` CLI (`tools-techne` TECHNE-TOOL-CLI-006); declared pins, the expiry banner, the review date as a binding parameter, Codex instructions and the host marker (TECHNE-TOOLS-OPS-014); any live rebuild, withdrawal or other remote action, which is the binding owner's alone; and any EBS snapshot route, which decision 3 rejects.

## Current state

Captured and selected as the pilot on 2026-10-07 under Kris's grant; not yet planned. `host/status.sh` prints a text table and fails as described above. `stop.sh` stops without reading status. `destroy.sh` deletes the stack and, by hand, the parameters. The operator guide gives the GitHub token a 30-day expiry in two places, and prints the exemption review date from a constant in `host/status.sh`; the review has since been decided early as keep (`KI-ARCADIA-GOV-021`).

## Steps

- [ ] Give `host/status.sh` a versioned structured report (`techne/host-workspace/v1`) with `clean`, `at-risk` and `unknown` outcomes and exit statuses 0, 3, 4 and 1; make it tolerate one repository's failure, fail closed on inventory, match only working-tree `.git` directories, and add a read-only `--fetch`.
- [ ] Make `stop.sh` read the status with a short connect timeout, print anything at risk or unknown, and stop regardless; add `--now`.
- [ ] Replace the single destroy with rebuild (stack only, keeping `github-token` and `model-api-key`, then requiring a fresh Tailscale key and removal of the old device) and withdraw (stack and every parameter, then the manual footprint list), both through the recipe's destroy path under the binding's `aws.admin_profile`.
- [ ] Guard both: refuse unless clean; `--discard <repo>...` naming exactly the repositories at risk; `--discard-unreadable-host` with typed confirmation after printing the recovery routes (push, then a verified bundle to the Mac); a same-host check before deletion; idempotent clean-up.
- [ ] Update `recipes/direct-host/recipe.toml` and the recipe manifest check for the new status inputs and operations.
- [ ] Add offline checks with stubs for the clean, at-risk, unknown, unreachable, stopped and malformed cases.
- [ ] Update `docs/guides/operator/agent-host.md`: the protection boundary and disposable list, the work-matters and emergency sequences, the operator role's actual permissions, rebuild and withdraw, and the GitHub token's 90-day expiry in both places.
- [ ] Decide with Kris what the status output shows for the exemption review now that it is decided as keep, or leave it for TECHNE-TOOLS-OPS-014.

## Files touched

- `operations/aws/agent-host/host/status.sh`, `operations/aws/agent-host/status.sh`, `operations/aws/agent-host/stop.sh`, `operations/aws/agent-host/destroy.sh`, and new rebuild and withdraw entry points beside them
- `recipes/direct-host/recipe.toml`
- `tooling/checks/agent-host-aws-scripts.sh`, `tooling/checks/agent-host-workspace.sh`, `tooling/checks/recipe-manifest.py` and their fixtures
- `docs/guides/operator/agent-host.md`
- This record

## Verify

- `bun run test` and the repository's checks pass, including the new stubbed status, stop, rebuild and withdraw cases.
- `ki repo audit --repo .` passes.
- The operator guide states a 90-day token expiry and no 30-day expiry remains.

## Dependencies / blocks

None to start. TECHNE-TOOL-CLI-006 in `tools-techne` consumes the status contract and manifest this record changes, so it follows this pilot; TECHNE-TOOLS-OPS-014 follows it as part of the same wave.

## Documentation impact

### Decision Records

None in this repository: ODR-KI-ARCADIA-001 in `ki-arcadia-principal` records the design.

### Specifications

The structured status report is a new contract between this harness and `tools-techne`, carried by `recipe.toml` and its schema version under ADR-TECHNE-003; no separate specification.

### Guides

`docs/guides/operator/agent-host.md` changes as listed in the Steps, including the 90-day GitHub token expiry.

### Roadmap

The pilot's lessons are written into TECHNE-TOOL-CLI-006 and TECHNE-TOOLS-OPS-014 before they start.

## Discussion

### Pilot

The design-loop standard asks for one pilot before any parallel wave. This record is that pilot because the CLI reads the manifest and status contract it changes, and the harness scripts are the part a live rebuild exercises first.

### Open points for planning

- Whether rebuild and withdraw are new scripts or modes of `destroy.sh`, and how `recipe.toml` names them.
- How the same-host check identifies the host: instance ID from the status read compared with the stack's instance before deletion.
- What the status shows for the exemption review once it is no longer a scheduled date.

---
id: TECHNE-TOOLS-OPS-013
area: OPS
title: Guard agent-host work
kind: deliver
purpose: capability
project: agent-host
component: operations
horizon: next
status: ready
blocks: [TECHNE-TOOLS-OPS-015]
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T20:50:00Z
updated_at: 2026-10-08T08:14:00Z
---

# Guard Agent-Host Work

## Goal

Stopping, rebuilding or withdrawing the agent host never silently discards work that no remote holds. The host reports one clear safe, at-risk or unknown verdict, stop warns but always works, and rebuild and withdraw are separate operations that refuse while work is at risk unless the operator discards it by name.

## Context

This is the pilot of the agent-host durability rollout. Kris Brown approved the design on 2026-10-07, and [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) in `ki-arcadia-principal` records it. Its safe-work rule, status contract, stop, rebuild and withdraw, recovery routes and rollout entries apply here: only work in Git on a remote is safe; stop warns and never refuses while teardown fails closed with two overrides; no EBS snapshot is a recovery route; rebuild and withdraw are two operations through the recipe's destroy path; and this harness record is the one pilot, delivered before the wave.

The gaps it closes: `host/status.sh` runs under `set -euo pipefail`, so one broken repository aborts the report, and it suppresses discovery errors, so an empty or missing workspace still reaches a normal summary; its `.git` match also finds worktree and submodule `.git` files. `stop.sh` and `destroy.sh` do not read the status at all, rebuild and withdrawal are one destroy path with a hand workaround to keep the GitHub token, and the operator guide understates the operator role, which may terminate the tagged instance under the `KI-ARCADIA-GOV-020` policy but cannot delete the stack.

The host was rebuilt on 2026-10-07 by a stack-only delete that kept the GitHub token, and setup re-converged. The pilot proceeds as the first record; the next live rebuild or withdrawal, run by the binding owner, is its live test.

Kris also rotated the GitHub token on 2026-10-07 with a 90-day expiry and decided that the operator guide's 30-day guidance changes to 90 days. That guide change is carried here because this record already rewrites the guide.

## Boundary

- In scope: the versioned status report with its exit statuses, per-repository tolerance, fail-closed inventory and read-only `--fetch`; the stop warning with a timeout and `--now`; rebuild and withdraw with the guard, both overrides, the same-host check and idempotent clean-up; the `recipe.toml` and manifest-test changes these need; offline checks with stubs; and the operator guide's protection boundary, sequences, corrected operator-role summary and 90-day token expiry.
- Out of scope: the `techne` CLI (`tools-techne` TECHNE-TOOL-CLI-006); declared pins, the expiry banner, removing the exemption review-date line from host status, Codex instructions and the host marker (TECHNE-TOOLS-OPS-014); any live rebuild, withdrawal or other remote action, which is the binding owner's alone; and any EBS snapshot route, which ODR-KI-ARCADIA-001 rejects.

## Current state

Planned on 2026-10-08 under Kris's approval to plan and deliver the pilot. `host/status.sh` prints a text table and fails as described above. `stop.sh` stops without reading status. `destroy.sh` deletes the stack and every parameter, so a rebuild keeps the GitHub token only by hand. The operator guide gives the GitHub token a 30-day expiry in two places, and `host/status.sh` prints the exemption review date from a constant.

## Design

The planning choices, within ODR-KI-ARCADIA-001:

- **Report.** `host/status.sh --json` prints one `techne/host-workspace/v1` document: the host's hostname and cloud-init instance ID, the workspace, whether it fetched, an `outcome`, a `repositories` list with each repository's `state`, counts and problem, and a `problems` list for the inventory. Without `--json` it prints the existing text table with each repository's state and the inventory problems, followed by the expiry lines unchanged. The expiries stay out of the JSON report until TECHNE-TOOLS-OPS-014 adds its cached expiry file.
- **Exit statuses.** 0 `clean`, 3 `at-risk`, 4 `unknown`, 1 when the script itself fails. Through the Mac-side `status.sh`, SSH's own 255 means the host could not be reached.
- **Inventory.** The expected set is the binding's repository list, which the Mac-side `status.sh` now passes to the host; a run on the host reads `repositories.txt` beside the script. A missing workspace, an absent expected repository, a Git directory outside the declared set, a discovery error or a failed Git read makes the outcome `unknown`. Discovery matches only `.git` directories, so linked-worktree and submodule `.git` files are not repositories; a linked worktree's uncommitted files count towards its repository.
- **At risk.** A repository is at risk when it has uncommitted or untracked files, commits on any local branch or `HEAD` that no remote-tracking branch contains, or stashes. Ignored files are disposable.
- **Fetch.** `--fetch` runs `git fetch --all --prune` in each repository, which changes only remote-tracking refs; a failed fetch makes that repository `unknown`.
- **Stop.** `stop.sh` finds the running host first, then reads the status with a 5-second connect timeout, prints anything at risk or unknown, or that the status could not be read, and stops regardless. `--now` skips the read.
- **Rebuild and withdraw.** They are modes of the recipe's destroy path rather than new scripts: `destroy.sh rebuild` and `destroy.sh withdraw`, and a bare `destroy.sh` is refused. `recipe.toml` names them in a new `[operations]` table, each pointing at the `destroy` script, and declares the status contract in a new `[status]` table with its schema and exit statuses. Both run under the binding's `aws.admin_profile` and keep `CONFIRM_DESTROY_AGENT_HOST`. Rebuild deletes only the stack and then prints the rebuild sequence: remove the old tailnet device, store a fresh Tailscale key, provision and set up. Withdraw deletes the stack and all three parameters, then prints the manual footprint.
- **Guard.** Before deleting, both read the status in JSON. A report is readable only when it parses, carries the schema and its outcome matches the exit status. `clean` proceeds. `at-risk` refuses unless `--discard <repository>...` names exactly the repositories at risk. `unknown` or an unreadable report refuses unless `--discard-unreadable-host` is given; the script then prints the recovery routes, push and then a verified `git bundle` copied to the Mac, and requires typing `discard <stack name>`. Each override is refused where the other applies or nothing is at risk.
- **Same host.** The stack's `AgentHostInstanceId` output must equal the instance ID in a readable report, or both operations refuse. Only the unreadable-host override skips that check, and says so.
- **Idempotent.** A stack that is already gone skips the guard and the stack deletion, and missing parameters do not block withdrawal.

## Steps

- [ ] Give `host/status.sh` a versioned structured report (`techne/host-workspace/v1`) with `clean`, `at-risk` and `unknown` outcomes and exit statuses 0, 3, 4 and 1; make it tolerate one repository's failure, fail closed on inventory, match only working-tree `.git` directories, and add a read-only `--fetch`. Make the Mac-side `status.sh` pass the declared repository list, `--json`, `--fetch` and a connect timeout.
- [ ] Make `stop.sh` read the status with a short connect timeout, print anything at risk or unknown, and stop regardless; add `--now`.
- [ ] Replace the single destroy with rebuild (stack only, keeping `github-token` and `model-api-key`, then requiring a fresh Tailscale key and removal of the old device) and withdraw (stack and every parameter, then the manual footprint list), both through the recipe's destroy path under the binding's `aws.admin_profile`.
- [ ] Guard both: refuse unless clean; `--discard <repo>...` naming exactly the repositories at risk; `--discard-unreadable-host` with typed confirmation after printing the recovery routes (push, then a verified bundle to the Mac); a same-host check before deletion; idempotent clean-up.
- [ ] Update `recipes/direct-host/recipe.toml` and the recipe manifest check for the new status inputs, the `[status]` contract and the `[operations]` table.
- [ ] Add offline checks with stubs for the clean, at-risk, unknown, unreachable, stopped and malformed cases.
- [ ] Update `docs/guides/operator/agent-host.md`: the protection boundary and disposable list, the work-matters and emergency sequences, the operator role's actual permissions, rebuild and withdraw, and the GitHub token's 90-day expiry in both places.
- [x] The exemption review line in the status output: removed by TECHNE-TOOLS-OPS-014; this record leaves the line untouched. Decision 6 of the Techne run's decisions log settled on 2026-10-07 that the exemption has no fixed review date.

## Files touched

- `operations/aws/agent-host/host/status.sh`, `operations/aws/agent-host/status.sh`, `operations/aws/agent-host/stop.sh` and `operations/aws/agent-host/destroy.sh`
- `recipes/direct-host/recipe.toml`
- `tooling/checks/agent-host-aws-scripts.sh`, `tooling/checks/agent-host-workspace.sh`, `tooling/checks/recipe-manifest.py` and `tooling/checks/recipe-manifest.sh`
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

### Planning choices

Rebuild and withdraw became modes of `destroy.sh` because the ODR routes both through the recipe's destroy path and the manifest check ties each binding variable to the script that reads it; two wrapper scripts would duplicate every default. The same-host check uses the stack's `AgentHostInstanceId` output against the instance ID cloud-init records on the host, which the operator user can read without `sudo`. A Git directory outside the declared set makes the inventory `unknown`, as the ODR's fail-closed rule requires, even though such a checkout is disposable by rule: the unreadable-host override is the deliberate way past it.

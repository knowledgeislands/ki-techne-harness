---
id: TECHNE-TOOLS-OPS-013
area: OPS
title: Guard agent-host work
kind: deliver
purpose: capability
project: agent-host
component: operations
status: done
blocks: []
blocked_by: []
baseline_ref: c10575379e2cd45366c1d6f35aa08aff938f5ccb
created_at: 2026-10-07T20:50:00Z
updated_at: 2026-10-08T13:00:38Z
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

- **Report.** `host/status.sh --json` prints one `techne/host-workspace/v1` document: the host's hostname and `host.id`, a provider-defined identity of the machine (the cloud-init instance ID on AWS; a hardware or install UUID on owned hardware), the workspace, whether it fetched, an `outcome`, a `repositories` list with each repository's `state`, counts and problem, and a `problems` list for the inventory. Without `--json` it prints the existing text table with each repository's state and the inventory problems, followed by the expiry lines unchanged. The expiries stay out of the JSON report until TECHNE-TOOLS-OPS-014 adds its cached expiry file.
- **Exit statuses.** 0 `clean`, 3 `at-risk`, 4 `unknown`, 1 when the script itself fails. Through the Mac-side `status.sh`, SSH's own 255 means the host could not be reached.
- **Inventory.** The expected set is the binding's repository list, which the Mac-side `status.sh` now passes to the host; a run on the host reads `repositories.txt` beside the script. A missing workspace, an absent expected repository, a Git directory outside the declared set, a discovery error or a failed Git read makes the outcome `unknown`. Discovery matches only `.git` directories, so linked-worktree and submodule `.git` files are not repositories; a linked worktree's uncommitted files count towards its repository.
- **At risk.** A repository is at risk when it has uncommitted or untracked files, commits on any local branch or `HEAD` that no remote-tracking branch contains, or stashes. Ignored files are disposable.
- **Fetch.** `--fetch` runs `git fetch --all --prune` in each repository, which changes only remote-tracking refs; a failed fetch makes that repository `unknown`.
- **Stop.** `stop.sh` finds the running host first, then reads the status with a 5-second connect timeout, prints anything at risk or unknown, or that the status could not be read, and stops regardless. `--now` skips the read.
- **Rebuild and withdraw.** They are modes of the recipe's destroy path rather than new scripts: `destroy.sh rebuild` and `destroy.sh withdraw`, and a bare `destroy.sh` is refused. `recipe.toml` names them in a new `[operations]` table, each pointing at the `destroy` script, and declares the status contract in a new `[status]` table with its schema and exit statuses. Both run under the binding's `aws.admin_profile` and keep `CONFIRM_DESTROY_AGENT_HOST`. Rebuild deletes only the stack and then prints the rebuild sequence: remove the old tailnet device, store a fresh Tailscale key, provision and set up. Withdraw deletes the stack and all three parameters, then prints the manual footprint.
- **Guard.** Before deleting, both read the status in JSON. A report is readable only when it parses, carries the schema and its outcome matches the exit status. `clean` proceeds. `at-risk` refuses unless `--discard <repository>...` names exactly the repositories at risk. `unknown` or an unreadable report refuses unless `--discard-unreadable-host` is given; the script then prints the recovery routes, push and then a verified `git bundle` copied to the operator's machine, and requires typing `discard <stack name>`. Each override is refused where the other applies or nothing is at risk.
- **Same host.** The stack's `AgentHostInstanceId` output must equal the `host.id` in a readable report, or both operations refuse. Only the unreadable-host override skips that check, and says so.
- **Idempotent.** A stack that is already gone skips the guard and the stack deletion, and missing parameters do not block withdrawal.

## Steps

- [x] Give `host/status.sh` a versioned structured report (`techne/host-workspace/v1`) with `clean`, `at-risk` and `unknown` outcomes and exit statuses 0, 3, 4 and 1; make it tolerate one repository's failure, fail closed on inventory, match only working-tree `.git` directories, and add a read-only `--fetch`. Make the Mac-side `status.sh` pass the declared repository list, `--json`, `--fetch` and a connect timeout.
- [x] Make `stop.sh` read the status with a short connect timeout, print anything at risk or unknown, and stop regardless; add `--now`.
- [x] Replace the single destroy with rebuild (stack only, keeping `github-token` and `model-api-key`, then requiring a fresh Tailscale key and removal of the old device) and withdraw (stack and every parameter, then the manual footprint list), both through the recipe's destroy path under the binding's `aws.admin_profile`.
- [x] Guard both: refuse unless clean; `--discard <repo>...` naming exactly the repositories at risk; `--discard-unreadable-host` with typed confirmation after printing the recovery routes (push, then a verified bundle copied to the operator's machine); a same-host check before deletion; idempotent clean-up.
- [x] Update `recipes/direct-host/recipe.toml` and the recipe manifest check for the new status inputs, the `[status]` contract and the `[operations]` table.
- [x] Add offline checks with stubs for the clean, at-risk, unknown, unreachable, stopped and malformed cases.
- [x] Update `docs/guides/operator/agent-host.md`: the protection boundary and disposable list, the work-matters and emergency sequences, the operator role's actual permissions, rebuild and withdraw, and the GitHub token's 90-day expiry in both places.
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

The structured status report is a new contract between this harness and `tools-techne`, carried by `recipe.toml` and its schema version under ADR-KI-ARCADIA-006; no separate specification.

### Guides

`docs/guides/operator/agent-host.md` changes as listed in the Steps, including the 90-day GitHub token expiry.

### Roadmap

The pilot's lessons are written into TECHNE-TOOL-CLI-006 and TECHNE-TOOLS-OPS-014 before they start.

## Review

### Delivered

- `host/status.sh` prints a `techne/host-workspace/v1` document with `--json`, reports `clean`, `at-risk` or `unknown` with exit statuses 0, 3 and 4 (1 for its own failure), fails closed on the inventory, tolerates one repository's failed Git read, counts a linked worktree's uncommitted files towards its repository and adds a read-only `--fetch`. The Mac-side `status.sh` passes the binding's declared repositories, `--json`, `--fetch` and `--connect-timeout`.
- `stop.sh` reads the status with a 5-second connect timeout, warns about anything at risk, unknown or unreadable, and always stops; `--now` skips the read.
- `destroy.sh rebuild` and `destroy.sh withdraw` replace the single teardown, guarded by the status, `--discard <repository>...`, `--discard-unreadable-host` with a typed confirmation, and a same-host check, and both may be rerun after a partial clean-up.
- `recipe.toml` declares the `[status]` contract and the `[operations]` table, and the readers of the Tailscale name, repository list and workspace; the manifest check validates them.
- The operator guide states the protection boundary and disposable list, the status outcomes, the stop warning, rebuild and withdraw with the guard and recovery routes, the work-matters and emergency sequences, the operator role's actual permissions and the 90-day token expiry.
- Review tweaks: Kris approved two review proposals before review (Decision 11 of the Techne run's decisions log, from the generic-review report's P1 and P2).
  - **P1.** The report's `host.instance_id` is now `host.id`, documented as a provider-defined identity of the machine: the cloud-init instance ID on AWS, and a hardware or install UUID on owned hardware. The schema stays `techne/host-workspace/v1` because nothing outside this repository reads the field yet; `tools-techne` takes its instance ID from AWS, not from this report. The same-host check stays in the AWS `destroy.sh`, which compares `host.id` with the stack's `AgentHostInstanceId` output. `host/status.sh`, `destroy.sh`, the stubbed reports in `agent-host-aws-scripts.sh` and the guide changed.
  - **P2.** The guide's opening paragraph no longer names the 2026-11-06 review date, since the exemption has no fixed review date. The recovery route in the guide and in `destroy.sh` says the bundles are copied to the operator's machine rather than to the Mac. Other mentions of the Mac in the guide are outside P2 and unchanged.

### Change Summary

- `5c1515c` feat(agent-host): report host work as a versioned status contract — `host/status.sh`, `status.sh`, `tooling/checks/agent-host-workspace.sh`, and this record to in-progress.
- `c47c970` feat(agent-host): guard stop, rebuild and withdraw on the host's status — `stop.sh`, `destroy.sh`, `recipe.toml`, `recipe-manifest.py`, `recipe-manifest.sh`, `agent-host-aws-scripts.sh`.
- `2ac1fe5` docs(agent-host): document the protection boundary, rebuild and withdraw — `docs/guides/operator/agent-host.md`.
- fix(agent-host): name the host by a provider-defined `host.id` (review tweaks P1 and P2) — `host/status.sh`, `destroy.sh`, `agent-host-aws-scripts.sh`, the operator guide and this record.

Baseline `c10575379e2cd45366c1d6f35aa08aff938f5ccb`.

### Verification

- `bun run test`: pass, including `agent-host-workspace.sh`, `agent-host-aws-scripts.sh`, `recipe-manifest.sh` and shellcheck over every operations and check script.
- New stubbed cases: status clean, at-risk, unknown for an absent, undeclared or broken repository and a missing workspace, a linked worktree, `--fetch` leaving working trees alone; stop for clean, at-risk, unknown, unreachable, malformed, mismatched-exit, `--now` and a stopped host; rebuild and withdraw for each outcome, each override and its refusals, a wrong typed confirmation, another instance's status, an already-gone stack, a second binding and a foreign stack tag; manifest refusals for the status schema, a shared exit status, an operation's unknown script, a missing operation and a reader that does not read its variable.
- `ki repo audit --repo .`: PASS.
- `grep -n "30 days\|30-day" docs/guides/operator/agent-host.md`: no match.
- Nothing ran against AWS, Tailscale, SSM or the host.

### Outstanding concerns

- An empty repository with no commits reports `unknown` (it cannot list unpushed commits), which is fail-closed but may surprise.
- The status report still prints the exemption review line; TECHNE-TOOLS-OPS-014 removes it, as the Steps record. The guide's Status section still describes that line because the output still has it.
- No live run: the guard, the stop warning and the same-host check have been exercised only against stubs.

### Post-change review

The change stays inside the planned files. The status contract and `[status]` table are new inputs for TECHNE-TOOL-CLI-006 in `tools-techne`, which this record does not change.

### Mini recap

The agent host now says whether its work is clean, at risk or unknown; stop warns and always works, and rebuild and withdraw refuse to discard unlanded work unless the operator names it or confirms an unreadable host.

## Done

Accepted 2026-10-08 under Kris's decision in the Techne decisions log, Decision 12 (2026-10-08): "Accept KI-ARCADIA-GOV-031, Accept TECHNE-TOOLS-OPS-013" (accept through ki-accept and prune both). The exemption review line and the guide's description of it are left for TECHNE-TOOLS-OPS-014, as planned; the first live stop or teardown remains the first live test of the guard. TECHNE-TOOLS-OPS-015 no longer waits on this record, so both dependency fields are cleared.

## Discussion

### Pilot

The design-loop standard asks for one pilot before any parallel wave. This record is that pilot because the CLI reads the manifest and status contract it changes, and the harness scripts are the part a live rebuild exercises first.

### Planning choices

Rebuild and withdraw became modes of `destroy.sh` because the ODR routes both through the recipe's destroy path and the manifest check ties each binding variable to the script that reads it; two wrapper scripts would duplicate every default. The same-host check uses the stack's `AgentHostInstanceId` output against the host's `host.id`, which on AWS is the instance ID cloud-init records on the host, which the operator user can read without `sudo`. A Git directory outside the declared set makes the inventory `unknown`, as the ODR's fail-closed rule requires, even though such a checkout is disposable by rule: the unreadable-host override is the deliberate way past it.

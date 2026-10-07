---
id: TECHNE-TOOLS-OPS-011
area: OPS
title: Manage agent-host footprint
theme: operations
horizon: now
status: ready
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T04:41:13Z
updated_at: 2026-10-07T06:56:00Z
---

# Manage Agent-Host Footprint

## Goal

The working state on `ki-techne-agent-host` is as reproducible as the host itself. Kris can rebuild the host and get back the same clones, identity, tools and skills by rerunning one step. Stopping or tearing the host down never silently loses work, and Kris can see in one place what expires and when.

## Context

Origin: Kris, 2026-10-07, after the first remote session on the host.

`TECHNE-TOOLS-OPS-009` delivered the host as a repository-owned CloudFormation stack, with a boot script, a kill switch (`stop.sh`) and a teardown (`destroy.sh`), under the prototype that `KI-ARCADIA-GOV-020` in `ki-arcadia-principal` authorises. The stack reproduces the machine and the base runtimes. It does not reproduce what an operator then adds by hand. In the first session, that was the repository clones under `~/workspaces/kit/`, the Git identity, the `ki` CLI, the KI skills under `~/.claude/skills/` and the Claude Code sign-in. Rebuilding the host today means repeating those steps from memory.

The host also holds a second checkout of repositories that Kris works on from the Mac. Work committed on the host but not pushed exists nowhere else, and `stop.sh` and `destroy.sh` do not check for it. `KI-HARNESS-GOV-147` in `ki-agentic-harness` addresses the same risk for coordinated worktrees: it makes the branch, not the checkout, the durable unit, so that removing a checkout is always safe. The agent host is that problem at the scale of a whole machine.

Several credentials and authorities on the host expire on their own. The fine-grained GitHub token at `/ki/techne/agent-host/github-token` expires after 30 days. The Tailscale node key expires on the tailnet's key-expiry schedule unless expiry is disabled for the device. The prototype authority itself lapses on 2026-11-06, the review date that `KI-ARCADIA-GOV-021` tracks. None of these dates is visible from the host or from this repository.

## Boundary

Adopted into Now and planned on 2026-10-07 on Kris's instruction ("I want OPS-011 so it's re-runnable", and "codex would be good too"), which is also the approval to mark it Ready and the explicit authority, under the Techne Programme Hold, to run the setup live against `ki-techne-agent-host` as `techne` over Tailscale SSH. That authority covers this host's home directory only: no AWS or Tailscale API call, no stack change to a running host, no service.

In scope:

- **Rerunnable workspace setup.** One idempotent command, run from the Mac, converges a fresh or existing host to the declared state as `techne`, without `sudo`: the Git identity and settings; the repository set, declared in one data file and laid out as on the Mac, cloned when missing, never touching a dirty checkout and fast-forwarding clean ones only on request; mise with the Bun and Node pins and each repository's own pins; dependencies; one consolidated shell environment file sourced by `.profile`, `.bashrc` and husky's `init.sh`, replacing the hand-made blocks and `~/.ki-host-env`; the `ki` CLI at a pinned version with bootstrap, local harness development, registry and estate repair; the Codex CLI for `techne` at a pinned version, with `codex login` left to Kris; Kris's personal Claude instructions rendered from chezmoi on the Mac; and the documented user setting that keeps auto-memory off. A second run reports no changes.
- **Read-only status.** One command reports, per repository on the host, uncommitted files, commits on no remote, stashes and the branch's position against its last-fetched upstream, and the known expiry dates: the GitHub token's, read from GitHub's response header; the Tailscale node key's, from the local `tailscale` client; and the prototype lapse on 2026-11-06.
- **zsh in the host build.** `zsh` joins the stack's package list for future builds. The current host cannot install it without `sudo`, so it stays without zsh until it is rebuilt.
- The runbook's setup and status sections.

Left as follow-ups, not in this record:

- **Work durability in `stop.sh` and `destroy.sh`.** The status command gives Kris the evidence by hand; making stop and teardown refuse or warn on it changes the AWS-side scripts and their order of operations, so it is a separate record.
- **The two-checkout rule and the designated roadmap writing checkout.** These need a decision, not a script.
- **Currency.** The pins live in one place and rerunning setup applies them, but nothing updates them; a shared chezmoi host profile or an update routine is a separate choice.
- **A standing expiry view** such as a message of the day; the status command and the runbook cover it for now.

Out of scope: credentials, MCP configuration or any other `~/.claude` content beyond the five instruction files and the one auto-memory setting; the Claude Code and Codex sign-ins; any change to the stack's network, role or exposure bounds; the 2026-11-06 renewal decision, which `KI-ARCADIA-GOV-021` owns; the Mac's chezmoi source, which this work reads with `chezmoi cat` and never applies.

## Current state

The host was set up by hand on 2026-10-07 (17 clones, `ki` 0.7.1, mise 2026.10.3 with Bun 1.4.2 and Node 24, `~/.ki-host-env`, and the PATH blocks the Discussion below lists). Nothing in this repository can repeat it. The token now reads all 21 Knowledge Islands repositories on the Mac, including the four it could not read during the hand set-up, and has write access. Codex, Kris's Claude instructions and the auto-memory setting are absent on the host, so the estate audit fails `RUNTIMES-2` and `SELECT-1`.

## Steps

- [ ] Add `operations/aws/agent-host/host/repositories.txt`, the declared repository set (path under `~/workspaces/kit` and HTTPS origin), mirroring the Mac's 21 Knowledge Islands checkouts.
- [ ] Add `operations/aws/agent-host/host/converge.sh`, the host-side, idempotent convergence, runnable on the host from the harness clone or from a staged copy, which prints each change and ends with a summary that says `no changes` when nothing changed.
- [ ] Add `operations/aws/agent-host/host/status.sh`, the read-only status report.
- [ ] Add `operations/aws/agent-host/setup.sh` and `status.sh`, the Mac-side entry points: setup renders the Claude instructions with `chezmoi cat`, stages them with the host scripts over one SSH connection and runs the convergence; status runs the host status over SSH.
- [ ] Add a stub-backed test, `tooling/checks/agent-host-workspace.sh`, run by the existing offline checks: a temporary home with local Git origins and stub `mise`, `ki`, `bun`, `codex` and `claude`, asserting first-run changes, a second run with no changes, an untouched dirty checkout, a fast-forwarded clean one, the migration of the hand-made shell blocks, the merged Claude setting and the status report; and extend the ShellCheck list to the new scripts.
- [ ] Add `zsh` to the stack's package list.
- [ ] Update the runbook with the setup and status commands.
- [ ] Run the local gates, then run setup live twice and verify on the host.

## Files touched

- `operations/aws/agent-host/setup.sh` (new)
- `operations/aws/agent-host/status.sh` (new)
- `operations/aws/agent-host/host/converge.sh` (new)
- `operations/aws/agent-host/host/status.sh` (new)
- `operations/aws/agent-host/host/repositories.txt` (new)
- `tooling/checks/agent-host-workspace.sh` (new)
- `tooling/checks/controller.sh`
- `infra/aws/agent-host-stack.yaml`
- `operations/README.md`
- `docs/guides/operator/agent-host.md`
- This record

## Verify

- Local: `bun run test` (which runs the offline checks, ShellCheck and the new stub test), `bunx biome ci .`, `bunx rumdl check .`, `ki repo audit --repo .` and `git diff --check`.
- Live, against `ki-techne-agent-host`: `setup.sh` twice, the second reporting no changes; `ssh ki-techne-agent-host 'command -v bun codex ki claude'` resolves all four in a non-interactive shell; `git hook run pre-commit` passes in two husky repositories with `PATH` reduced to `/usr/bin:/bin`; `ki doctor` passes; `ki repo --estate audit` on the host, with any remaining failure explained; `status.sh` reports every repository and the three expiry entries.

## Dependencies / blocks

None in this repository. The hand set-up and the token's repository access are already in place.

## Documentation impact

### Decision Records

None.

### Specifications

None.

### Guides

The operator runbook gains the workspace setup and status commands.

### Roadmap

This record. The follow-ups above are captured separately when Kris wants them.

## Discussion

### Rerunnable setup

One idempotent step, run as `techne` after the stack's boot script, would bring the host to a known working state on top of the harness stack: clone or update a declared list of repositories, set the Git identity, install the `ki` CLI, install or sync the KI skills, and confirm that Claude Code is installed and ready to sign in. Running it twice changes nothing. It could live in the boot script, in a separate script in `operations/aws/agent-host/`, or in a chezmoi-managed source shared with the Mac; the next topic bears on that choice. Secrets stay out of it: the GitHub credential helper and the interactive Claude Code sign-in already avoid storing keys, and the setup step must keep it that way.

### Work durability

`stop.sh` and `destroy.sh` should refuse, or at least warn and require confirmation, while any declared repository on the host has uncommitted changes, unpushed commits or stashes. This is the same principle as `KI-HARNESS-GOV-147`: work must exist on a branch on the remote before the checkout that holds it can be discarded. The check runs on the host, but the scripts run from the Mac with AWS credentials and the host has no session-manager access. That suggests either a check over Tailscale SSH before the AWS call, or a host-side script that Kris runs first. A stopped host keeps its volume, so the refusal matters most for teardown. A warning on stop still catches work left behind on a host that may later be torn down by the lapse.

### Two checkouts of the same repositories

The Mac and the host each hold a checkout of the same repositories. The working rule is simple: push where you worked, and pull before working elsewhere. It needs to be written down where both sides see it, and ideally checked, for example by a shell prompt or session-start hook that shows unpushed or behind-remote state. The roadmap write locus in the `ki-work-roadmap` standard adds a sharper case: roadmap records and their serial reservations need one designated writing checkout per repository. A reservation committed on the host but not pushed could collide with one made on the Mac. Which checkout is designated, or how the two serialise, is an open question.

### Keeping tools and skills current

The `ki` CLI, the KI skills, Claude Code and Node.js drift on the host unless something updates them. The Mac manages these through chezmoi. Sharing that model, a chezmoi source with a host profile that installs and updates the same tools and skills, would keep the two machines in step and give one place to change versions. The alternative is a host-only update script in this repository, which is simpler but drifts from the Mac. `TECHNE-TOOLS-OPS-009` already left SSH and Zed entries and the operator profile to the chezmoi source, which favours sharing.

### Expiry view

One view, on the host and in the runbook, should show what expires and when:

- the GitHub token, 30 days from creation, with the rotation steps in `docs/guides/operator/agent-host.md`;
- the Tailscale node key, from the device's key expiry in the admin console, or a note that expiry is disabled for it;
- the prototype lapse on 2026-11-06, under `KI-ARCADIA-GOV-020` and `KI-ARCADIA-GOV-021`.

The GitHub token and the lapse fall close together, so a renewal under `KI-ARCADIA-GOV-021` also needs a new token. The view could be a message of the day, a `ki` or shell command, or a table in the runbook; a dated table alone goes stale.

### Sources and relations

- `TECHNE-TOOLS-OPS-009` (this repository): the host stack, boot script, kill switch, teardown and runbook this record builds on.
- `KI-ARCADIA-GOV-020` (`ki-arcadia-principal`): the prototype's authority and bounds.
- `KI-ARCADIA-GOV-021` (`ki-arcadia-principal`): the 2026-11-06 review, renewal or teardown.
- `KI-HARNESS-GOV-147` (`ki-agentic-harness`): the branch, not the checkout, as the durable unit of work.

These are cross-repository references and are not recorded in `blocks` or `blocked_by`.

### Identifier collision - 2026-10-07

This record was first pushed as `TECHNE-TOOLS-OPS-010` from the host checkout, and that ID collided with `TECHNE-TOOLS-OPS-010` (diagram the agent-host runbook), which the Mac checkout had already reserved and pushed. Both reservation commits made the same ledger change, so the rebase dropped the host's one as already applied and raised no conflict. The record was renumbered to `TECHNE-TOOLS-OPS-011` under a fresh reservation. This is the two-checkout serial risk described above under "Two checkouts of the same repositories", happening for real.

### Hand-applied PATH fix - 2026-10-07

Bun and Node were installed through mise, but their shims were not on `PATH` in shells that skip `~/.bashrc` or stop at its interactive-only early return. A plain `git commit` from Zed's Agent Panel or Claude Code's tool shells therefore failed the husky pre-commit hook for a missing `bun`. So that commits work on the train on 2026-10-08, the fix was applied by hand on the host on 2026-10-07. It must be folded into the rerunnable setup step above rather than left as a one-off.

Files touched under `/home/techne`, each marked `# ki-agent-host: mise shims (TECHNE-TOOLS-OPS-011)` and adding `~/.local/share/mise/shims` and `~/.local/bin` to `PATH` only when absent:

- `~/.profile` - block prepended; backup `~/.profile.bak-ops011-20261007050058`;
- `~/.bashrc` - block prepended above Ubuntu's interactive-only early return; backup `~/.bashrc.bak-ops011-20261007050058`;
- `~/.config/husky/init.sh` - new file, which husky 9 sources before every hook, so hooks find `bun` whatever shell started Git.

The earlier `~/.ki-host-env`, sourced from both start-up files, was left in place. With `PATH` reduced to `/usr/bin:/bin`, `git hook run pre-commit` passed in `ki-techne-harness` and `tools-ki`.

### Open questions

- Does the setup step belong in the boot script, a separate script in this repository, or a shared chezmoi source?
- Should teardown refuse outright on unlanded work, or warn and require an explicit override?
- Is the Mac or the host the designated roadmap writing checkout, or does each repository name one?
- Is Tailscale key expiry left on for the host's device, and if so, what is its current expiry date?
- Does any of this justify work before the 2026-11-06 review, or should it wait for a renewal decision?

### Planning decisions - 2026-10-07

- **Run from the Mac, converge on the host.** The Mac holds the chezmoi source for the Claude instructions and the operator's SSH access, and a fresh host has no harness clone to run from. So `setup.sh` runs on the Mac and streams the host scripts and rendered instructions over one SSH connection, and the convergence itself runs on the host, where the state is. The same `host/converge.sh` also runs directly on the host from the harness clone, skipping only the Claude instructions, which need the Mac.
- **Not in the boot script.** The boot script runs as root once, before Kris signs in and before the token's repository access is known; the workspace changes after build and must be rerunnable, so it stays a separate user-level step.
- **Codex through mise.** The global mise configuration pins `npm:@openai/codex` beside Bun and Node, so Codex has a shim on `PATH` for Zed and the terminal and changes version in the same place. Creating `~/.agents` lets `ki bootstrap` detect the Codex runtime and install its skills.
- **Auto-memory.** The documented user setting is `autoMemoryEnabled: false` in `~/.claude/settings.json`, which the Mac already has; setup merges that one key and leaves the rest of the file alone.

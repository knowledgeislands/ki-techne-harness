---
id: TECHNE-TOOLS-OPS-011
area: OPS
title: Manage agent-host footprint
theme: operations
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: a8e68e18f8d2c6109c77fa833589b980eab2a9c2
created_at: 2026-10-07T04:41:13Z
updated_at: 2026-10-07T09:11:11Z
---

# Manage Agent-Host Footprint

## Goal

The working state on `ki-techne-agent-host` is as reproducible as the host itself. Kris can rebuild the host and get back the same clones, identity, tools and skills by rerunning one step. Stopping or tearing the host down never silently loses work, and Kris can see in one place what expires and when.

## Context

Origin: Kris, 2026-10-07, after the first remote session on the host.

`TECHNE-TOOLS-OPS-009` delivered the host as a repository-owned CloudFormation stack, with a boot script, a kill switch (`stop.sh`) and a teardown (`destroy.sh`), under the prototype that `KI-ARCADIA-GOV-020` in `ki-arcadia-principal` authorises. The stack reproduces the machine and the base runtimes. It does not reproduce what an operator then adds by hand. In the first session, that was the repository clones under `~/workspaces/kit/`, the Git identity, the `ki` CLI, the KI skills under `~/.claude/skills/` and the Claude Code sign-in. Rebuilding the host today means repeating those steps from memory.

The host also holds a second checkout of repositories that Kris works on from the Mac. Work committed on the host but not pushed exists nowhere else, and `stop.sh` and `destroy.sh` do not check for it. `KI-HARNESS-GOV-147` in `ki-agentic-harness` addresses the same risk for coordinated worktrees: it makes the branch, not the checkout, the durable unit, so that removing a checkout is always safe. The agent host is that problem at the scale of a whole machine.

Several credentials and authorities on the host expire on their own. The fine-grained GitHub token at `/ki/techne/agent-host/github-token` expires after 30 days. The Tailscale node key expires on the tailnet's key-expiry schedule unless expiry is disabled for the device. The host's authority itself is a standing exemption with no lapse, set through `KI-ARCADIA-GOV-023` and recorded in `GDR-KI-ARCADIA-004`, with a scheduled review on 2026-11-06. None of these dates is visible from the host or from this repository.

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

- [x] Add `operations/aws/agent-host/host/repositories.txt`, the declared repository set (path under `~/workspaces/kit` and HTTPS origin), mirroring the Mac's 21 Knowledge Islands checkouts.
- [x] Add `operations/aws/agent-host/host/converge.sh`, the host-side, idempotent convergence, runnable on the host from the harness clone or from a staged copy, which prints each change and ends with a summary that says `no changes` when nothing changed.
- [x] Add `operations/aws/agent-host/host/status.sh`, the read-only status report.
- [x] Add `operations/aws/agent-host/setup.sh` and `status.sh`, the Mac-side entry points: setup renders the Claude instructions with `chezmoi cat`, stages them with the host scripts over one SSH connection and runs the convergence; status runs the host status over SSH.
- [x] Add a stub-backed test, `tooling/checks/agent-host-workspace.sh`, run by the existing offline checks: a temporary home with local Git origins and stub `mise`, `ki`, `bun`, `codex` and `claude`, asserting first-run changes, a second run with no changes, an untouched dirty checkout, a fast-forwarded clean one, the migration of the hand-made shell blocks, the merged Claude setting and the status report; and extend the ShellCheck list to the new scripts.
- [x] Add `zsh` to the stack's package list.
- [x] Update the runbook with the setup and status commands.
- [x] Run the local gates, then run setup live twice and verify on the host.
- [x] Deviation, 2026-10-07: set the OS hostname to `ki-techne-agent-host` in the stack's boot script, and align the status report and runbook with the standing exemption.

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
- `docs/guides/operator/agent-host-architecture.archify.json` (deviation)
- `tooling/checks/agent-host-stack.rb` (deviation)
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

## Review

### Delivered

The approved boundary: a rerunnable workspace setup driven from the Mac, a read-only status report, `zsh` in the host build and the runbook. Excluded, as planned and left as follow-ups: work durability in `stop.sh` and `destroy.sh`, the two-checkouts rule, keeping the host current, and a standing expiry view beyond the status report. Baseline `a8e68e18f8d2c6109c77fa833589b980eab2a9c2` (the ready plan); delivery in `634c1f1`, `f4d42be`, `c071d71`, `d7ccac2` and the commit that moves this record to `awaiting-review`.

### Change Summary

- `operations/aws/agent-host/host/repositories.txt`: the 21 Knowledge Islands repositories on the Mac, by path and HTTPS origin.
- `operations/aws/agent-host/host/converge.sh`: idempotent convergence of the Git identity and settings, the repository set (clone if missing, skip a dirty checkout, fast-forward a clean one only with `--pull`), mise 2026.10.3 with global pins for Bun 1.4.2, Node 24 and Codex CLI 0.160.1, each repository's mise tools and Bun dependencies, one environment file `~/.config/ki-agent-host/env.sh` sourced from `.profile`, `.bashrc` and Husky's `init.sh` (folding in the hand-made blocks and `~/.ki-host-env`, keeping `KNIP_DISABLE_RAW_TRANSFER=1`), `ki` 0.7.1 by its signed installer, `ki bootstrap`, the local `ki-agentic-harness`, the registry and estate repair, the staged Claude instructions and `autoMemoryEnabled: false`. It backs up what it replaces, compares content before writing and ends with a summary that says `no changes` when nothing changed.
- `operations/aws/agent-host/host/status.sh`: read-only report of branch, uncommitted files, unpushed commits, stashes and upstream counts per repository, and the GitHub token, Tailscale key and prototype expiry dates. The token reaches `curl` on standard input only.
- `operations/aws/agent-host/setup.sh` and `status.sh`: the Mac entry points. Setup renders `CLAUDE.md`, `communication.md`, `delegation.md`, `memory-scope.md` and `markdown.md` with `chezmoi cat`, adds a source header, and stages them with the host scripts over one SSH connection.
- `tooling/checks/agent-host-workspace.sh`, run by `tooling/checks/controller.sh`, which also adds the host scripts to ShellCheck: stub-backed checks of first-run changes, a second run with no changes, the dirty and behind checkouts, the shell-block migration, the merged Claude setting, Codex detection, estate repair and the status report.
- `infra/aws/agent-host-stack.yaml`: `zsh` in the boot script's package list.
- `docs/guides/operator/agent-host.md` and `operations/README.md`: "Workspace setup" and "Status" sections, and a status pointer in the kill switch.
- Deviation from the plan: the first live run exposed three behaviours the plan did not foresee, fixed in `c071d71`. `ki dev local set` refuses while the checkout is active, so the step skips the set when the path is already recorded. Plain `ki bootstrap` reuses configured agents, so the script passes `--refresh` when an agent home exists but the agent is not configured. `ki repo --estate diag` exits 0 while projections are repairable, so repair keys on its counts. The stubs now reproduce each.
- Deviation after review submission, approved by Kris on 2026-10-07 at 09:10 CEST and folded in while this record is open: the host reported the AWS default hostname `ip-10-90-0-40`. The boot script in `infra/aws/agent-host-stack.yaml` now sets the OS hostname to `ki-techne-agent-host` with `hostnamectl`, writes a cloud-init drop-in with `preserve_hostname: true` so later boots keep it, and adds `127.0.1.1 ki-techne-agent-host` to `/etc/hosts` so `sudo` and local lookups resolve it; `tooling/checks/agent-host-stack.rb` asserts all three. It takes effect at the next build; the live stack and instance were not changed, so the current host keeps its name until it is rebuilt, as the runbook says. In the same pass, the status report, runbook and architecture diagram source stop describing a prototype lapse: `KI-ARCADIA-GOV-023` made the exemption standing, recorded in `GDR-KI-ARCADIA-004`, with no lapse and a scheduled review on 2026-11-06.

### Verification

- Local: `bun run test` passes, including the new checks and ShellCheck; `bunx biome ci .`, `bunx rumdl check .` and `git diff --check` are clean; `ki repo audit --repo .` passes with 18 skills.
- Live, as `techne` over SSH only. The first run made 32 changes, including the four new clones, the Codex pin, the environment migration and the Claude instructions, with one failure (`ki dev local set`). After the fix, a run made 2 changes (the estate repair and a fast-forward), and the next run reported `CHANGES=0` and `no changes`.
- `command -v bun codex ki claude` in a non-interactive SSH command resolves all four; `codex --version` reports 0.160.1 and `KNIP_DISABLE_RAW_TRANSFER` is 1.
- `git hook run pre-commit` with `PATH=/usr/bin:/bin` passes in `ki-techne-harness` and `tools-ki`.
- `ki doctor`: healthy, 12 checks pass, both `claude-code` and `chatgpt-codex` ready, local harness active.
- `ki repo --estate diag`: 21 repositories healthy. `ki repo --estate audit` fell from 99 failing findings to 22. `SELECT-1` and `RUNTIMES-2` now pass. The remaining 22 are 21 `BIND-2` findings, because the host has no `~/.config/ki/mcp-servers.yaml` and MCP configuration is out of scope, and one `TEST-5` in `tools-ki`, whose completion test needs `zsh`, which the running host cannot install without `sudo`. Two warnings are content freshness in `ki-agentic-harness`.
- Deviation: `bun run test` (stack validation with `bash -n` and ShellCheck on the rendered user data, and the workspace checks), `bunx biome ci .`, `bunx rumdl check .`, `git diff --check` and `ki repo audit --repo .` (pass, 18 skills) are clean. `cfn-lint` is not installed, so the repository's own stack check stands in for it. Nothing was run against the live host or AWS.
- `status.sh`: 21 repositories, none at risk; GitHub token expires 2026-11-06, the Tailscale key does not expire, and the prototype authority lapses 2026-11-06. That was the wording of the run on 2026-10-07; the status script now reports the standing exemption's review date instead (fix `888101b`), verified locally only and not re-run live.

### Outstanding concerns

- **The hostname arrives only with a rebuild.** The current host stays `ip-10-90-0-40` until Kris rebuilds it under the standing exemption.
- **Codex is not signed in.** Kris runs `codex login` as `techne` on the host.
- **`zsh` arrives only with a rebuild.** Until then `tools-ki`'s coverage test fails on the host.
- **`BIND-2` fails everywhere on the host** while it has no MCP source. Whether the host should have one is a separate decision.
- **Old hand-made backups remain.** `~/.profile.bak-ops011-*` and `~/.bashrc.bak-ops011-*` from the hand set-up are left for Kris to delete.
- **The repository set is a copy.** `repositories.txt` mirrors the Mac by hand; a new repository needs a line there.
- **Pins need upkeep.** The `ki`, mise, Bun, Node and Codex versions are pinned in `converge.sh`; keeping them current is the currency follow-up.

### Post-change review

The goal is met for the in-scope part: one rerunnable command rebuilds the workspace, a second run changes nothing, and Kris can see unlanded work and expiry dates before stopping the host. Scope held; the three fixes stayed inside the setup script and its checks. Regression risk is low for the controller, which is untouched; on the host the script never touches a dirty checkout, backs up replaced files and never copies credentials. The review was the implementing agent's own check against the plan, the gates and the live host, not an independent reviewer.

### Mini recap

OPS-011's first slice turns the hand set-up of the agent host into `setup.sh` and `status.sh`, verified live: a second run changes nothing, tools and hooks resolve non-interactively, and the estate audit's remaining failures are the MCP source and `zsh`. Proposed learning route: the three `ki` behaviours found live (`dev local set` while active, bootstrap without `--refresh`, `diag` exit status) to `tools-ki` through its own records if Kris wants them changed.

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
- the prototype lapse on 2026-11-06, under `KI-ARCADIA-GOV-020` and `KI-ARCADIA-GOV-021`. Since superseded: `KI-ARCADIA-GOV-023` made the exemption standing (`GDR-KI-ARCADIA-004`), with no lapse and a scheduled review on 2026-11-06, which the status script now reports (fix `888101b`).

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

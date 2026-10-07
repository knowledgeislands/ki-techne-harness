---
id: TECHNE-TOOLS-OPS-011
area: OPS
title: Manage agent-host footprint
theme: operations
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T04:41:13Z
updated_at: 2026-10-07T04:45:48Z
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

- Triage only: this record captures the concern and does not plan or implement it.
- No change to the controller or to the agent-host stack's network, role or exposure bounds; those stay as `KI-ARCADIA-GOV-020` fixes them.
- No remote operation by an agent. Under the Techne Programme Hold, building, stopping and tearing down the host remain Kris's operations.
- No decision on whether the prototype continues after 2026-11-06; `KI-ARCADIA-GOV-021` owns that.
- No change to the Mac's chezmoi source from this repository; any shared model is agreed with that source's own roadmap.

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

### Open questions

- Does the setup step belong in the boot script, a separate script in this repository, or a shared chezmoi source?
- Should teardown refuse outright on unlanded work, or warn and require an explicit override?
- Is the Mac or the host the designated roadmap writing checkout, or does each repository name one?
- Is Tailscale key expiry left on for the host's device, and if so, what is its current expiry date?
- Does any of this justify work before the 2026-11-06 review, or should it wait for a renewal decision?

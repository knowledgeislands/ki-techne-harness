---
id: TECHNE-TOOLS-OPS-022
area: OPS
title: Agent host OS patching
kind: deliver
purpose: capability
project: agent-host
component: recipes
horizon: next
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-09T06:52:36Z
updated_at: 2026-10-09T16:04:33Z
---

# Agent Host OS Patching

## Goal

The `direct-host` recipe keeps any bound agent host's operating system patched, kernel and security updates included, through a path that the recipe defines and the binding owner controls, and it reports pending updates and a required reboot in status and at login.

## Context

On 2026-10-09 an attempt to apply Ubuntu updates on the current AWS agent host stopped before any change. The `techne` operator has no `sudo` by design (the [operator guide](../guides/operator/agent-host.md)), and the host's SSM agent was inactive that day. The host had 26 upgradable packages, including the kernel and `libc6`, and `/var/run/reboot-required` had been set since 2026-10-08. The only way to update the host today is a rebuild, which only the binding owner can run. Decision 23 in the Techne decisions log approved capturing this record.

Read-only readings on 2026-10-09, taken by the host-restart run in the Techne agent state before a planned stop/start through AWS, corrected part of that picture. Ubuntu's own unattended upgrades were already on and working: `20auto-upgrades` enables the daily list update and upgrade, the allowed origins are the release, `-security` and the ESM apps and infra security pockets, `unattended-upgrades.service` and both `apt-daily` timers are active, and `/var/log/apt/history.log` shows unattended installs on 8 and 9 October, the 7.0.0-1013 kernel among them. Automatic reboot was off by default, which is why `/var/run/reboot-required` (kernel, `linux-base`, `libc6`) had been set since 8 October 06:21 UTC. Thirty packages were upgradable, six from `noble-security`, including the 7.0.0-1014 kernel, which the next unattended run installs and which then needs another reboot. Livepatch was not installed and the machine was not attached to Ubuntu Pro. The unattended-upgrades log is root-only, so `techne` cannot read it. The repositories were all clean (`OUTCOME=clean`). That first restart attempt stopped because the binding owner's AWS session had expired; a second, after Kris logged in, restarted the host through the operator stop/start the same day (Decision 25), moving it to the 7.0.0-1013 kernel and clearing the reboot flag. Kris, approving restarts through the provider, asked on 2026-10-09 to progress this record "so we have capability going forwards" (Decision 24(d)), and answered its six decisions the same day, all as recommended (Decision 26(b)). He does not attach Ubuntu Pro to his binding and restarts by hand.

The recipe must stay general (Decisions 10 and 11): it must work for any binding owner and for any target, cloud or owned, Linux or macOS, with provider-specific parts in the provider layer. The AWS provider lives in `infra/aws/agent-host-stack.yaml`, whose boot script installs packages at build, and in `operations/aws/agent-host/`. The recipe lives in `recipes/direct-host/`.

Patching must keep the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) boundary. It must not need remote agent execution or any new remote-environment authority beyond the exempt host.

## Boundary

- In scope: the recipe's patching model, declared once as intent with a per-provider mechanism; optional binding fields for the reboot window and Livepatch; the AWS boot script's patching configuration; reporting pending updates, security updates, reboot-required and its age, and Livepatch state through `host/status.sh`, its JSON document and the login banner, on Ubuntu and macOS; the provider patching hooks an owned-host provider must supply, written as a contract; the operator guide's patching and restart section; and offline checks.
- Out of scope: patching or restarting the current host, which needs the binding owner's action; the owned-host provider itself (TECHNE-TOOLS-OPS-021), which implements the contract; the `tools-techne` binding schema and CLI for the new fields, handed off as a paired record; Ubuntu Pro attachment of any host, which the binding owner does; granting the operator user `sudo`; SSM, Patch Manager or any other remote management plane; rebuilding a host to apply this record; and any remote action.

## Plan

### Model

One model for every provider and OS, in three layers, none of which needs a rebuild or the operator's root:

1. **Security updates install unattended.** The host's own scheduler applies security updates daily as root, set up by the image or boot script. Non-security updates stay out of the unattended set; they arrive at the next build or through the owner's own action.
2. **Kernel fixes go live through Livepatch where available.** Where the binding opts in and the provider supports it (Ubuntu with Ubuntu Pro), critical kernel fixes apply without a restart. Livepatch narrows, but never removes, the need for a reboot.
3. **Reboots happen only when needed, at a window the binding chooses.** With no window in the binding, the default, the host never restarts itself: status and the login banner say a reboot is required and since when, and the binding owner restarts through the provider's stop and start, the normal restart route. A window is a daily local time, `HH:MM` in the host's time zone, such as `04:00`. With one, the host may restart itself at that time on any day only when a reboot is required and no user is logged in, so it never cuts a live session.

The operator user stays without `sudo`. Everything needing root is set by the image or the boot script; reporting reads only world-readable state.

### Provider contract

`recipe.toml` declares the intent once: unattended security updates, optional Livepatch, a reboot window that defaults to none, and the reporting fields. Each provider table declares its mechanism under `[providers.<provider>.patching]`, which `tooling/checks/recipe-manifest.py` requires for every supported provider:

- **AWS (Ubuntu):** the boot script writes `/etc/apt/apt.conf.d/20auto-upgrades` and a `52ki-agent-host-unattended-upgrades` file (security origins only; `Automatic-Reboot "false"` always, because unattended-upgrades' own reboot decision checks for logged-in users when its daily run ends, not when the reboot happens; see Alternatives considered). With a window, it also installs a `ki-agent-host-reboot` systemd timer that fires daily at the window's time (`OnCalendar=*-*-* 04:00:00`, host time zone) and whose service restarts the host only when `/var/run/reboot-required` exists and `who` lists no session at that moment. When the binding opts in to Livepatch, it attaches Ubuntu Pro from a SecureString in the stack's parameter prefix, read like the Tailscale key and never written to disk, and enables Livepatch. No SSM agent, Patch Manager or instance-role change.
- **Owned Linux (TECHNE-TOOLS-OPS-021):** the same contract through systemd: the distribution's unattended-update service and timers, enabled at enrolment by the binding owner as root, and, only when a window is set, the same daily reboot timer and guard.
- **macOS:** `softwareupdate`'s automatic security responses and system files set by the binding owner at enrolment; no automatic restart by default, because FileVault holds a restarted Mac at the unlock screen unless an authenticated restart (`fdesetup authrestart`) is used, which needs the owner's credentials. If a binding sets a window, it takes the same daily `HH:MM` form in the host's time zone and any restart in it stays subject to the FileVault caveat. Reporting uses `softwareupdate --list` from the local catalogue, without forcing a network scan at login.

### Reporting

`host/status.sh` gains an `updates` block in the JSON document and a text section: OS family, pending updates, pending security updates, `reboot_required` with the time it was first required (the mtime of `/var/run/reboot-required`) and the packages from `reboot-required.pkgs`, and Livepatch state where present (`unsupported`, `disabled`, or the patch state). On Ubuntu, counts come from `/usr/lib/update-notifier/apt-check`, which `techne` can run; on macOS from `softwareupdate --list`. A failed reading is reported as unknown for that field and never changes the work-safety outcome: updates do not put work at risk (ODR-KI-ARCADIA-001), so `outcome` and the exit status are unchanged. The block is additive, so the schema stays `techne/host-workspace/v1` with an optional member.

The text report writes the counts into the cache the banner reads. The banner also checks `/var/run/reboot-required` directly, a local file read with no network or credential call, so a reboot need shows at the next login without waiting for a status run. It prints one line when a reboot is required (with its age and the restart route), and one when security updates are pending past a day.

### Restart route

The guide names the provider's stop and start as the normal restart: run status first, then stop and start the host through the provider (on AWS, `stop.sh` then `techne host start`, under the binding owner's live session), reconnect over Tailscale and run status again. EBS persists the workspace, so a restart loses only running sessions, which status before the stop reveals.

### The current host

It needs no rebuild to benefit. The reporting reaches it at the binding owner's next `setup`, which runs as `techne`. Its unattended security updates are already on. The boot-script settings (window, Livepatch) arrive with the next build that happens anyway, currently TECHNE-TOOLS-OPS-017's. Until then a required reboot is reported and the owner restarts through the provider.

## Current state

The AWS boot script in `infra/aws/agent-host-stack.yaml` installs packages but sets no patching policy, so the host runs Ubuntu's image defaults: unattended security upgrades on, automatic reboot off, no Livepatch. The boot script runs only at first boot, so a change to it reaches a host only at its next build. `host/status.sh` reports repositories, expiries and tool drift, and writes the expiry cache; the banner in `converge.sh` reads only that cache and the clock. Neither reports updates or reboot-required. `recipe.toml` declares no patching intent and no reboot window, and the operator guide says nothing about patching or restarting. The operator has no `sudo` and the host's SSM agent is disabled by design, so no remote patch path exists, and none is wanted. The current host was restarted through the provider on 2026-10-09 (Decision 25) and runs the 7.0.0-1013 kernel. The next unattended run, about 06:50 UTC on 2026-10-10, should install the 1014 kernel and set the reboot flag again; Kris accepts the one provider stop/start that needs (Decision 26(c)).

## Steps

- [ ] Declare the patching intent in `recipes/direct-host/recipe.toml`, the optional `reboot_window` and `livepatch` parameters (no default; absent means no automatic reboot and no Livepatch), and `[providers.aws.patching]`; teach `tooling/checks/recipe-manifest.py` to require a patching table for each provider and to validate the window's form (a 24-hour `HH:MM`, with no weekday).
- [ ] Add the AWS patching configuration and the conditional daily reboot timer to the boot script in `infra/aws/agent-host-stack.yaml`, with `RebootWindow` and `Livepatch` stack parameters passed by `provision.sh`, and the Ubuntu Pro token read from the parameter prefix only when Livepatch is on; extend `tooling/checks/agent-host-stack.rb` for both.
- [ ] Add the `updates` block and text section to `operations/aws/agent-host/host/status.sh`, for Ubuntu and macOS, and write the counts to the banner cache; keep the outcome and exit status unchanged.
- [ ] Extend the banner in `operations/aws/agent-host/host/converge.sh` with the reboot-required and pending-security lines.
- [ ] Add offline fixtures and stubs to `tooling/checks/agent-host-workspace.sh` (and siblings) for: no updates, pending security updates, reboot required with age and packages, Livepatch absent and active, `apt-check` failing, and a macOS `softwareupdate` listing.
- [ ] Write the provider patching contract into the recipe documentation and the operator guide, with the restart route, the FileVault caveat, Ubuntu Pro attachment as the binding owner's step, and the current-host note.
- [x] Hand off a paired `tools-techne` record for the `reboot_window` and `livepatch` binding fields and the `updates` status member, and record its identifier here: [TECHNE-TOOL-CLI-008](https://github.com/knowledgeislands/tools-techne/blob/main/docs/roadmap/TECHNE-TOOL-CLI-008-host-patching-fields.md), captured in triage on 2026-10-09.
- [ ] Live verification, only under a separate grant from the binding owner for the exempt host: setup, then status showing the `updates` block, and a new login showing the banner line while a reboot is required.

## Files touched

- `recipes/direct-host/recipe.toml`
- `infra/aws/agent-host-stack.yaml`
- `operations/aws/agent-host/provision.sh`
- `operations/aws/agent-host/host/status.sh`
- `operations/aws/agent-host/host/converge.sh`
- `tooling/checks/recipe-manifest.py`, `tooling/checks/agent-host-stack.rb`, `tooling/checks/agent-host-workspace.sh` and `tooling/checks/fixtures/`
- `docs/guides/operator/agent-host.md`

## Verify

- `bun run test` passes, including the recipe-manifest, stack and workspace checks.
- The stack check asserts that the boot script writes security-only origins and `Automatic-Reboot "false"`, installs the reboot timer only when a window is set and with a daily `OnCalendar=*-*-* HH:MM:00` built from the window, rejects a window carrying a weekday, guards the reboot on `reboot-required` and an empty `who`, and reads the Pro token only when Livepatch is on, never writing it to disk.
- The workspace check asserts each fixture's `updates` block and banner line, and that every fixture's `outcome` and exit status match the same fixture without updates.
- `ki repo audit` passes.
- Live: only under the separate grant above.

## Dependencies / blocks

No prerequisite. TECHNE-TOOLS-OPS-017 changes the same boot script and is the next planned rebuild, so whichever lands second rebases; this record's boot-script settings reach the current host at that rebuild. TECHNE-TOOLS-OPS-015 and TECHNE-TOOLS-OPS-019 touch `recipe.toml`, `setup.sh` and the recipe-manifest check; ordinary rebase, no ordering. TECHNE-TOOLS-OPS-021 implements this record's owned-host contract. The `tools-techne` binding fields and status member are the paired, non-blocking [TECHNE-TOOL-CLI-008](https://github.com/knowledgeislands/tools-techne/blob/main/docs/roadmap/TECHNE-TOOL-CLI-008-host-patching-fields.md); without it the fields reach the scripts only through their environment variables.

## Documentation impact

### Decision Records

None needed here: the patching model applies ODR-KI-ARCADIA-001 and ADR-KI-ARCADIA-003 without changing them, and the record holds the rationale. If Kris wants the no-unplanned-restart rule to bind every provider, Arcadia may record it in ODR-KI-ARCADIA-001, by handoff.

### Specifications

The `techne/host-workspace/v1` status document gains an optional `updates` member; the recipe gains a patching table. Both are documented in `recipe.toml` and the operator guide, which are this repository's contract for them.

### Guides

The operator guide gains a patching and restart section: what runs unattended, the reboot window, Livepatch and Ubuntu Pro attachment, reading the `updates` block and banner, the stop/start restart route, and the macOS FileVault caveat.

### Roadmap

The paired `tools-techne` record [TECHNE-TOOL-CLI-008](https://github.com/knowledgeislands/tools-techne/blob/main/docs/roadmap/TECHNE-TOOL-CLI-008-host-patching-fields.md) for the binding fields and status member. TECHNE-TOOLS-OPS-021 inherits the owned-host patching contract; its record should cite this one when it is planned.

## Discussion

### Decisions for the binding owner

Kris answered all six on 2026-10-09, each as recommended (Decision 26(b)), and amended the sixth the same day (Decision 27). The plan above follows them.

1. **Automatic reboot default.** Resolved: none. A binding may set a window, and the host restarts in it only when a reboot is required and nobody is logged in.
2. **Livepatch.** Resolved: an opt-in binding field, off by default. Kris does not attach Ubuntu Pro to his binding; he restarts by hand when a reboot is required.
3. **Unattended scope.** Resolved: security updates only, as today; non-security updates arrive at the next build.
4. **Outcome.** Resolved: pending updates and reboot-required never change the status outcome or exit status; they show as report lines and a banner line.
5. **Current host.** Resolved: no rebuild for this record. Reporting arrives at the next `setup`, the boot-script settings at TECHNE-TOOLS-OPS-017's rebuild, and Kris restarts through the provider when a kernel asks for it, starting with the 1014 kernel due on 2026-10-10 (Decision 26(c)).
6. **Reboot window form.** Resolved, as amended by Decision 27: a daily local time in the binding, `HH:MM` in the host's time zone; Kris's binding uses `04:00`. Decision 27 preferred the native unattended-upgrades reboot over a custom timer if it reboots only when required and with nobody logged in. It does not hold for the logged-in check (see Alternatives considered), so the AWS provider keeps the `ki-agent-host-reboot` timer, now daily.

The record stays `draft` until Kris approves this plan as Ready.

### Alternatives considered

- **SSM Patch Manager.** Rejected: it needs the SSM agent the boot script disables and a management-plane authority outside the hold boundary, and it is AWS-only.
- **A narrow `sudo` rule for a `techne host patch` command.** Rejected: the operator gains root reach, and unattended updates already cover the routine path.
- **Rebuild to patch.** Rejected by the owner: rebuilds are for changing the host, not for keeping it current.
- **Native unattended-upgrades reboot** (`Automatic-Reboot "true"` only with a window, `Automatic-Reboot-Time` set to it, `Automatic-Reboot-WithUsers "false"`). Preferred by Decision 27, but rejected because it does not meet the rule. It does reboot only when `/var/run/reboot-required` exists. But the upstream documentation describes `Automatic-Reboot-Time` as rebooting at that time instead of immediately, which the tool does by scheduling `shutdown -r` when its run ends, and `Automatic-Reboot-WithUsers` is evaluated then too. `apt-daily-upgrade.timer` runs around 06:00 to 07:00, so with a `04:00` window the logged-in check happens about 21 hours before the reboot, and a session started in between is cut. Moving `apt-daily-upgrade.timer` to the window with an immediate reboot would narrow that gap to the run's length, but it also moves the upgrade schedule and relies on unattended-upgrades evaluating the reboot on a run with nothing to install, which this record does not establish. The custom timer checks `reboot-required` and `who` at the moment it restarts.

### Related records

None of these is a prerequisite, so the dependency fields stay empty; the paired TECHNE-TOOL-CLI-008 is non-blocking either way. TECHNE-TOOLS-OPS-017 changes the same AWS boot script and is the next planned rebuild. TECHNE-TOOLS-OPS-018 moves tool installation to Rig; OS patching stays outside Rig. TECHNE-TOOLS-OPS-021 adds the owned-host provider, which supplies this record's owned-host hooks.

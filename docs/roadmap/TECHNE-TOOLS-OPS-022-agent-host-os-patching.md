---
id: TECHNE-TOOLS-OPS-022
area: OPS
title: Agent host OS patching
purpose: capability
project: agent-host
component: recipes
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-09T06:52:36Z
updated_at: 2026-10-09T06:52:36Z
---

# Agent Host OS Patching

## Goal

The `direct-host` recipe keeps any bound agent host's operating system patched, kernel and security updates included, through a path that the recipe defines and the binding owner controls, and it reports pending updates and a required reboot in status and at login.

## Context

On 2026-10-09 an attempt to apply Ubuntu updates on the current AWS agent host stopped before any change. The `techne` operator has no `sudo` by design (the [operator guide](../guides/operator/agent-host.md)), and the host's SSM agent was inactive that day. The host had 26 upgradable packages, including the kernel and `libc6`, and `/var/run/reboot-required` had been set since 2026-10-08. The only way to update the host today is a rebuild, which only the binding owner can run. Decision 23 in the Techne decisions log approved capturing this record.

The recipe must stay general (Decisions 10 and 11): it must work for any binding owner and for any target, cloud or owned, Linux or macOS, with provider-specific parts in the provider layer. The AWS provider lives in `infra/aws/agent-host-stack.yaml`, whose boot script installs packages at build, and in `operations/aws/agent-host/`. The recipe lives in `recipes/direct-host/`.

Patching must keep the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) boundary. It must not need remote agent execution or any new remote-environment authority beyond the exempt host.

## Boundary

- In scope: the recipe's patching model and the provider contract it needs; reporting pending updates and a required reboot through `host/status.sh` and the login banner; the AWS provider's patching path; and the hooks an owned-host provider must supply.
- Out of scope: patching the current host, which needs the binding owner's action; the owned-host provider itself (TECHNE-TOOLS-OPS-021); granting the operator user `sudo`, unless the design concludes that a narrow rule is the right model and the owner approves it; and any remote action.

## Discussion

### Open questions

- **Model:** unattended security updates with a scheduled, announced reboot window, or an owner-run patch operation such as `techne host patch`, or both: unattended for security fixes and owner-run for the kernel and reboot.
- **Reboot and durability:** how a reboot respects the durability guarantees in [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md). For example: run status first, refuse or defer while work is at risk, and announce the window to running sessions. On macOS hosts, FileVault may hold the machine at the unlock screen after a reboot unless authenticated restart is used.
- **Reporting:** how `status.sh` and the login banner show the pending update count, security updates, reboot-required and how long it has been required, and whether a stale reboot-required should make the outcome non-clean.
- **Provider split:** on AWS, unattended updates set up by the boot script, or an SSM-capable instance role with Patch Manager, which also needs the SSM agent active. On owned hosts, a `launchd` or `systemd` timer. On macOS, `softwareupdate`. The recipe should declare the intent, and each provider should supply the mechanism.
- **Privilege:** which identity applies updates when `techne` has no `sudo`. Options include a root-owned timer installed at build, a narrow `NOPASSWD` rule for one patch command, or the provider's management plane.
- **Current host:** whether it waits for the planned rebuild (TECHNE-TOOLS-OPS-017) to pick up the pending updates, or the binding owner rebuilds sooner. This is the owner's call and is tracked in the Arcadia `agent-host` checkpoint, not here.

### Related records

None of these is a prerequisite, so the dependency fields stay empty. TECHNE-TOOLS-OPS-017 changes the same AWS boot script and is the next planned rebuild, which would pick up today's pending updates. TECHNE-TOOLS-OPS-018 moves tool installation to Rig; OS patching stays outside Rig. TECHNE-TOOLS-OPS-021 adds the owned-host provider, which will need to supply this record's provider hooks. Planning settles the order.

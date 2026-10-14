---
id: KI-TECHNE-OPS-027
area: OPS
title: Agent-host Tailscale key minting
purpose: capability
project: agent-host
component: operations
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-14T06:31:40Z
updated_at: 2026-10-14T06:31:40Z
---

# Agent-Host Tailscale Key Minting

## Goal

A rebuild of the agent host no longer needs Kris to generate a Tailscale auth key by hand. `provision.sh` mints the single-use key itself from a Tailscale OAuth client that Kris creates once, stores it in Parameter Store for the boot script, and the hand route stays as a fallback.

## Context

Today the operator guide's [Before the build](../guides/operator/agent-host.md#before-the-build) asks Kris to generate a key in the Tailscale admin console: not reusable, not ephemeral, pre-approved, tagged `tag:ki-techne-agent-host` only, with a one-day expiry. Kris copies it to the clipboard, pipes it into the `/ki/techne/agent-host/tailscale-auth-key` SecureString parameter and clears the clipboard. After enrolment the guide's [Verify over Tailscale](../guides/operator/agent-host.md#verify-over-tailscale) step deletes the spent parameter. [Rebuild and withdraw](../guides/operator/agent-host.md#rebuild-and-withdraw) repeats the hand step on every rebuild, and `operations/aws/agent-host/destroy.sh rebuild` prints it as step 2 of the rebuild sequence. `operations/aws/agent-host/provision.sh` refuses to run when the parameter is missing (`require_secret tailscale-auth-key`).

Kris approved capturing this on 2026-10-14 (Techne Decision 50).

The proposal:

1. Kris creates a Tailscale OAuth client once, scoped to `auth_keys` writes and to `tag:ki-techne-agent-host` only, and keeps its client secret in 1Password.
2. At build time `provision.sh` reads the secret on the workstation, exchanges it for a short-lived access token and mints one auth key with the same properties as the hand route: single-use, non-ephemeral, pre-approved, that tag only, shortest workable expiry.
3. The key goes straight into the Parameter Store parameter. It is never echoed, passed as a command argument or written to disk anywhere else, and the existing delete-after-enrolment step still applies.
4. When no OAuth client is configured, or Kris prefers it, the present hand route works unchanged.

## Boundary

- In: minting in `provision.sh` behind an explicit opt-in, with the hand route as fallback; the matching change to the rebuild sequence `destroy.sh rebuild` prints; the operator guide's one-time OAuth client setup and its revocation in the kill switch and withdraw steps; offline tests of the minting path against a stubbed API.
- Security boundary: the OAuth client secret stays in 1Password and is read only on the workstation at build time. Nothing about the OAuth client reaches the host, the instance role, Parameter Store, Git, a command argument or retained evidence. The client can only create auth keys for `tag:ki-techne-agent-host`; it cannot manage devices, the policy file or other tags.
- Out: creating the OAuth client, any build, rebuild or AWS change, and any change to the tailnet policy. These wait for the [Techne Programme Hold](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) to allow remote-environment management. Device removal on rebuild stays a hand step.

## Dependencies / blocks

Not blocking anything, and nothing blocks capture. Implementation is local work; using it against the live tailnet and AWS account waits for the Programme Hold.

## Discussion

Open questions for adoption and planning:

- **Where the secret is read from.** `op read` with a 1Password reference at build time, an environment variable Kris populates with `op run`, or a reference named in the host binding. Each keeps the secret off disk; they differ in how `provision.sh` discovers it and whether it depends on the 1Password CLI being signed in.
- **How `destroy.sh rebuild` prints the new sequence.** It could print the minting route when the OAuth client is configured and the hand route otherwise, or always print both with the minting route first.
- **Whether `tools-techne` needs a field.** The `[status]` table or the host binding may need to record that the host uses minted keys, or the 1Password reference, so `techne host setup` and `techne doctor` can say which route applies. That is a `tools-techne` decision; this repository would hand over the need.
- **Expiry.** The shortest expiry the API accepts that still covers a slow build, against the guide's present one day.

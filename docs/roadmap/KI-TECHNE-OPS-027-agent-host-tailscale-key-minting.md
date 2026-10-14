---
id: KI-TECHNE-OPS-027
area: OPS
title: Agent-host Tailscale key minting
kind: deliver
purpose: capability
project: agent-host
component: operations
horizon: now
status: awaiting-review
blocks: []
blocked_by: []
baseline_ref: c77c7d90c48b07978a39ed0a444baf2fa6117a17
created_at: 2026-10-14T06:31:40Z
updated_at: 2026-10-14T09:10:00Z
---

# Agent-Host Tailscale Key Minting

## Goal

A rebuild of the agent host no longer needs Kris to generate a Tailscale auth key by hand. `provision.sh` mints the single-use key itself from a Tailscale OAuth client that Kris creates once, stores it in Parameter Store for the boot script, and the hand route stays as a fallback.

## Context

Today the operator guide's [Before the build](../guides/operator/agent-host.md#before-the-build) asks Kris to generate a key in the Tailscale admin console: not reusable, not ephemeral, pre-approved, tagged `tag:ki-techne-agent-host` only, with a one-day expiry. Kris copies it to the clipboard, pipes it into the `/ki/techne/agent-host/tailscale-auth-key` SecureString parameter and clears the clipboard. After enrolment the guide's [Verify over Tailscale](../guides/operator/agent-host.md#verify-over-tailscale) step deletes the spent parameter. [Rebuild and withdraw](../guides/operator/agent-host.md#rebuild-and-withdraw) repeats the hand step on every rebuild, and `operations/aws/agent-host/destroy.sh rebuild` prints it as step 2 of the rebuild sequence. `operations/aws/agent-host/provision.sh` refuses to run when the parameter is missing (`require_secret tailscale-auth-key`).

Kris approved capturing this on 2026-10-14 in the Techne run ("TS-OAUTH - capture as work") and adopted it at horizon `now` the same day ("TS-OAUTH-ADOPT - now"): local implementation may proceed, while creating the OAuth client and any live rebuild stay with Kris.

The proposal:

1. Kris creates a Tailscale OAuth client once, scoped to `auth_keys` writes and to `tag:ki-techne-agent-host` only, and keeps its client secret in 1Password.
2. At build time `provision.sh` reads the secret on the workstation, exchanges it for a short-lived access token and mints one auth key with the same properties as the hand route: single-use, non-ephemeral, pre-approved, that tag only, shortest workable expiry.
3. The key goes straight into the Parameter Store parameter. It is never echoed, passed as a command argument or written to disk anywhere else, and the existing delete-after-enrolment step still applies.
4. When no OAuth client is configured, or Kris prefers it, the present hand route works unchanged.

## Boundary

- In: minting in `provision.sh` behind an explicit opt-in, with the hand route as fallback; the matching change to the rebuild sequence `destroy.sh rebuild` prints; the operator guide's one-time OAuth client setup and its revocation in the kill switch and withdraw steps; offline tests of the minting path against a stubbed API.
- Security boundary: the OAuth client secret stays in 1Password and is read only on the workstation at build time. Nothing about the OAuth client reaches the host, the instance role, Parameter Store, Git, a command argument or retained evidence. The client can only create auth keys for `tag:ki-techne-agent-host`; it cannot manage devices, the policy file or other tags.
- Out: creating the OAuth client, any build, rebuild or AWS change, and any change to the tailnet policy. These wait for the [Techne Programme Hold](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) to allow remote-environment management. Device removal on rebuild stays a hand step. A `techne` binding field for the 1Password reference is `tools-techne`'s change, handed over rather than made here.

## Current state

At the baseline `provision.sh` only checks that the `tailscale-auth-key` SecureString exists, `destroy.sh rebuild` always prints the hand route, and the guide documents the hand route alone. No script talks to the Tailscale API.

## Steps

- [x] Add `operations/aws/agent-host/mint-tailscale-key.sh`: read the client from a 1Password item reference with `op read`, or from environment variables under `op run`; exchange it for an access token and mint one single-use, non-ephemeral, pre-approved key for the binding's tag with a one-hour expiry; pipe it to `aws ssm put-parameter --value file:///dev/stdin` without `--overwrite`; `--check` exchanges the token only.
- [x] Make `provision.sh` mint only when the key parameter is absent and a client is configured, after template validation and just before the deploy, and name both routes when neither applies.
- [x] Make `destroy.sh rebuild` print the minting route when a client is configured and the hand route, with the minting alternative, otherwise; add the OAuth client to the withdraw footprint.
- [x] Extend the offline AWS-script checks with stubbed `op`, `curl` and `aws`: both secret sources, key properties, ordering, stored-key reuse, refusal paths, the second binding, and random per-run credentials swept from every logged argument, the output and every file under the check's home and temporary directory.
- [x] Document the one-time OAuth client setup, its 1Password item, use, `--check`, retry, the kill switch and withdrawal in the operator guide.

## Files touched

- `operations/aws/agent-host/mint-tailscale-key.sh` (new)
- `operations/aws/agent-host/provision.sh`
- `operations/aws/agent-host/destroy.sh`
- `tooling/checks/agent-host-aws-scripts.sh`
- `docs/guides/operator/agent-host.md`

## Verify

`bun run test` passes, including `tooling/checks/agent-host-aws-scripts.sh` and `shellcheck` over every agent-host script. The live check, which only Kris may run, is listed under the Review packet.

## Dependencies / blocks

Not blocking anything, and nothing blocks the local work. The live check needs Kris to create the OAuth client and either run `mint-tailscale-key.sh --check` or one rebuild; a rebuild falls under the [Techne Programme Hold](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) exemption for this host.

Handoff to `tools-techne`, not blocking: its binding schema has a fixed list of provider-neutral fields, so a binding cannot yet carry the 1Password item reference. An optional neutral field, such as `tailscale_oauth_item`, passed to `provision` and `destroy` as `AGENT_HOST_TAILSCALE_OAUTH_ITEM`, would let `techne` runs mint without an exported variable. Once `tools-techne` accepts such a field, this repository adds the matching optional parameter to `recipes/agent-host/recipe.toml`. Until then the operator exports the variable by hand.

## Documentation impact

### Decision Records

None needed: the route is an operational convenience within the existing exemption and the record's security boundary, not a new architectural decision.

### Specifications

None: the recipe manifest and the status contract are unchanged.

### Guides

The operator guide gains [Key minting](../guides/operator/agent-host.md#key-minting) with the one-time OAuth client setup and the 1Password item, and its build, kill-switch, rebuild and withdraw steps name the minting route and the client.

### Roadmap

No new record. The `tools-techne` binding field is a handoff for that repository to schedule, and the recipe parameter follows it.

## Review

### Delivered

The approved boundary: minting behind the `AGENT_HOST_TAILSCALE_OAUTH_ITEM` opt-in (or the `op run` variables), the hand route unchanged as fallback, the rebuild sequence, the guide and offline tests. Excluded as agreed: the OAuth client itself, any Tailscale or AWS call with real credentials, any rebuild, and any `tools-techne` change. Baseline `c77c7d90c48b07978a39ed0a444baf2fa6117a17`; the implementing commit follows it on `main`.

### Change Summary

- `operations/aws/agent-host/mint-tailscale-key.sh`: new minting script. curl takes each request as configuration on standard input, so the secret and token never reach an argument; every value is format-checked before it enters a configuration line, and no error names a value. No here-string or here-document is used, because Bash 3.2 backs both with temporary files.
- `operations/aws/agent-host/provision.sh`: `has_secret` split from `require_secret`; minting runs after `validate-template` and before `deploy`, so a template error never leaves a fresh key behind.
- `operations/aws/agent-host/destroy.sh`: route-aware rebuild step 2 and the OAuth client in the withdraw footprint.
- `tooling/checks/agent-host-aws-scripts.sh`: the minting checks.
- `docs/guides/operator/agent-host.md`: the Key minting section and its cross-references.

Decisions: expiry one hour rather than the hand route's one day; the item reference rather than a binding field, pending `tools-techne`; a stored key always wins, so minting never overwrites.

### Verification

- `bun run test`: passed, including `agent-host AWS script checks passed` and `offline checks passed`.
- `shellcheck tooling/checks/*.sh operations/aws/agent-host/*.sh`: clean.
- The secrecy sweep was proved to bite: temporarily echoing the key, and separately passing the token as a curl argument, each made the check fail; both probes were reverted.
- `bunx rumdl check` on the guide: no issues.

### Outstanding concerns

- Live check, Kris only: create the OAuth client and its 1Password item as [One-time setup](../guides/operator/agent-host.md#one-time-setup) describes, then run `mint-tailscale-key.sh --check`, or one rebuild. The Tailscale console labels, the `auth_keys` scope name and the token response's `scope` field follow Tailscale's documentation as understood when written and were not seen against a live tailnet.
- The `tools-techne` binding field above is a handoff, not yet filed there.

### Post-change review

The goal is met locally: a rebuild with the variable set needs no hand-generated key, and without it nothing changes. Regression risk is low: the existing provision, stop and destroy checks pass unchanged, and the default path makes the same AWS calls as before. Acceptance waits on the live check.

### Mini recap

Minting is implemented, tested offline with a leak sweep and documented, with the hand route intact. Remaining: Kris's one-time client setup and live check, and the `tools-techne` binding-field handoff. Learning route: the stdin-configuration pattern for curl could serve other credential-bearing scripts here, if any appear.

## Discussion

### Where the secret is read from

Resolved: a 1Password item reference in `AGENT_HOST_TAILSCALE_OAUTH_ITEM`, read with `op read` (fields `username` and `credential` of an API Credential item), with `AGENT_HOST_TAILSCALE_OAUTH_CLIENT_ID` and `AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET` as the alternative for `op run`. The reference is the binding owner's, so it has no recipe default; a binding field would be the natural home once `tools-techne` carries it.

### How `destroy.sh rebuild` prints the new sequence

Resolved: it prints the minting route when a client is configured in its environment and the hand route, with the minting alternative, otherwise. Either way the spent key parameter must be gone before `provision.sh` mints, which the post-build verification step already ensures.

### Whether `tools-techne` needs a field

Resolved: yes, for `techne`-driven runs; `[status]` needs nothing. The need is handed over as an optional neutral binding field, non-blocking, and the scripts work by hand meanwhile.

### Expiry

Resolved: one hour. The boot script reads the key minutes after the deploy, and minting happens just before the deploy; a failed build is retried after deleting the parameter, so a fresh key is minted rather than an expired one reused.

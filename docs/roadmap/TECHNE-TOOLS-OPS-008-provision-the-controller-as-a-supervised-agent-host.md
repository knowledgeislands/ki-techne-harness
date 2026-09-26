---
id: TECHNE-TOOLS-OPS-008
area: OPS
title: Provision supervised agent host
theme: operations
horizon: triage
status: draft
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-09-26T15:55:00Z
updated_at: 2026-09-26T15:55:00Z
---

# Provision Supervised Agent Host

## Goal

Decide whether the deployed controller host should also serve as the persistent human-supervised remote agent host, and if so, name the exact additive changes required, their cost, their exposure, and their rollback — so that the supervised operating mode has a real target rather than a hoped-for one.

## Context

Inspection of the deployed controller established that the access path for supervised work already exists and needs no inbound exposure. The host is reachable through the session-manager service over its existing outbound HTTPS allowance; the instance security group has no ingress rules at all, and none are required. A dropped connection was shown to leave the far-side shell alive, and the service's resume operation returns a working stream to that same session. A terminal multiplexer is already installed. Those are the properties the supervised mode depends on, and they are present.

What is absent is the agent host itself. The instance has no running SSH service and an empty authorised-keys file, so editor-based remote development cannot attach today. There is no Node or Bun runtime, no agent command-line runtime, no session-manager tool, and no repository checkout. The node is a two-processor, four-gigabyte instance with roughly twelve gigabytes of free disk against a canonical archipelago checkout of about nine gigabytes, so a checkout fits but leaves only a few gigabytes of headroom before runtimes and images.

This item exists because the earlier conclusion that the substrate structurally could not serve the supervised mode was too strong. The access path is proven. The gap is a provisioning gap, and it is smaller than expected but not free.

## Boundary

This item does not provision anything. It does not enable the SSH service, install an authorised key, install a runtime, resize the instance, enlarge the volume, or open a port. Each of those is a change requiring explicit approval from the exposure authority, and the purpose of this record is to put the decision and its cost in one place first.

## Discussion

### Two candidate access shapes

The first shape keeps the session-manager service as the only access path and adds an agent runtime plus a repository checkout on the host. It needs no ingress, no key material, and no network change of any kind; the access grant is an identity permission that can be scoped and revoked centrally. Editor-based remote development would need the SSH service enabled and reached through the session-manager service as a transport, which still adds no ingress rule but does add a key to manage.

The second shape adds a mesh-network node to the host. The existing outbound HTTPS allowance is sufficient for a relayed connection, so this also needs no ingress rule. Its cost is that the exposure decision moves from a security-group rule to a network access-control list, and no such list is recorded in any repository today. An untagged node inherits a permissive default, so this is a larger change than it appears and must not be made casually.

### Capacity is the binding constraint

The measured headroom is a few gigabytes after a full checkout. Two processors and four gigabytes is thin for an interactive agent session alongside the control-plane workload the host already carries, and a single node means the controller and the agent host share a blast radius: if the node is lost, both are lost. Either the capacity is accepted explicitly, or a separate host is named.

### Standing cost

Measured spend for the account over an eight-day window attributable to this host was about nine dollars for compute, with under a dollar each for the network address and the volume, which is roughly the list rate for the instance size running continuously. That is an existing charge, not a new one, but it is the cost of a host that has been essentially idle, and it is the number against which a wake-on-demand alternative should be judged.

### Least privilege over time

Any grant made for a proof should be named with its revocation at the moment it is made: which identity permission, which key, which network tag, and who removes it when the proof ends. A permission granted for one proof otherwise stays granted.

### Open questions

- Is the supervised agent host this node, or a separate host with more capacity?
- If it is this node, is the shared blast radius with the controller acceptable?
- Does editor-based remote development justify enabling the SSH service, given that the session-manager path already gives a persistent shell?
- Which mesh-network access-control list governs the second shape, and in which repository is it recorded?
- What is the revocation step for every grant this provisioning would create?

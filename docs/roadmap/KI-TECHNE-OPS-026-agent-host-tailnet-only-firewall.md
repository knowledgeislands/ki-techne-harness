---
id: KI-TECHNE-OPS-026
area: OPS
title: Agent-host tailnet-only listener firewall
purpose: capability
project: agent-host
component: recipes
status: triage
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-13T23:55:10Z
updated_at: 2026-10-13T23:55:10Z
---

# Agent-Host Tailnet-Only Listener Firewall

## Goal

The `agent-host` recipe declares Rig's tailnet-only firewall for the listeners its agents start, so a development server, preview or tool port on the host is reachable only from loopback and the tailnet. The AWS stack keeps opening no public inbound port. Kris's Macs and the agent host then share one firewall model.

## Context

Handed over by `tools-rig` under the Rig Initiative on 2026-10-14, from mac-studio-bootstrap Decision 51. Rig's [KI-TOOL-RIG-CORE-051](https://github.com/knowledgeislands/tools-rig/blob/main/docs/roadmap/KI-TOOL-RIG-CORE-051-linux-tailnet-only-firewall.md) adds a built-in `linux-nftables` provider for the `[firewall.ID]` declaration that [KI-TOOL-RIG-CORE-047](https://github.com/knowledgeislands/tools-rig/blob/main/docs/roadmap/KI-TOOL-RIG-CORE-047-tailnet-only-listener-firewall.md) delivered for macOS. It owns one nftables table and one systemd unit, drops only the declared ports from outside loopback and Tailscale's ranges, never filters port 22, and changes the host only under an attended `rig apply --sudo`. It is at Awaiting review, delivered against fixtures only; no Rig release contains it yet.

A declaration in `recipes/agent-host/rig.toml` would look like this, with the ports the recipe's agents actually use:

```toml
[firewall.dev-server-tailnet]
name = "Agent dev servers on the tailnet only"
purpose = "Keep agent-started listeners off the VPC and the internet"
rationale = "Development servers bind every address by default"
provider = "linux-nftables"
locator = "info.knowledgeislands.techne.firewall.dev-server"
platforms = ["linux"]
ports = ["tcp:3000"]
allow = ["tailnet"]
profiles = ["agent-host"]
```

What this repository shows today, read from the files only, with no AWS call:

- `infra/aws/agent-host-stack.yaml`: the security group has no ingress rules. Egress is TCP 443 and 80 and UDP 3478 and 41641 to anywhere. The instance sets `AssociatePublicIpAddress: true` on a subnet routed through an internet gateway, so it has a public IPv4 address, but nothing is open inbound. No public inbound rule was found.
- The user data disables `ssh.socket`, `ssh.service` and the SSM agent; access is Tailscale SSH only. The VPC is `10.90.0.0/24` with no IPv6, so it does not overlap Tailscale's `100.64.0.0/10`.
- The user data's `apt-get install` line does not include `nftables`, which the provider needs.
- `recipes/agent-host/rig.toml` pins Rig 0.4.0, which predates the provider.
- `infra/aws/target-stack.yaml` allows TCP 6443 only from the controller's security group, not from the internet. `infra/aws/controller-stack.yaml` has no ingress rules.

## Boundary

- In: a `linux-nftables` firewall declaration in the recipe's Rig profile for its agents' listener ports; adding `nftables` to the host's package install; moving the Rig pin to a release that contains the provider; an offline check that the stack keeps no public ingress rule; the operator guide's rollback (`sudo systemctl disable --now LOCATOR.service` and `sudo nft delete table inet rig_NAME`).
- Out: any `rig apply`, host rebuild or AWS change. Applying the firewall to the running host waits for the Techne Programme Hold to allow remote-environment management. Rig's provider itself, its review and release belong to `tools-rig`.

## Dependencies / blocks

Not blocking anything. It depends on a Rig release containing KI-TOOL-RIG-CORE-051, after that record is reviewed and accepted, and on the Techne Programme Hold for any change to the running host. KI-TECHNE-OPS-025 may move the profile to `roles/` first; the declaration then belongs wherever the role profile lives.

## Discussion

Origin: `tools-rig`, Rig Initiative, mac-studio-bootstrap Decision 51. Capture only; adoption, port choice, priority and plan belong to this repository.

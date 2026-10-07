# Build and operate the agent host

This runbook is for Kris, as the operator who builds, connects to, stops and tears down the prototype agent host that `KI-ARCADIA-GOV-020` authorises. The host is a separate EC2 instance, `ki-techne-agent-host`, in account `655383751458`, region `eu-west-1`. It sits beside the retained controller `ki-techne-ops-007-primary` and shares nothing with it: its own stack, network, security group, instance role and instance profile.

Run nothing here until the gate in `KI-ARCADIA-GOV-020` has cleared and the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) names this prototype. Agents prepare and review this path; only Kris runs it.

## What the host is

- **Operator OS user:** `kris`. It is a non-root user without `sudo`. Use `kris@ki-techne-agent-host` in the chezmoi SSH `Host` entry and in Zed's `ssh_connections` entry.
- **Tailnet name:** `ki-techne-agent-host`, advertising `tag:ki-techne-agent-host`.
- **Access:** Tailscale SSH only. The security group has no inbound rule; the boot script disables the OpenSSH listener and the session-manager agent, and the instance role has no session-manager permission.
- **Image:** Ubuntu from the controller's pinned image, with Git, `tmux`, `jq`, Node.js from the latest `24.x` release (checksum-verified), the AWS CLI and Tailscale. Claude Code is installed for `kris` by the native installer in `~/.local/bin`.
- **Size:** `t3.medium` with a 40 GB encrypted `gp3` volume by default. At list prices this is roughly 33 USD a month while running, plus about 3.50 USD for the volume and 3.65 USD for the public IPv4 address, which exists only for outbound traffic.
- **Secrets:** the instance role may read only Parameter Store names under `/ki/techne/agent-host/`, decrypting only through Parameter Store. The boot script reads `tailscale-auth-key` and nothing else; `github-token` and `model-api-key` are reserved and are not needed to test the connection.
- **Not on the host:** K3s, Paperclip, Kitteth, Telegram or any controller workload.

The stack is `infra/aws/agent-host-stack.yaml`; the scripts are in `operations/aws/agent-host/`.

## Egress and what a security group cannot enforce

The security group allows only outbound TCP 443 (GitHub, the model API, package registries, Tailscale coordination and DERP relays), TCP 80 (signed Ubuntu package archives), UDP 3478 (Tailscale STUN) and UDP 41641 (Tailscale direct connections to peers on the default port).

A security group filters by address and port, not by name, so it cannot hold these GOV-020 limits by itself:

- TCP 443 and TCP 80 reach any address, not only GitHub, the model API, package registries and Tailscale.
- DNS through the VPC resolver is never filtered by security groups, so DNS stays open to every name.
- A direct peer connection to a peer behind NAT uses a translated port, so it usually falls back to a DERP relay over TCP 443. Sessions still work, with extra latency.

Name-based enforcement needs a DNS firewall, a network firewall or an egress proxy. That is outside this prototype.

## Before the build

1. In the Tailscale admin console, make sure the tailnet policy has a `tagOwners` entry for `tag:ki-techne-agent-host`, a grant that admits only Kris's devices to that tag, and an `ssh` rule that accepts Kris's identity for user `kris` on that tag. Record where this policy lives; no repository records it today.
2. Generate an auth key: not reusable, not ephemeral, pre-approved, tagged `tag:ki-techne-agent-host`, with a short expiry such as one day. Copy it to the clipboard.
3. Sign in with the administrator profile: run `assume knowledge-islands-techne`. The `knowledge-islands-techne-agent-host` permission set cannot create or tag resources, so it cannot build the host.
4. Store the key without putting it in a command argument, then clear the clipboard:

   ```sh
   pbpaste | aws ssm put-parameter --profile knowledge-islands-techne --region eu-west-1 \
     --name /ki/techne/agent-host/tailscale-auth-key --type SecureString --value file:///dev/stdin
   pbcopy </dev/null
   ```

## Build

From the repository root, still under the administrator profile:

```sh
bash operations/aws/agent-host/provision.sh
```

The script refuses any account other than `655383751458`, refuses to run if the `ki-techne-agent-host` stack already exists or the auth-key parameter is missing, and deploys only that stack. It never touches `ki-techne-ops-007-controller`. Override the size with `AGENT_HOST_INSTANCE_TYPE` (`t3.medium`, `t3.large` or `t3.xlarge`) and `AGENT_HOST_VOLUME_SIZE` (16 to 100 GB).

The boot script takes a few minutes. Its log goes to the instance console and `/var/log/ki-agent-host-bootstrap.log`, never including the key. To read it from the Mac:

```sh
aws ec2 get-console-output --profile knowledge-islands-techne --region eu-west-1 --latest \
  --instance-id <AgentHostInstanceId> --output text
```

## Verify over Tailscale

1. `tailscale status` lists `ki-techne-agent-host` with the tag.
2. `ssh kris@ki-techne-agent-host 'whoami; git --version; node --version; ~/.local/bin/claude --version'` prints `kris` and the three versions.
3. In Zed, open the `ki-techne-agent-host` remote with `upload_binary_over_ssh` enabled; the host never downloads the Zed server itself.
4. Delete the spent auth-key parameter: `aws ssm delete-parameter --profile knowledge-islands-techne --region eu-west-1 --name /ki/techne/agent-host/tailscale-auth-key`. Tailscale keeps the node joined across reboots.

The `kris` user installs anything else it needs, such as Bun, mise or `ki`, in its own home directory.

## Kill switch

Do both steps; either one alone stops access.

1. Stop the host, which ends every session on it. With `assume knowledge-islands-techne-agent-host`:

   ```sh
   bash operations/aws/agent-host/stop.sh
   ```

   It stops only a running instance tagged `ki-agent-host-id = agent-host`, `ki-lifecycle = prototype` and `Name = ki-techne-agent-host`.

2. In the Tailscale admin console, remove the `ki-techne-agent-host` device and revoke any unused auth key for its tag.

## Teardown

With `assume knowledge-islands-techne`:

```sh
CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host bash operations/aws/agent-host/destroy.sh
```

It refuses a stack that is not tagged `ki-agent-host-id = agent-host`, deletes the `ki-techne-agent-host` stack and waits for every resource to go, then deletes the three parameters under `/ki/techne/agent-host/`. Then, outside this repository:

1. Remove the device, its tag owner, grant and `ssh` rule from the tailnet policy, and revoke any remaining auth key.
2. Revoke any GitHub token or model API key issued for the host.
3. Remove the `KnowledgeIslandsTechneAgentHost` permission set assignment and permission set, and the `knowledge-islands-techne-agent-host` profile and SSH and Zed entries from the chezmoi source, applying only after reviewing `chezmoi diff`.

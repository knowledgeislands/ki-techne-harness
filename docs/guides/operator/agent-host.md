# Build and operate the agent host

This runbook is for Kris, as the operator who builds, connects to, stops and tears down the prototype agent host that `KI-ARCADIA-GOV-020` authorises. The host is a separate EC2 instance, `ki-techne-agent-host`, in account `655383751458`, region `eu-west-1`. It sits beside the retained controller `ki-techne-ops-007-primary` and shares nothing with it: its own stack, network, security group, instance role and instance profile.

Run nothing here until the gate in `KI-ARCADIA-GOV-020` has cleared and the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) names this prototype. Agents prepare and review this path; only Kris runs it.

## What the host is

- **Operator OS user:** `techne`. It is a non-root user without `sudo`. Use `techne@ki-techne-agent-host` in the chezmoi SSH `Host` entry and in Zed's `ssh_connections` entry.
- **Tailnet name:** `ki-techne-agent-host`, advertising `tag:ki-techne-agent-host`.
- **Access:** Tailscale SSH only. The security group has no inbound rule; the boot script disables the OpenSSH listener and the session-manager agent, and the instance role has no session-manager permission.
- **Image:** Ubuntu from the controller's pinned image, with Git, `tmux`, `jq`, Node.js from the latest `24.x` release (checksum-verified), the AWS CLI and Tailscale. Claude Code is installed for `techne` by the native installer in `~/.local/bin`, and `techne`'s Git uses the `ki-agent-host` credential helper for GitHub.
- **Size:** `t3.medium` with a 40 GB encrypted `gp3` volume by default. At list prices this is roughly 33 USD a month while running, plus about 3.50 USD for the volume and 3.65 USD for the public IPv4 address, which exists only for outbound traffic.
- **Secrets:** the instance role may read only Parameter Store names under `/ki/techne/agent-host/`, decrypting only through Parameter Store. The boot script reads `tailscale-auth-key` and nothing else. The Git credential helper reads `github-token` when Git asks for GitHub credentials. `model-api-key` stays unused: Claude Code signs in interactively as Kris instead, so no model API key is stored.
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

1. In the Tailscale admin console, merge the [tailnet policy](#tailnet-policy) below into the existing policy file. The console is the policy's only record; no repository holds it.
2. Generate an auth key under **Settings → Keys → Generate auth key**:
   - **Reusable:** off, so the key joins one device only.
   - **Ephemeral:** off, so the node survives a stop and start.
   - **Pre-approved:** on. The option appears only when device approval is enabled; without device approval nothing is needed.
   - **Tags:** on, with `tag:ki-techne-agent-host` only. The tag must already be in `tagOwners`.
   - **Expiration:** one day, the shortest the build needs.

   Copy the key to the clipboard.
3. Sign in with the administrator profile: run `assume knowledge-islands-techne`. The `knowledge-islands-techne-agent-host` permission set cannot create or tag resources, so it cannot build the host.
4. Store the key without putting it in a command argument, then clear the clipboard:

   ```sh
   pbpaste | aws ssm put-parameter --profile knowledge-islands-techne --region eu-west-1 \
     --name /ki/techne/agent-host/tailscale-auth-key --type SecureString --value file:///dev/stdin
   pbcopy </dev/null
   ```

## Tailnet policy

Merge these entries into the existing tailnet policy file in the Tailscale admin console under **Access controls**. Do not replace the file: add each entry to the existing section of the same name, creating the section only if it is absent. The policy is HuJSON, so comments and trailing commas are accepted.

```jsonc
{
  // Add to "tagOwners".
  "tagOwners": {
    "tag:ki-techne-agent-host": ["kris.me.uk@gmail.com"],
  },

  // Add to "acls": Kris may reach the agent host on TCP 22 only.
  "acls": [
    {
      "action": "accept",
      "src": ["kris.me.uk@gmail.com"],
      "dst": ["tag:ki-techne-agent-host:22"],
    },
  ],

  // Add to "ssh": Tailscale SSH admits Kris as the techne user only.
  "ssh": [
    {
      "action": "accept",
      "src": ["kris.me.uk@gmail.com"],
      "dst": ["tag:ki-techne-agent-host"],
      "users": ["techne"],
    },
  ],

  // Optional: add to "tests" and "sshTests" so a later edit cannot widen access unnoticed.
  "tests": [
    {
      "src": "kris.me.uk@gmail.com",
      "accept": ["tag:ki-techne-agent-host:22"],
      "deny": ["tag:ki-techne-agent-host:80"],
    },
  ],
  "sshTests": [
    {
      "src": "kris.me.uk@gmail.com",
      "dst": ["tag:ki-techne-agent-host"],
      "accept": ["techne"],
      "deny": ["root"],
    },
  ],
}
```

If the policy uses `grants` instead of `acls`, add this grant in place of the `acls` entry:

```jsonc
{
  "src": ["kris.me.uk@gmail.com"],
  "dst": ["tag:ki-techne-agent-host"],
  "ip": ["tcp:22"],
},
```

**Default allow-all.** A policy that still holds Tailscale's default rule, `{"action": "accept", "src": ["*"], "dst": ["*:*"]}` (or the grant `{"src": ["*"], "dst": ["*"], "ip": ["*"]}`), lets every node reach every other, so the tagged host could reach Kris's devices and any other node. Replace that rule with one whose source excludes tagged devices, keeping members' access to each other:

```jsonc
{"action": "accept", "src": ["autogroup:member"], "dst": ["autogroup:member:*"]},
```

`autogroup:member` covers devices that belong to a tailnet user, not tagged devices, so the agent host then has no outbound access to any node. Before saving, list what the old rule allowed that the new one does not, such as other tagged nodes, shared-in devices or exit nodes, and add a specific rule for each one still needed; for exit-node use, add `"autogroup:internet:*"` to the destination. Kris's access to the agent host stays limited to the explicit port 22 rule above.

These entries follow Tailscale's documented policy-file schema as understood when this runbook was written; they were not validated against a live tailnet. The console validates the policy on save and rejects an invalid one without changing anything. Points to check there: whether the `tests` and `sshTests` forms are accepted as written, whether a tailnet that has moved to `grants` still accepts `acls` beside them, and whether `autogroup:member` is accepted as a destination in the tailnet's policy version.

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
2. `ssh techne@ki-techne-agent-host 'whoami; git --version; node --version; ~/.local/bin/claude --version'` prints `techne` and the three versions.
3. In Zed, open the `ki-techne-agent-host` remote with `upload_binary_over_ssh` enabled; the host never downloads the Zed server itself.
4. Delete the spent auth-key parameter: `aws ssm delete-parameter --profile knowledge-islands-techne --region eu-west-1 --name /ki/techne/agent-host/tailscale-auth-key`. Tailscale keeps the node joined across reboots.

The `techne` user installs anything else it needs, such as Bun, mise or `ki`, in its own home directory.

## Credentials on the host

Claude Code and GitHub use different credentials, and neither is stored in the repository or passed on a command line.

### Claude Code

Claude Code signs in interactively as Kris, so no model API key is stored and `/ki/techne/agent-host/model-api-key` stays unused. Over Tailscale SSH, run `claude` as `techne` on the host and choose the Claude account login. It prints a sign-in URL: open it in a browser on the Mac, approve the sign-in, and paste the returned code into the SSH session. The session's credentials stay in `techne`'s home directory on the host.

### GitHub

GitHub uses a fine-grained personal access token that Kris creates in GitHub under **Settings → Developer settings → Personal access tokens → Fine-grained tokens**:

- **Resource owner:** `knowledgeislands`. If the organisation requires approval for fine-grained tokens, an owner must approve the request before the token works.
- **Expiration:** 30 days.
- **Repository access:** only the Knowledge Islands repositories Kris selects.
- **Permissions:** Contents read and write; Metadata read-only, which GitHub adds automatically. Nothing else.

Copy the token to the clipboard, then store it without echoing it and clear the clipboard:

```sh
pbpaste | aws ssm put-parameter --profile knowledge-islands-techne --region eu-west-1 \
  --name /ki/techne/agent-host/github-token --type SecureString --value file:///dev/stdin
pbcopy </dev/null
```

The boot script installs `/usr/local/bin/git-credential-ki-agent-host` and sets it as `techne`'s Git credential helper for `https://github.com`. When Git needs GitHub credentials, the helper reads the parameter through the instance role and answers with it; it ignores other hosts and other credential actions and writes nothing to disk. Clone over HTTPS, for example `git clone https://github.com/knowledgeislands/<repository>.git`; SSH remotes do not use the helper. To check the token from the host, run `git ls-remote https://github.com/knowledgeislands/<repository>.git`.

To rotate the token, create a new one, overwrite the parameter by adding `--overwrite` to the command above, and revoke the old one in GitHub. The token expires after 30 days whether or not the host is still running.

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

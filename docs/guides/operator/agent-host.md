# Build and operate the agent host

This runbook is for Kris, as the operator who builds, connects to, stops and tears down the prototype agent host that `KI-ARCADIA-GOV-020` authorises. The host is a separate EC2 instance, `ki-techne-agent-host`, in account `655383751458`, region `eu-west-1`. It sits beside the retained controller `ki-techne-ops-007-primary` and shares nothing with it: its own stack, network, security group, instance role and instance profile.

The host runs under the one standing exemption that the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) carries, recorded in `GDR-KI-ARCADIA-004` and set through `KI-ARCADIA-GOV-023` within the bounds `KI-ARCADIA-GOV-020` accepted. The exemption has no automatic lapse: it stands until Kris changes or withdraws it, and Kris reviews it on 2026-11-06. It covers this one host and nothing else. Agents prepare and review this path; only Kris runs it.

## At a glance

![The agent host: Kris's Mac, the tailnet and the host in the Techne account, with its operator role, instance role and Parameter Store](agent-host-architecture.svg)

On the Mac, the chezmoi helper `techne-agent-host` checks the host and opens Zed's `ssh://` remote; Zed reaches the host through the Tailscale client over WireGuard, and the tailnet policy admits only `techne` over Tailscale SSH. The host sits in its own security group with no inbound rule and talks out only over HTTPS, to GitHub with a fine-grained token and to the model provider through Kris's Claude account login. Its instance role reads only the parameters under `/ki/techne/agent-host/`.

Granted turns Kris's SSO admin session into the account-local operator role, which may only start and stop the host. The controller `ki-techne-ops-007-primary` is drawn for contrast: it is held, has its own stack and is untouched.

Two AWS profiles are in play. The build and teardown use the admin profile `knowledge-islands-techne`; stop, start and the kill switch use `knowledge-islands-techne-agent-host`. The diagram's source is [`agent-host-architecture.archify.json`](agent-host-architecture.archify.json).

## What the host is

- **Operator OS user:** `techne`. It is a non-root user without `sudo`. Use `techne@ki-techne-agent-host` in the chezmoi SSH `Host` entry and in Zed's `ssh_connections` entry.
- **Tailnet name:** `ki-techne-agent-host`, advertising `tag:ki-techne-agent-host`.
- **Access:** Tailscale SSH only. The security group has no inbound rule; the boot script disables the OpenSSH listener and the session-manager agent, and the instance role has no session-manager permission.
- **Image:** Ubuntu from the controller's pinned image, with Git, `tmux`, `jq`, `zsh`, Node.js from the latest `24.x` release (checksum-verified), the AWS CLI and Tailscale. Claude Code is installed for `techne` by the native installer in `~/.local/bin`, and `techne`'s Git uses the `ki-agent-host` credential helper for GitHub.
- **Hostname:** the boot script sets the OS hostname to `ki-techne-agent-host`, keeps it across reboots with cloud-init's `preserve_hostname` and adds it to `/etc/hosts` so `sudo` and local lookups resolve it. This applies from the next build: a host built before it, including the current one, keeps the AWS default name such as `ip-10-90-0-40` until it is rebuilt, because `techne` has no `sudo` to rename it. The same holds for `zsh`.
- **Size:** `t3.medium` with a 40 GB encrypted `gp3` volume by default. At list prices this is roughly 33 USD a month while running, plus about 3.50 USD for the volume and 3.65 USD for the public IPv4 address, which exists only for outbound traffic.
- **Secrets:** the instance role may read only Parameter Store names under `/ki/techne/agent-host/`, decrypting only through Parameter Store. The boot script reads `tailscale-auth-key` and nothing else. The Git credential helper reads `github-token` when Git asks for GitHub credentials. `model-api-key` stays unused: Claude Code signs in interactively as Kris instead, so no model API key is stored.
- **Not on the host:** K3s, Paperclip, Kitteth, Telegram or any controller workload.

The stack is `infra/aws/agent-host-stack.yaml`; the scripts are in `operations/aws/agent-host/`.

## Recipe and binding

The host is the first binding, `agent-host`, of the harness recipe `direct-host`, whose agents run on the host itself. The recipe's manifest, [`recipes/direct-host/recipe.toml`](../../../recipes/direct-host/recipe.toml), names the stack and scripts, the fields a binding fills in, the environment variable each script reads for each field, the resource selectors and recipe-owned tags, and the footprint a binding leaves. A binding is a person's named instance, held outside this repository at `~/.config/techne/hosts/<name>.toml` with schema `techne/host-binding/v1`; it names its provider by carrying exactly one provider table, here `[aws]`. The `techne` CLI in `tools-techne` reads both and runs these scripts with every variable set from the binding; the manifest and the variables are the only contract between the two repositories.

Run by hand with no variable set, every script behaves as the `agent-host` binding: each default below is that binding's value. A field the manifest marks required has no recipe default, so the binding must give it; the scripts still default it to today's value. A recipe default may be derived from the binding name, written `{name}`.

| Binding field | Recipe default | Variable | Read by |
| --- | --- | --- | --- |
| `host_name` | `ki-techne-{name}` | `AGENT_HOST_NAME` | `setup.sh`, `provision.sh`, `stop.sh` |
| `tailscale_name` | `ki-techne-{name}` | `AGENT_HOST_TAILSCALE_NAME` | `setup.sh`, `status.sh`, `provision.sh` |
| `tailscale_tag` | `tag:ki-techne-{name}` | `AGENT_HOST_TAILSCALE_TAG` | `provision.sh` |
| `repositories` | `operations/aws/agent-host/host/repositories.txt` | `AGENT_HOST_REPOSITORIES` | `setup.sh` |
| `workspace` | `~/workspaces/kit` | `KI_AGENT_HOST_WORKSPACE` | `setup.sh`, `status.sh` |
| `aws.account` | required | `EXPECTED_AWS_ACCOUNT` | `provision.sh`, `stop.sh`, `destroy.sh` |
| `aws.region` | required | `AWS_REGION` | `provision.sh`, `stop.sh`, `destroy.sh` |
| `aws.admin_profile` | required | `AWS_PROFILE` | `provision.sh`, `destroy.sh` |
| `aws.operator_profile` | required | `AWS_PROFILE` | `stop.sh` |
| `aws.tag` | `{name}` | `AGENT_HOST_ID` | `provision.sh`, `stop.sh`, `destroy.sh` |
| `aws.stack_name` | `ki-techne-{name}` | `AGENT_HOST_STACK_NAME` | `provision.sh`, `destroy.sh` |
| `aws.parameter_prefix` | `/ki/techne/{name}` | `AGENT_HOST_PARAMETER_PREFIX` | `provision.sh`, `destroy.sh` |
| `aws.operator_role` | `ki-techne-{name}-operator` | none | the CLI's provider adapter only |
| `aws.instance_type` | `t3.medium` | `AGENT_HOST_INSTANCE_TYPE` | `provision.sh` |
| `aws.volume_size` | `40` | `AGENT_HOST_VOLUME_SIZE` | `provision.sh` |

`setup.sh` and `status.sh` read no AWS variable: they reach the host by its Tailscale name over SSH, and pass the workspace to the host scripts, which expand a leading `~/` to the operator's home there. `provision.sh` passes the host name, Tailscale name and tag, tag value and parameter prefix to the stack's `HostName`, `TailscaleHostname`, `TailscaleTag`, `AgentHostId` and `ParameterPrefix` parameters, and tags the stack with the tag value. `AGENT_HOST_INSTRUCTIONS` is not a binding field: it is the person's own list of Claude instruction files that `setup.sh` renders, space-separated names under `~/.claude`, defaulting to `CLAUDE.md communication.md delegation.md memory-scope.md markdown.md`.

`bun run test` checks the manifest offline: every binding field declared once, in its provider-neutral or provider section, no AWS concept outside `[providers.aws]`, each listed script reading its variable, and each script default equal to the `agent-host` binding's value.

## Egress and what a security group cannot enforce

The security group allows only outbound TCP 443 (GitHub, the model API, package registries, Tailscale coordination and DERP relays), TCP 80 (signed Ubuntu package archives), UDP 3478 (Tailscale STUN) and UDP 41641 (Tailscale direct connections to peers on the default port).

A security group filters by address and port, not by name, so it cannot hold these GOV-020 limits by itself:

- TCP 443 and TCP 80 reach any address, not only GitHub, the model API, package registries and Tailscale.
- DNS through the VPC resolver is never filtered by security groups, so DNS stays open to every name.
- A direct peer connection to a peer behind NAT uses a translated port, so it usually falls back to a DERP relay over TCP 443. Sessions still work, with extra latency.

Name-based enforcement needs a DNS firewall, a network firewall or an egress proxy. That is outside this prototype.

## Operator access

The `knowledge-islands-techne-agent-host` AWS profile assumes the IAM role `arn:aws:iam::655383751458:role/ki/ki-techne-agent-host-operator` from Kris's existing `knowledge-islands-techne` SSO profile. The role lives in the Techne account alone: only that account's `AWSAdministratorAccess` SSO role may assume it, sessions last at most 8 hours, and its inline policy is the `KI-ARCADIA-GOV-020` least-privilege policy unchanged. Nothing in the organisation or its management account is created or changed for the prototype; it relies only on Kris's existing SSO access to the account.

## Before the build

1. In the Tailscale admin console, merge the [tailnet policy](#tailnet-policy) below into the existing policy file. The console is the policy's only record; no repository holds it.
2. Generate an auth key under **Settings → Keys → Generate auth key**:
   - **Reusable:** off, so the key joins one device only.
   - **Ephemeral:** off, so the node survives a stop and start.
   - **Pre-approved:** on. The option appears only when device approval is enabled; without device approval nothing is needed.
   - **Tags:** on, with `tag:ki-techne-agent-host` only. The tag must already be in `tagOwners`.
   - **Expiration:** one day, the shortest the build needs.

   Copy the key to the clipboard.
3. Sign in with the administrator profile: run `assume knowledge-islands-techne`. The `knowledge-islands-techne-agent-host` operator role cannot create or tag resources, so it cannot build the host.
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

In a policy that uses `grants`, the replacement grant is:

```jsonc
{"src": ["autogroup:member"], "dst": ["autogroup:member"], "ip": ["*"]},
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

The boot script ends by printing `ki-agent-host bootstrap complete`. It also writes a ready marker under `/var/lib/ki-agent-host/`, but that directory is root-only and `techne` has no `sudo`, so check the bootstrap log or console output for the completion line instead.

## Verify over Tailscale

1. `tailscale status` lists `ki-techne-agent-host` with the tag.
2. `ssh techne@ki-techne-agent-host 'whoami; git --version; node --version; ~/.local/bin/claude --version'` prints `techne` and the three versions, and `ssh techne@ki-techne-agent-host hostname` prints `ki-techne-agent-host`. The first connection asks you to accept the host key. Claude Code is at `~/.local/bin/claude`, which is not on the `PATH` of a non-interactive SSH command, so name it in full there; an interactive login shell finds it as `claude`.
3. In Zed, open the `ki-techne-agent-host` remote with `upload_binary_over_ssh` enabled; the host never downloads the Zed server itself.
4. Delete the spent auth-key parameter: `aws ssm delete-parameter --profile knowledge-islands-techne --region eu-west-1 --name /ki/techne/agent-host/tailscale-auth-key`. Tailscale keeps the node joined across reboots.

Set up the `techne` workspace next, as [Workspace setup](#workspace-setup) describes, once the GitHub token is in place.

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

## Workspace setup

One rerunnable command from the Mac converges `techne`'s workspace on the host. Run it after every build, and again whenever the repository set, a tool pin or Kris's Claude instructions change:

```sh
bash operations/aws/agent-host/setup.sh          # add --pull to fast-forward clean checkouts
```

It needs `chezmoi` on the Mac and uses SSH to the binding's Tailscale name only, `ki-techne-agent-host` unless `AGENT_HOST_TAILSCALE_NAME` is set. It renders Kris's Claude instructions with `chezmoi cat`, copies them with the host scripts over one connection and runs `host/converge.sh` there. That script converges:

- the Git identity from the Mac's global configuration and the house pull, branch and push settings;
- the repositories in [`host/repositories.txt`](../../../operations/aws/agent-host/host/repositories.txt), in the Mac's `~/workspaces/kit/<organisation>/<repository>` layout. It clones a missing repository, leaves a checkout with uncommitted changes alone and, with `--pull`, only fast-forwards a clean one;
- mise and its global pins for Bun, Node and the Codex CLI, each repository's own mise tools and its Bun dependencies;
- one shell environment file, `~/.config/ki-agent-host/env.sh`, sourced from `.profile`, `.bashrc` and Husky's `init.sh`, so tools are on `PATH` in non-interactive SSH and Git hooks too;
- the `ki` CLI at its pinned version, `ki bootstrap` for Claude Code and Codex, the local `ki-agentic-harness` checkout, the registry and the repositories' skill projections;
- Kris's Claude instructions in `~/.claude`, the files `AGENT_HOST_INSTRUCTIONS` names, each with a header naming its source, and `autoMemoryEnabled` set to `false`.

It never copies credentials, MCP configuration or any other part of `~/.claude`. It backs up any file it replaces under `~/.local/state/ki-agent-host/backups/`. A run that finds nothing to do ends with `no changes`; a failed step makes it exit non-zero. On the host, `bash host/converge.sh` from the harness checkout does the same without the Claude instructions.

Two steps remain Kris's. Sign Claude Code in as [Claude Code](#claude-code) describes. Sign Codex in by running `codex login` as `techne` on the host, which prints a sign-in URL to approve on the Mac.

### Status

Before you stop or tear down the host, and whenever you want to know what is at risk, run the read-only report from the Mac:

```sh
bash operations/aws/agent-host/status.sh
```

For each repository it lists the branch, uncommitted files, commits that no remote branch contains, stashes and the ahead and behind counts as of the last fetch, and flags any with work at risk. It also lists the GitHub token's expiry, the Tailscale node key's expiry and the date of the exemption's scheduled review, which is not a lapse. It changes and fetches nothing.

## A working session

![One working session: Kris connects through the helper and Zed over Tailscale, runs Claude Code on the host, and pushes only on request through the credential helper](agent-host-session.svg)

Kris runs `techne-agent-host connect [path]`. The helper checks that Tailscale is up and the host answers, then opens Zed's `ssh://` remote; with `--aws` it first assumes the agent-host profile and starts the host if it is stopped. Zed connects as `techne` over the tailnet, uploads its server binary from the Mac, and Kris opens a repository and a terminal.

In that session Claude Code runs as `techne` and commits explicit paths. It pushes only when Kris asks. Git then asks the credential helper, which reads the token through the instance role and answers with it, so the token never reaches disk. Only Kris opens sessions: no schedule, webhook or message starts one. The diagram's source is [`agent-host-session.archify.json`](agent-host-session.archify.json).

## Kill switch

Do both steps; either one alone stops access.

1. Stop the host, which ends every session on it. If time allows, run [Status](#status) first so nothing unlanded is lost. With `assume knowledge-islands-techne-agent-host`:

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
3. With `assume knowledge-islands-techne`, delete the inline policy and then the `ki-techne-agent-host-operator` role in account `655383751458`, and remove the `knowledge-islands-techne-agent-host` profile and SSH and Zed entries from the chezmoi source, applying only after reviewing `chezmoi diff`.

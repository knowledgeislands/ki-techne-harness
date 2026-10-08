# Build and operate the agent host

This runbook is for Kris, as the operator who builds, connects to, stops and tears down the prototype agent host that `KI-ARCADIA-GOV-020` authorises. The host is a separate EC2 instance, `ki-techne-agent-host`, in account `655383751458`, region `eu-west-1`. It sits beside the retained controller `ki-techne-ops-007-primary` and shares nothing with it: its own stack, network, security group, instance role and instance profile.

The host runs under the one standing exemption that the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) carries, recorded in `GDR-KI-ARCADIA-004` and set through `KI-ARCADIA-GOV-023` within the bounds `KI-ARCADIA-GOV-020` accepted. The exemption has no automatic lapse: it stands until Kris changes or withdraws it. It covers this one host and nothing else. Agents prepare and review this path; only Kris runs it.

## At a glance

![The agent host: Kris's Mac, the tailnet and the host in the Techne account, with its operator role, instance role and Parameter Store](agent-host-architecture.svg)

On the Mac, the chezmoi helper `techne-agent-host` checks the host and opens Zed's `ssh://` remote; Zed reaches the host through the Tailscale client over WireGuard, and the tailnet policy admits only `techne` over Tailscale SSH. The host sits in its own security group with no inbound rule and talks out only over HTTPS, to GitHub with a fine-grained token and to the model provider through Kris's Claude account login. Its instance role reads only the parameters under `/ki/techne/agent-host/`.

Granted turns Kris's SSO admin session into the account-local operator role, which may start, stop, reboot and terminate the tagged host but cannot delete its stack. The controller `ki-techne-ops-007-primary` is drawn for contrast: it is held, has its own stack and is untouched.

Two AWS profiles are in play. The build, rebuild and withdrawal use the admin profile `knowledge-islands-techne`; stop, start and the kill switch use `knowledge-islands-techne-agent-host`. The diagram's source is [`agent-host-architecture.archify.json`](agent-host-architecture.archify.json).

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
| `tailscale_name` | `ki-techne-{name}` | `AGENT_HOST_TAILSCALE_NAME` | `setup.sh`, `status.sh`, `provision.sh`, `stop.sh`, `destroy.sh` |
| `tailscale_tag` | `tag:ki-techne-{name}` | `AGENT_HOST_TAILSCALE_TAG` | `provision.sh` |
| `repositories` | `operations/aws/agent-host/host/repositories.txt` | `AGENT_HOST_REPOSITORIES` | `setup.sh`, `status.sh`, `stop.sh`, `destroy.sh` |
| `workspace` | `~/workspaces/kit` | `KI_AGENT_HOST_WORKSPACE` | `setup.sh`, `status.sh`, `stop.sh`, `destroy.sh` |
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

`setup.sh` and `status.sh` read no AWS variable: they reach the host by its Tailscale name over SSH, and pass the workspace to the host scripts, which expand a leading `~/` to the operator's home there. `stop.sh` and `destroy.sh` read the Tailscale name, repository list and workspace only to pass them to `status.sh`, which reads the host's status before they act. `provision.sh` passes the host name, Tailscale name and tag, tag value and parameter prefix to the stack's `HostName`, `TailscaleHostname`, `TailscaleTag`, `AgentHostId` and `ParameterPrefix` parameters, and tags the stack with the tag value. `AGENT_HOST_INSTRUCTIONS` is not a binding field: it is the person's own list of Claude instruction files that `setup.sh` renders, space-separated names under `~/.claude`, defaulting to `CLAUDE.md communication.md delegation.md memory-scope.md markdown.md`.

`bun run test` checks the manifest offline: every binding field declared once, in its provider-neutral or provider section, no AWS concept outside `[providers.aws]`, each listed script reading its variable, and each script default equal to the `agent-host` binding's value. It also checks the `[status]` table, which declares the status report's schema and exit statuses, and the `[operations]` table, which names the `rebuild` and `withdraw` operations of the `destroy` script.

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
- **Expiration:** 90 days.
- **Repository access:** only the Knowledge Islands repositories Kris selects.
- **Permissions:** Contents read and write; Metadata read-only, which GitHub adds automatically. Nothing else.

Copy the token to the clipboard, then store it without echoing it and clear the clipboard:

```sh
pbpaste | aws ssm put-parameter --profile knowledge-islands-techne --region eu-west-1 \
  --name /ki/techne/agent-host/github-token --type SecureString --value file:///dev/stdin
pbcopy </dev/null
```

The boot script installs `/usr/local/bin/git-credential-ki-agent-host` and sets it as `techne`'s Git credential helper for `https://github.com`. When Git needs GitHub credentials, the helper reads the parameter through the instance role and answers with it; it ignores other hosts and other credential actions and writes nothing to disk. Clone over HTTPS, for example `git clone https://github.com/knowledgeislands/<repository>.git`; SSH remotes do not use the helper. To check the token from the host, run `git ls-remote https://github.com/knowledgeislands/<repository>.git`.

To rotate the token, create a new one, overwrite the parameter by adding `--overwrite` to the command above, and revoke the old one in GitHub. The token expires after 90 days whether or not the host is still running.

## Workspace setup

One rerunnable command from the Mac converges `techne`'s workspace on the host. Run it after every build, and again whenever the repository set, a pin in [`recipes/direct-host/rig.toml`](../../../recipes/direct-host/rig.toml) or Kris's Claude instructions change:

```sh
bash operations/aws/agent-host/setup.sh          # add --pull to fast-forward clean checkouts
```

It needs `chezmoi` on the Mac and uses SSH to the binding's Tailscale name only, `ki-techne-agent-host` unless `AGENT_HOST_TAILSCALE_NAME` is set. It renders Kris's Claude instructions with `chezmoi cat`, copies them with the host scripts over one connection and runs `host/converge.sh` there. That script converges:

- the Git identity from the Mac's global configuration and the house pull, branch and push settings;
- the repositories in [`host/repositories.txt`](../../../operations/aws/agent-host/host/repositories.txt), in the Mac's `~/workspaces/kit/<organisation>/<repository>` layout. It clones a missing repository, leaves a checkout with uncommitted changes alone and, with `--pull`, only fast-forwards a clean one;
- mise and its global pins for Bun, Node and the Codex CLI, exact versions read from the recipe's pin file, then each repository's own mise tools and Bun dependencies, leaving each repository's `mise.toml` alone;
- one shell environment file, `~/.config/ki-agent-host/env.sh`, sourced from `.profile`, `.bashrc` and Husky's `init.sh`, so tools are on `PATH` in non-interactive SSH and Git hooks too;
- the `ki` CLI at its pinned version, `ki bootstrap` for Claude Code and Codex, the local `ki-agentic-harness` checkout, the registry and the repositories' skill projections;
- Rig at its pinned tag, with the pin file as `~/.config/rig/rig.toml` and the observe-only `direct-host-pins` provider: Rig reports drift and installs nothing yet;
- Kris's Claude instructions in `~/.claude`, the files `AGENT_HOST_INSTRUCTIONS` names, each with a header naming its source, and `autoMemoryEnabled` set to `false`;
- the recipe's own host instructions, `recipes/direct-host/host-instructions.md`, as `~/.claude/rules/ki-agent-host.md` for Claude Code and `~/.codex/AGENTS.md` for Codex: push where you worked, be level before working on the other machine, and leave roadmap writes to the workstation checkout;
- the host marker, `~/.config/ki/host-marker`, which `ki` will honour by refusing roadmap writes once [KI-TOOL-CLI-115](https://github.com/knowledgeislands/tools-ki/blob/main/docs/roadmap/KI-TOOL-CLI-115-refuse-host-roadmap-writes.md) lands;
- the login banner, `~/.config/ki-agent-host/banner.sh`, which an interactive shell shows once.

It never copies credentials, MCP configuration or any other part of `~/.claude`. It backs up any file it replaces under `~/.local/state/ki-agent-host/backups/`. A run that finds nothing to do ends with `no changes`; a failed step makes it exit non-zero. On the host, `bash host/converge.sh` from the harness checkout does the same without the Claude instructions.

Two steps remain Kris's. Sign Claude Code in as [Claude Code](#claude-code) describes. Sign Codex in by running `codex login` as `techne` on the host, which prints a sign-in URL to approve on the Mac.

### Status

Before you stop, rebuild or withdraw the host, and whenever you want to know what is at risk, run the read-only report from the Mac:

```sh
bash operations/aws/agent-host/status.sh             # add --fetch to refresh the remote-tracking branches first
```

Work on the host is safe only once it is in Git on a remote, on any branch (`ODR-KI-ARCADIA-001`). The report covers the repositories the binding declares, `host/repositories.txt` by default. A repository is **at risk** when it has uncommitted or untracked files, commits on any local branch that no remote branch contains, or stashes; files Git ignores do not count, and a linked worktree's uncommitted files count towards its repository. Everything else on the host is disposable by rule: Claude Code and Codex sign-ins and transcripts, caches, hand-made backups and any checkout outside the declared set. Land anything you want to keep from those by hand.

For each repository the report lists the branch, uncommitted files, unpushed commits, stashes and the ahead and behind counts as of the last fetch, and flags it `AT RISK` or `UNKNOWN`. The inventory fails closed: a missing workspace, a declared repository that is absent, a repository outside the declared set or a Git read that fails makes the outcome **unknown** rather than clean, and the report lists why. It then lists each pinned tool's state from `rig status --profile direct-host`, flagging `DRIFT`, and the GitHub token's and the Tailscale node key's expiries, flagging `EXPIRES SOON` within 14 days, and ends with a summary line such as `summary: REPOSITORIES=3 AT_RISK=1 UNKNOWN=0 OUTCOME=at-risk`. Last, it compares the Mac's own tools with the same pins, as a signal that never changes the exit status. The text report records the expiry dates, the drifted tools and the time of the check in `~/.cache/ki-agent-host/expiry` on the host; the login banner reads only that file and the clock, and shows one line for an expiry within 14 days, for drift, and for a check older than 7 days or none. Run the text report at least weekly. The report changes nothing else; `--fetch` runs `git fetch --all --prune` in each repository, which updates only remote-tracking branches, and a failed fetch makes that repository unknown.

The exit status carries the outcome: 0 clean, 3 at risk, 4 unknown, 1 when the report itself fails, and SSH's own 255 when the host cannot be reached. `--json` prints one `techne/host-workspace/v1` document instead of the table, naming the host by its hostname and `host.id`, the provider-defined identity of the machine: the cloud-init instance ID on AWS, and a hardware or install UUID on owned hardware, and `--connect-timeout <seconds>` bounds the wait for an unreachable host. `stop.sh` and `destroy.sh` read this document; the `techne` CLI reads it through the `[status]` table of the recipe manifest.

## A working session

![One working session: Kris connects through the helper and Zed over Tailscale, runs Claude Code on the host, and pushes only on request through the credential helper](agent-host-session.svg)

Kris runs `techne-agent-host connect [path]`. The helper checks that Tailscale is up and the host answers, then opens Zed's `ssh://` remote; with `--aws` it first assumes the agent-host profile and starts the host if it is stopped. Zed connects as `techne` over the tailnet, uploads its server binary from the Mac, and Kris opens a repository and a terminal.

In that session Claude Code runs as `techne` and commits explicit paths. It pushes only when Kris asks. Git then asks the credential helper, which reads the token through the instance role and answers with it, so the token never reaches disk. Only Kris opens sessions: no schedule, webhook or message starts one. The diagram's source is [`agent-host-session.archify.json`](agent-host-session.archify.json).

## Kill switch

Do both steps; either one alone stops access.

1. Stop the host, which ends every session on it. With `assume knowledge-islands-techne-agent-host`:

   ```sh
   bash operations/aws/agent-host/stop.sh             # --now skips the status read
   ```

   It stops only a running instance tagged `ki-agent-host-id = agent-host`, `ki-lifecycle = prototype` and `Name = ki-techne-agent-host`. First it reads [Status](#status) with a 5-second connect timeout and prints a warning naming each repository at risk or unknown, or saying the status could not be read. It never refuses: a stop keeps the disk, so the work is still there when the host starts again. In an emergency, `--now` stops without waiting for the read.

2. In the Tailscale admin console, remove the `ki-techne-agent-host` device and revoke any unused auth key for its tag.

## Before a rebuild

Before rebuilding the host or deploying a changed stack template, prove that the template still describes the running host. With `assume knowledge-islands-techne`, run `bun run self:aws:validate`, then create a change set for the first binding's values without executing it:

```sh
aws cloudformation deploy --profile knowledge-islands-techne --region eu-west-1 \
  --stack-name ki-techne-agent-host --template-file infra/aws/agent-host-stack.yaml \
  --capabilities CAPABILITY_IAM --no-execute-changeset \
  --parameter-overrides AgentHostId=agent-host HostName=ki-techne-agent-host \
    TailscaleHostname=ki-techne-agent-host TailscaleTag=tag:ki-techne-agent-host \
    ParameterPrefix=/ki/techne/agent-host InstanceType=t3.medium VolumeSize=40 \
  --tags ki-agent-host-id=agent-host ki-lifecycle=prototype ki-work-item=KI-ARCADIA-GOV-020
```

Expect `No changes to deploy`. If a change set is created instead, read it with `aws cloudformation describe-change-set` and delete it unexecuted with `aws cloudformation delete-change-set`; any listed resource change is a defect to fix before the rebuild.

## Rebuild and withdraw

The recipe's destroy path has two operations, both run with `assume knowledge-islands-techne` and both requiring `CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host`:

```sh
CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host bash operations/aws/agent-host/destroy.sh rebuild
CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host bash operations/aws/agent-host/destroy.sh withdraw
```

- **Rebuild** deletes the `ki-techne-agent-host` stack only, keeping the `github-token` and `model-api-key` parameters for the next build, then prints the rebuild sequence: remove the old `ki-techne-agent-host` device in the Tailscale admin console so the new host takes its name, store a fresh Tailscale auth key as [Before the build](#before-the-build) describes, overwriting any spent one, then run `provision.sh` and `setup.sh`. Run [Before a rebuild](#before-a-rebuild) first when the template has changed.
- **Withdraw** deletes the stack and the three parameters under `/ki/techne/agent-host/`, then lists what remains to remove by hand: the tailnet device, its tag, tag owner, grant and `ssh` rule and any unused auth key; the GitHub token and any model API key issued for the host; the `ki-techne-agent-host-operator` role, its inline policy and the `knowledge-islands-techne-agent-host` profile; and the SSH and Zed entries in the chezmoi source, applied only after reviewing `chezmoi diff`.

A bare `destroy.sh` is refused. Both operations refuse a stack that is not tagged `ki-agent-host-id = agent-host`, and both may be rerun after a partial clean-up: a stack that is already gone is skipped, and missing parameters do not block withdrawal.

### The guard

Before deleting anything, both operations read [Status](#status) as JSON with a 10-second connect timeout, and proceed only as follows:

| Outcome | What happens |
| --- | --- |
| Clean | Proceeds. Either override is refused. |
| At risk | Refuses, listing the repositories at risk and the recovery routes, unless `--discard <repository>...` names exactly those repositories. |
| Unknown, or the status cannot be read | Refuses, listing the reasons and the recovery routes, unless `--discard-unreadable-host` is given; then it asks you to type `discard ki-techne-agent-host`. |

A report counts as read only when it parses, carries the `techne/host-workspace/v1` schema and its outcome matches its exit status. The report's `host.id` must also match the stack's `AgentHostInstanceId` output, so a status read from another host cannot clear this one; only `--discard-unreadable-host`, which has no report to check, skips that check and says so.

The recovery routes, in order:

1. **Push.** On the host, push each repository's unlanded branches.
2. **Bundle.** On the host, run `git bundle create ~/<repository>.bundle --all` and `git bundle verify ~/<repository>.bundle` in each repository, copy the bundles to the operator's machine with `scp` over Tailscale SSH, and verify them again there.

There is no EBS snapshot route.

### When the work matters

1. Start the host if it is stopped, with `techne-agent-host connect --aws` or the operator profile.
2. Run `status.sh --fetch` and read what is at risk or unknown.
3. Land the work: push it, or bundle it to the operator's machine and verify the bundle.
4. Run `status.sh` again until it reports clean, then rebuild or withdraw without an override.

### In an emergency

1. Stop the host with `stop.sh --now`, as the [Kill switch](#kill-switch) describes.
2. Remove the `ki-techne-agent-host` device in the Tailscale admin console.
3. Rebuild or withdraw with `--discard-unreadable-host`, typing the confirmation. The host cannot be reached once its device is gone, so whatever was on it is lost.

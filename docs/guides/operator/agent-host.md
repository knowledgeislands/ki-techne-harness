# Build and operate the agent host

This runbook is for Kris, as the operator who builds, connects to, stops and tears down the prototype agent host that `KI-ARCADIA-GOV-020` authorises. The host is a separate EC2 instance, `ki-techne-agent-host`, in account `655383751458`, region `eu-west-1`. It sits beside the retained controller `ki-techne-ops-007-primary` and shares nothing with it: its own stack, network, security group, instance role and instance profile.

The host runs under the one standing exemption that the [Techne Programme Hold](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Hold.md) carries, recorded in `GDR-KI-ARCADIA-004` and set through `KI-ARCADIA-GOV-023` within the bounds `KI-ARCADIA-GOV-020` accepted. The exemption has no automatic lapse: it stands until Kris changes or withdraws it. It covers this one host and nothing else. Agents prepare and review this path; only Kris runs it.

## At a glance

![The agent host: Kris's Mac, the tailnet and the host in the Techne account, with its operator role, instance role and Parameter Store](agent-host-architecture.svg)

On the Mac, `techne host connect` from [`tools-techne`](https://github.com/knowledgeislands/tools-techne) checks the host and opens Zed's `ssh://` remote; Zed reaches the host through the Tailscale client over WireGuard, and the tailnet policy admits only `techne` over Tailscale SSH. The host sits in its own security group with no inbound rule and talks out only over HTTPS, to GitHub with a fine-grained token and to the model provider through Kris's Claude account login. Its instance role reads only the parameters under `/ki/techne/agent-host/`.

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
| `host_name` | `ki-techne-{name}` | `AGENT_HOST_NAME` | `provision.sh`, `stop.sh` |
| `tailscale_name` | `ki-techne-{name}` | `AGENT_HOST_TAILSCALE_NAME` | `setup.sh`, `status.sh`, `provision.sh`, `stop.sh`, `destroy.sh` |
| `tailscale_tag` | `tag:ki-techne-{name}` | `AGENT_HOST_TAILSCALE_TAG` | `provision.sh` |
| `repositories` | `operations/aws/agent-host/host/repositories.txt` | `AGENT_HOST_REPOSITORIES` | `setup.sh`, `status.sh`, `stop.sh`, `destroy.sh` |
| `workspace` | `~/workspaces/kit` | `KI_AGENT_HOST_WORKSPACE` | `setup.sh`, `status.sh`, `stop.sh`, `destroy.sh` |
| `reboot_window` | optional | `AGENT_HOST_REBOOT_WINDOW` | `provision.sh` |
| `livepatch` | optional | `AGENT_HOST_LIVEPATCH` | `provision.sh` |
| `profile` | optional | `AGENT_HOST_PROFILE` | `setup.sh` |
| `shell` | `zsh` | `AGENT_HOST_SHELL` | `setup.sh` |
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

`setup.sh` and `status.sh` read no AWS variable: they reach the host by its Tailscale name over SSH, and pass the workspace to the host scripts, which expand a leading `~/` to the operator's home there. `stop.sh` and `destroy.sh` read the Tailscale name, repository list and workspace only to pass them to `status.sh`, which reads the host's status before they act. `provision.sh` passes the host name, Tailscale name and tag, tag value and parameter prefix to the stack's `HostName`, `TailscaleHostname`, `TailscaleTag`, `AgentHostId` and `ParameterPrefix` parameters, and tags the stack with the tag value. `profile` and `shell` reach `setup.sh` alone, as [Profile payload](#profile-payload) and [Shell](#shell) describe.

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

One rerunnable command from the Mac converges `techne`'s workspace on the host. Run it after every build, and again whenever the repository set, a pin in [`recipes/direct-host/rig.toml`](../../../recipes/direct-host/rig.toml) or the binding owner's profile changes:

```sh
bash operations/aws/agent-host/setup.sh --pull # --pull fast-forwards clean checkouts
```

Pass `--pull` on every rerun. Without it, a checkout behind origin keeps stale skill projections, and `ki repo --estate repair` can then fail; `converge.sh` reports that failure with a reminder to rerun with `--pull`.

It uses SSH to the binding's Tailscale name only, `ki-techne-agent-host` unless `AGENT_HOST_TAILSCALE_NAME` is set. It validates the profile payload `AGENT_HOST_PROFILE` names, when one is set, and sends nothing if it is refused; then it copies the host scripts, the recipe's files and the payload over one connection and runs `host/converge.sh` there. That script converges:

- the Git identity from the Mac's global configuration and the house pull, branch and push settings;
- the repositories in [`host/repositories.txt`](../../../operations/aws/agent-host/host/repositories.txt), in the Mac's `~/workspaces/kit/<organisation>/<repository>` layout. It clones a missing repository, leaves a checkout with uncommitted changes alone and, with `--pull`, only fast-forwards a clean one;
- mise and its global pins for Bun, Node and the Codex CLI, exact versions read from the recipe's pin file, then each repository's own mise tools and Bun dependencies, leaving each repository's `mise.toml` alone;
- one shell environment file, `~/.config/ki-agent-host/env.sh`, sourced from `.profile`, `.bashrc`, Husky's `init.sh` and, for zsh, `.zshenv`, so tools are on `PATH` in non-interactive SSH and Git hooks too, and the hand-off to the chosen shell that [Shell](#shell) describes;
- the `ki` CLI at its pinned version, `ki bootstrap` for Claude Code and Codex, the local `ki-agentic-harness` checkout, the registry and the repositories' skill projections;
- Rig at its pinned tag, with the pin file as `~/.config/rig/rig.toml` and the observe-only `direct-host-pins` provider: Rig reports drift and installs nothing yet;
- `autoMemoryEnabled` set to `false` in `~/.claude/settings.json`;
- the recipe's own host instructions, `recipes/direct-host/host-instructions.md`, as `~/.claude/rules/ki-agent-host.md` for Claude Code and as the first part of `~/.codex/AGENTS.md` for Codex: push where you worked, be level before working on the other machine, and leave roadmap writes to the workstation checkout;
- the host marker, `~/.config/ki/host-marker`, which `ki` will honour by refusing roadmap writes once [KI-TOOL-CLI-115](https://github.com/knowledgeislands/tools-ki/blob/main/docs/roadmap/KI-TOOL-CLI-115-refuse-host-roadmap-writes.md) lands;
- the login banner, `~/.config/ki-agent-host/banner.sh`, which an interactive shell shows once.
- the binding owner's profile payload, when one is sent, as [Profile payload](#profile-payload) describes.

It never copies credentials or MCP configuration, and writes nothing to `~/.claude` but the recipe's rules, its settings key and the payload's files. It backs up any file it replaces under `~/.local/state/ki-agent-host/backups/`. A run that finds nothing to do ends with `no changes`; a failed step makes it exit non-zero. On the host, `bash host/converge.sh` from the harness checkout does the same and keeps the last applied payload's files; only a run from the workstation can change them.

Two steps remain Kris's. Sign Claude Code in as [Claude Code](#claude-code) describes. Sign Codex in by running `codex login` as `techne` on the host, which prints a sign-in URL to approve on the Mac.

### Profile payload

The binding owner's workstation layer reaches the host as one rendered directory, a `techne/host-profile/v1` payload (TECHNE-TOOLS-OPS-015). Kris's chezmoi source renders it with Cheztoi (DOTFILES-UE-073): one `chezmoi archive` call over exactly the targets the host's manifest names, with `--override-data` setting the values the host variants branch on.

```sh
~/.local/share/chezmoi/scripts/cheztoi-render --host vega --validator operations/aws/agent-host/host/profile-check.py
AGENT_HOST_PROFILE=~/.cache/cheztoi/vega bash operations/aws/agent-host/setup.sh
```

The payload holds `manifest.json` and, under `home/`, each file it lists at its path in the operator's home with its mode. The manifest names its `revision`, its `target_os` and, optionally, its `target_host`: the host name `status` reports, such as `ki-techne-agent-host`, which `converge.sh` compares with the host's before writing anything, so a payload rendered for one host is never applied to another. Leave `target_host` out until the host has the name the payload is for. An optional `rig` object names one Rig fragment under `~/.config/rig/conf.d/` and the profile it declares; the fragment may declare tools, categories and that profile only, through Rig's built-in providers.

`host/profile-check.py` validates the payload on the workstation before anything is sent, and again on the host before anything is written. It refuses a path outside the home, a symbolic link, an unlisted file, a destination the recipe manages (such as `~/.bashrc`, the chosen shell's start-up file, `~/.config/mise/`, `~/.claude/settings.json`, `~/.ssh/` or the workspace), a secret, content invalid on the target OS (such as `/opt/homebrew` on Linux, or an unguarded `pbcopy`) and a fragment that reaches a custom provider, a managed resource or an identity of the recipe's own Rig configuration. A refusal sends or changes nothing.

On the host, `converge.sh` writes each file with its mode, removes a file the source dropped only when the last applied payload installed it, and records the applied manifest at `~/.local/state/ki-agent-host/profile-manifest.json`. `~/.codex/AGENTS.md` is composed: the recipe's rules first, then the owner's file under its own heading. Files the retired `chezmoi cat` path rendered into `~/.claude`, which carry its "Rendered for ... from the Mac's chezmoi source" header, are backed up and removed unless the payload delivers them. With a fragment, `rig apply --profile <profile> --scope tools` then installs the owner's personal tools and reports them changed, unchanged or failed. A run without a payload keeps the last applied payload's files and installs no owner tool; the host has the recipe layer alone until a payload is first sent.

To recover a lost or rebuilt host's profile, re-render the payload on the workstation and rerun setup with it; nothing on the host is its only copy.

### Shell

`AGENT_HOST_SHELL`, `zsh` by default or `bash`, names the shell interactive sessions use. With zsh, `.zshenv` sources the environment file, and an interactive bash session hands off to `zsh -l` from a guarded block at the top of `.bashrc`. The hand-off never happens for a command, whether `bash -c` or an SSH command, or in a session that has already handed off. Interactive bash and zsh both get mise's hook.

Two escape hatches keep bash when a personal start-up file breaks the login: set `KI_AGENT_HOST_NO_HANDOFF=1` for one session, such as `ssh -t ki-techne-agent-host env KI_AGENT_HOST_NO_HANDOFF=1 bash -l`, or create `~/.config/ki-agent-host/no-handoff` on the host to keep bash until it is removed. Choosing `bash` removes the hand-off and the `.zshenv` block and keeps the rest of `.zshenv`. When the chosen shell is not installed, `converge.sh` warns and makes no hand-off; the provider installs it (TECHNE-TOOLS-OPS-017).

### Status

Before you stop, rebuild or withdraw the host, and whenever you want to know what is at risk, run the read-only report from the Mac:

```sh
bash operations/aws/agent-host/status.sh             # add --fetch to refresh the remote-tracking branches first
```

Work on the host is safe only once it is in Git on a remote, on any branch (`ODR-KI-ARCADIA-001`). The report covers the repositories the binding declares, `host/repositories.txt` by default. A repository is **at risk** when it has uncommitted or untracked files, commits on any local branch that no remote branch contains, or stashes; files Git ignores do not count, and a linked worktree's uncommitted files count towards its repository. Everything else on the host is disposable by rule: Claude Code and Codex sign-ins and transcripts, caches, hand-made backups and any checkout outside the declared set. Land anything you want to keep from those by hand.

For each repository the report lists the branch, uncommitted files, unpushed commits, stashes and the ahead and behind counts as of the last fetch, and flags it `AT RISK` or `UNKNOWN`. The inventory fails closed: a missing workspace, a declared repository that is absent, a repository outside the declared set or a Git read that fails makes the outcome **unknown** rather than clean, and the report lists why. It then lists each pinned tool's state from `rig status --profile direct-host`, flagging `DRIFT`, and the GitHub token's and the Tailscale node key's expiries, flagging `EXPIRES SOON` within 14 days, and ends with a summary line such as `summary: REPOSITORIES=3 AT_RISK=1 UNKNOWN=0 OUTCOME=at-risk`. Last, it compares the Mac's own tools with the same pins, as a signal that never changes the exit status. The text report records the expiry dates, the drifted tools and the time of the check in `~/.cache/ki-agent-host/expiry` on the host; the login banner reads only that file and the clock, and shows one line for an expiry within 14 days, for drift, and for a check older than 7 days or none. Run the text report at least weekly. The report changes nothing else; `--fetch` runs `git fetch --all --prune` in each repository, which updates only remote-tracking branches, and a failed fetch makes that repository unknown.

When a profile payload has been applied, the report also lists its revision and, for its Rig fragment, each personal tool's state from `rig status --profile <profile>`, flagging `DRIFT`; the `--json` document carries them in its optional `profile` member as `revision`, `rig_profile` and `drift`. Like updates, they never change the outcome or exit status, and the login banner names drifted personal tools on their own line.

The exit status carries the outcome: 0 clean, 3 at risk, 4 unknown, 1 when the report itself fails, and SSH's own 255 when the host cannot be reached. `--json` prints one `techne/host-workspace/v1` document instead of the table, naming the host by its hostname and `host.id`, the provider-defined identity of the machine: the cloud-init instance ID on AWS, and a hardware or install UUID on owned hardware, and `--connect-timeout <seconds>` bounds the wait for an unreachable host. `stop.sh` and `destroy.sh` read this document; the `techne` CLI reads it through the `[status]` table of the recipe manifest.

### Expiries and pins

The GitHub token expires 90 days after it is created and the Tailscale node key on its own schedule; the status report and the login banner warn within 14 days, so rotate the token as in [GitHub](#github) when either shows it. The banner knows only what the last text report found, which is why it also says when that report is more than 7 days old.

To bump a pin, change its locator in `recipes/direct-host/rig.toml` for each OS by an ordinary commit, then rerun setup; `converge.sh` installs the new version and status shows the host level again. `ki` moves to its current release this way. Claude Code updates itself, so its pin is a minimum. Rig only observes the pins for now; `rig apply` comes later, under TECHNE-TOOLS-OPS-018.

## Patching and restart

The recipe declares one patching model in its `[patching]` table, and each provider supplies the mechanism in its own patching table (TECHNE-TOOLS-OPS-022):

1. **Security updates install themselves.** Unattended upgrades install security updates only, daily; other updates wait for a rebuild or a deliberate upgrade.
2. **Kernel fixes go live through Livepatch where the binding opts in.** With `livepatch = true`, the host attaches Ubuntu Pro at build and enables Livepatch, which applies critical kernel fixes without a restart. It narrows the need for a restart; it does not remove it.
3. **The host restarts only at a window the binding chooses.** With no `reboot_window`, the default, the host never restarts itself: status and the login banner say when a restart is needed, and you restart it. With a window, a daily `HH:MM` in the host's time zone, such as `04:00`, the host restarts at that time only when a restart is required and nobody is logged in.

Updates never change the status outcome or exit status; they are a signal, like expiries and pins.

### On AWS

The boot script writes `/etc/apt/apt.conf.d/20auto-upgrades` and `52ki-agent-host-unattended-upgrades`, which allow the `-security`, ESM apps and ESM infra security origins only and always set `Automatic-Reboot "false"`. With a window, it also installs `/usr/local/sbin/ki-agent-host-reboot` and a daily `ki-agent-host-reboot.timer`; the guard restarts only when `/var/run/reboot-required` exists and `who` lists nobody. `who` does not see a detached `tmux` session, so land work before the window if an agent is running unattended.

`provision.sh` passes the binding's window and Livepatch choice to the stack's `RebootWindow` and `Livepatch` parameters, and refuses a window not in `HH:MM` form. For Livepatch, first store your Ubuntu Pro token as a SecureString, then build:

```sh
aws ssm put-parameter --profile knowledge-islands-techne --region eu-west-1 \
  --name /ki/techne/agent-host/ubuntu-pro-token --type SecureString --value file:///dev/stdin
```

Type the token, then Ctrl-D. `provision.sh` refuses Livepatch when the parameter is missing. The boot script reads it through the instance role into a file under `/run`, attaches with `pro attach --attach-config` and removes the file, so the token never reaches a command line or the disk. Rebuild keeps the parameter; withdraw deletes it, and you detach the machine in the Ubuntu Pro dashboard. The boot script runs only at first boot, so a window or Livepatch reaches a host only at its next build.

### Owned hosts

An owned Linux host (TECHNE-TOOLS-OPS-021) meets the same contract through its distribution's unattended-update service and systemd: security-only origins, and the same daily reboot timer and guard only when a window is set, enabled at enrolment by its owner as root. On macOS, the owner enables automatic security responses and system files at enrolment; there is no automatic restart by default. FileVault holds a restarted Mac at the unlock screen unless the restart is authenticated with `fdesetup authrestart`, which needs the owner's credentials, so a Mac restarts only when its owner is there or has prepared that.

### Reading updates

The text report gains an Updates section: operating system, pending updates, security updates flagged `SECURITY`, whether a restart is required and since when, flagged `REBOOT REQUIRED` with the packages that need it, and the Livepatch state. `--json` adds an `updates` member to the `techne/host-workspace/v1` document:

```json
"updates": {"os": "ubuntu", "pending": 34, "security": 12, "reboot_required": false,
  "reboot_required_since": null, "reboot_packages": null, "livepatch": "disabled"}
```

`null` means unknown. `livepatch` is the Livepatch client's state, such as `applied`, else `enabled` or `disabled` from Ubuntu Pro, or `unsupported` where neither exists. macOS reports pending and security updates from the last scan's catalogue, and `reboot_required` as `null` because it has no such flag.

The login banner reads `/var/run/reboot-required` itself, so a required restart shows at the next login with its age and packages. It also warns when security updates have been pending for more than a day, which suggests unattended upgrades are failing; that line comes from the last text report.

### Restart route

To restart the host by hand, as the banner asks:

1. Run [Status](#status) and land anything at risk; a restart ends every running session.
2. With `assume knowledge-islands-techne-agent-host`, stop the host with `bash operations/aws/agent-host/stop.sh`, then start it with `techne host start`.
3. Reconnect over Tailscale and run status again; the reboot line should be gone.

The EBS volume persists the workspace, so the restart loses only running sessions. Stop and start rather than a reboot from the host: `techne` has no `sudo`.

The current host keeps its build's settings: unattended security updates are on, automatic restart is off and there is no Livepatch. It gains the report and banner at your next `setup`, and a window or Livepatch only at its next build.

## A working session

![One working session: Kris connects through the helper and Zed over Tailscale, runs Claude Code on the host, and pushes only on request through the credential helper](agent-host-session.svg)

Kris runs `techne host connect [path]`, after `techne host start` when the host is stopped. It checks that Tailscale is up and the host answers, then opens Zed's `ssh://` remote; it makes no AWS call. Zed connects as `techne` over the tailnet, uploads its server binary from the Mac, and Kris opens a repository and a terminal.

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

1. Start the host if it is stopped, with `techne host start` or the operator profile.
2. Run `status.sh --fetch` and read what is at risk or unknown.
3. Land the work: push it, or bundle it to the operator's machine and verify the bundle.
4. Run `status.sh` again until it reports clean, then rebuild or withdraw without an override.

### In an emergency

1. Stop the host with `stop.sh --now`, as the [Kill switch](#kill-switch) describes.
2. Remove the `ki-techne-agent-host` device in the Tailscale admin console.
3. Rebuild or withdraw with `--discard-unreadable-host`, typing the confirmation. The host cannot be reached once its device is gone, so whatever was on it is lost.

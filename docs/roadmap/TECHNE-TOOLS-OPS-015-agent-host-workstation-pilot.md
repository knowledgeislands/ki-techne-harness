---
id: TECHNE-TOOLS-OPS-015
area: OPS
title: Agent-host workstation pilot
kind: deliver
purpose: capability
project: agent-host
component: operations
horizon: now
status: awaiting-review
blocks: [TECHNE-TOOLS-OPS-017]
blocked_by: []
baseline_ref: 977abc90f86814c39d57e2b5489be8bd8494d67c
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-09T18:25:06Z
---

# Agent-Host Workstation Pilot

## Goal

A session on the agent host works like the binding owner's own workstation for a first, minimal slice: the recipe applies the owner's profile payload when one is supplied, the owner's personal tools install through Rig with one tool first, interactive sessions run the binding's chosen shell (zsh by default) with the host environment, and both Claude and Codex follow instructions that match what the host can do.

## Context

This is the harness half of the agent-host workstation pilot, paired for the current binding with DOTFILES-UE-073, Kris's Cheztoi record in a chezmoi source, which supplies the payload this record applies. The record names no person: any binding owner's payload uses the same hook, on any target the recipe supports, Linux or macOS. [ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the workstation model; Kris Brown approved it on 2026-10-08, accepting all seven recommended decisions, and on the same day approved the generic-review proposals P6 and P9, which make the shell a per-binding choice with zsh as the recipe default and the payload hook the only route for personal instructions.

- **Payload contract.** The harness applies "the binding owner's profile payload if one is supplied", naming no person. The payload carries a revision, file ownership and permissions, removal of files dropped from the allowlist, and validation of rendered contents for secrets, paths invalid on the target OS and managed resources, refusing a Rig fragment that declares any. Delivery is pull-on-demand through `techne host setup`. The hook is the only route for personal instructions: `setup.sh`'s `chezmoi cat` rendering of `AGENT_HOST_INSTRUCTIONS` is removed, not generalised beside it.
- **Personal tools through Rig.** Stage 1 (TECHNE-TOOLS-OPS-014) installed Rig at a pinned tag; `rig apply` installs the owner's profile from the delivered `conf.d` fragment, one tool first. For the current binding that is `mgit`, which works by discovery only on the host, because its workspace manifests are not delivered.
- **Shell (decision 4, P6).** The interactive shell is a per-binding choice: the binding's optional `shell` field names it and the recipe's default is zsh. The recipe installs the chosen shell, keeps `env.sh` sourceable from any shell, and adds a guarded hand-off from `.bashrc` to the chosen shell as a login shell, whose startup files source `env.sh`; when the chosen shell is bash, no hand-off is made. Login, interactive, non-interactive SSH and Git-hook shells, and mise environments, are each tested. The provider's own login-shell change waits for the next rebuild (TECHNE-TOOLS-OPS-017).
- **Instructions.** The Claude and Codex instruction files come from the payload; the delegation instructions are the host variant without detached agents (decision 5).
- **No new binaries but Rig (decision 6).** Neither `techne` nor any personal-configuration tool is installed on the host.

## Boundary

- In scope: the person-neutral payload hook in `setup.sh` and `converge.sh` with the contract above; `rig apply` for the owner's delivered fragment; the binding's shell with the zsh default, the guarded hand-off and its shell-path tests; personal-tool drift in `status.sh`; operator guide corrections - recovery of profile and runtime state by re-running setup from the operator's workstation, and removal of references to the retired `techne-agent-host` helper.
- Out of scope: the Cheztoi allowlist and renderer (DOTFILES-UE-073); the recipe's Rig profile and drift check (TECHNE-TOOLS-OPS-014, done); the `ki` provider (TECHNE-TOOLS-OPS-016) and moving `converge.sh`'s installs to Rig (TECHNE-TOOLS-OPS-018); the provider's login-shell change (TECHNE-TOOLS-OPS-017); the remaining person-specific defaults and the binding fields themselves (TECHNE-TOOLS-OPS-019); a `--profile` option or binding field in `techne host setup` and personal-tool drift in `techne host status` in `tools-techne`; any credential, unattended process or writing-checkout marker; and any remote action, which is the binding owner's alone.

## Current state

Planned on 2026-10-08 under Decision 20 of the Techne run; Kris approved the plan on 2026-10-09 (Decision 28). TECHNE-TOOLS-OPS-013 and TECHNE-TOOLS-OPS-014 are done: the host runs Rig 0.4.0, which observes the recipe's `agent-host` profile through the `agent-host-pins` provider, and the recipe writes its own rules to `~/.claude/rules/ki-agent-host.md` and `~/.codex/AGENTS.md` and the marker to `~/.config/ki/host-marker`.

`setup.sh` still requires `chezmoi` and renders the `AGENT_HOST_INSTRUCTIONS` files (`CLAUDE.md`, `communication.md`, `delegation.md`, `memory-scope.md`, `markdown.md`) into the payload's `claude/` directory with `chezmoi cat`; `converge.sh` copies them to `~/.claude/` and never removes one. The delivered `delegation.md` points at detached agents, which the exemption does not allow on the host. No other personal file and no personal tool reaches the host.

The stack creates `techne` with `/bin/bash` and installs `zsh` through its boot script, and `techne` has no `sudo`, so the recipe can check for a shell but cannot install one. `converge.sh` writes `env.sh`, sourced from `.profile`, `.bashrc` and husky's `init.sh`, and activates mise only for interactive bash. Rig 0.4.0's built-in kinds include `direct-download` `executable` with an HTTPS locator, a `~/` destination and a `sha256:` checksum, which needs no Homebrew and no `sudo` on Linux or macOS. `techne host setup` runs `setup.sh` with the operator's environment, so an environment parameter reaches the script without a `tools-techne` change.

## Plan

### Payload contract, version 1

The payload is a directory the binding owner's source renders on the operator's workstation. `setup.sh` takes its path from `AGENT_HOST_PROFILE`, declared as a recipe parameter with no default; unset means no payload, and the host gets the recipe layer alone. The binding field `profile` that later replaces the environment variable belongs to TECHNE-TOOLS-OPS-019 and its paired `tools-techne` record.

- `manifest.json` with `schema` `techne/host-profile/v1`, `revision` (an opaque string the source chooses, such as its commit and a content hash), `target_os` (`linux` or `macos`), an optional `target_host`, `files`, `removed` and an optional `rig` object.
- `files` lists each delivered file by `path`, relative to the operator's home with no `..`, absolute or empty component, and `mode` (`0600`, `0644`, `0700` or `0755`). Each file sits under `home/` in the payload at that path. The harness owns ownership: every file is written as the operator user.
- `removed` lists paths the source dropped from its allowlist. The harness removes a path only when its own record of the previous payload shows it installed that path.
- `rig.fragment` names one file under `home/.config/rig/conf.d/` and `rig.profile` the profile it declares. The fragment may declare tools, categories and its profile only, through built-in providers; it may not declare a provider table, a custom adapter, a managed resource, a `[rig]` table, or any identity the recipe's `rig.toml` declares.
- Reserved destinations, refused in any payload: `~/.config/rig/rig.toml`, `~/.config/mise/`, `~/.config/ki-agent-host/`, `~/.config/ki/host-marker`, `~/.claude/rules/ki-agent-host.md`, `~/.claude/settings.json`, `~/.claude/skills/`, `~/.agents/`, `~/.local/share/rig/providers/`, `~/.ssh/`, `~/.gitconfig`, `~/.profile`, `~/.bashrc`, the chosen shell's recipe-managed startup file and the workspace root.
- `~/.codex/AGENTS.md` is a composed destination: Codex reads one global instructions file, so the harness writes the recipe's rules first and the payload's file after them under a heading, rather than letting either replace the other.
- Validation refuses a symbolic link, a file the manifest does not list, a listed file that is absent, a path or content invalid on `target_os` (for Linux, `/Users/`, `/opt/homebrew`, `/usr/local/Cellar`, `brew shellenv`, `pbcopy` or `pbpaste` outside a guard; for macOS, `/home/`), and content matching the secret patterns the repository's checks already use. `setup.sh` validates on the operator's workstation before anything is sent; `converge.sh` repeats the structural checks on the host before writing.
- `target_host`, when present, names the host the payload was rendered for. `converge.sh` compares it with the host's operating-system host name, the `host.hostname` that `status.sh` reports (such as `ki-techne-agent-host`), before writing anything, and refuses the payload on a mismatch, so a bundle rendered for one host is never applied to another. It does not use `host.id`, the provider identity, which on AWS is the instance ID and changes at every rebuild. When it is absent, no host check is made. Kris accepted this field on 2026-10-09 (Decision 26(a) of the Techne run) and chose the host name over `host.id` on 2026-10-09 (Decision 28). A host built before the boot script set its name still reports the AWS default, such as `ip-10-90-0-40`, so a payload for it either omits `target_host` or names that reported value until the rebuild.
- `converge.sh` keeps the applied manifest at `~/.local/state/ki-agent-host/profile-manifest.json`; `status.sh` reports its revision.

### Migration from the `chezmoi cat` path

The five files the old path wrote carry its "Rendered for ... from the Mac's chezmoi source" header. On the first run of the new `converge.sh`, a `~/.claude/*.md` file with that header that the payload does not deliver is removed, and one the payload delivers is replaced. A run without a payload therefore leaves a recipe-only host rather than stale personal instructions.

### Shell

`AGENT_HOST_SHELL`, declared as a recipe parameter with default `zsh`, names the chosen shell; `bash` and `zsh` are supported in the pilot. For zsh, `converge.sh` writes a managed block at the top of `~/.zshenv` that sources `env.sh`, and `env.sh` activates mise for interactive zsh as it does for bash. For any shell other than bash it adds a managed block to `.bashrc`, after the `env.sh` block and above Ubuntu's interactive-only return, that runs `exec "$shell" -l` only when the session is interactive, `SSH_ORIGINAL_COMMAND` is empty, the shell is executable, `KI_AGENT_HOST_NO_HANDOFF` is unset and `~/.config/ki-agent-host/no-handoff` is absent, and the hand-off has not already happened in this session. The two escape hatches give the operator a bash session if a personal zsh file breaks the login. When the chosen shell is missing, `converge.sh` warns, makes no hand-off and leaves installation to the provider (TECHNE-TOOLS-OPS-017).

### Personal tools

After the payload is written, `converge.sh` runs `rig apply --profile <rig.profile>` and reports the result as changed, unchanged or failed. `status.sh` adds `rig status --profile <rig.profile>` to its drift line and JSON `problems` when a payload with a fragment has been applied. No owner tool is installed when no payload is supplied.

## Steps

- [x] Add the `profile` and `shell` parameters to `recipe.toml` and teach `tooling/checks/recipe-manifest.py` an optional parameter with no default, so `check_binding_defaults` stays green for the live binding.
- [x] Add the payload validator as one script beside `setup.sh`, run by `setup.sh` on the operator's workstation and by `converge.sh` on the host, implementing the contract above.
- [x] Change `setup.sh`: drop `AGENT_HOST_INSTRUCTIONS`, `chezmoi cat` and the `chezmoi` requirement; stage a validated payload when `AGENT_HOST_PROFILE` is set; pass the shell choice to `converge.sh`.
- [x] Change `converge.sh`: apply the payload's files with their modes, remove only previously installed paths the source dropped, migrate the old `chezmoi cat` files, compose `~/.codex/AGENTS.md`, record the applied manifest, and run `rig apply` for the payload's profile.
- [x] Add the shell: the `~/.zshenv` block, mise activation for interactive zsh, the guarded `.bashrc` hand-off with its two escape hatches, and the missing-shell warning.
- [x] Change `status.sh`: report the applied payload revision and personal-tool drift.
- [x] Add offline checks with stubs and fixtures: a valid payload, each refusal (a `target_host` that does not match the host name, reserved destination, `..` path, symbolic link, unlisted file, secret, a macOS path in a Linux payload, a fragment with a custom provider or managed resource or a recipe identity), removal of a dropped file but not of an unrecorded one, the migration, Codex composition with and without a payload, a run with no payload, and the shell paths - login, interactive, non-interactive SSH command, Git hook through husky's `init.sh` and a mise environment - for zsh and for bash, plus both escape hatches.
- [x] Update the operator guide: rendering and passing a payload (`AGENT_HOST_PROFILE` and `target_host`, with Cheztoi's chezmoi-native render - one `chezmoi archive` call with `--override-data` from a per-host manifest - as the example), choosing the shell, the escape hatches, recovery of profile and runtime state by re-running setup, and removal of the retired `techne-agent-host` helper's references.
- [x] Render DOTFILES-UE-073's payload on the Mac and run this repository's validator against it offline; record the result here.
- [x] Live verification, only under a separate grant from Kris for SSH to the exempt host: the binding owner runs setup with the payload and `status`, and opens a new SSH session.

## Files touched

- `operations/aws/agent-host/setup.sh`, `operations/aws/agent-host/host/converge.sh`, `operations/aws/agent-host/host/status.sh` and a new payload validator beside them
- `recipes/agent-host/recipe.toml`
- `tooling/checks/recipe-manifest.py`, `tooling/checks/agent-host-workspace.sh` or a new check script, and fixtures under `tooling/checks/fixtures/`
- `docs/guides/operator/agent-host.md`
- This record

## Verify

- `bun run test` and the repository's checks pass, including every new payload and shell case above.
- `ki repo audit --repo .` reports no new failure or warning against the 2026-10-08 baseline (`FAIL=0 WARN=2`).
- Offline: DOTFILES-UE-073's rendered payload passes this repository's validator, and a copy with a planted macOS path, secret or custom provider, or with a `target_host` that does not match the stubbed host name, is refused.
- On the host, after the binding owner runs setup with the payload: `mgit` is installed through Rig at `~/.local/bin/mgit`, a new SSH session lands in zsh with the host environment and the owner's prompt, `ssh <host> 'echo $0; command -v mise ki mgit'` runs non-interactively in bash with the pinned tools, `~/.claude/delegation.md` is the host variant, `~/.codex/AGENTS.md` starts with the recipe's rules, and `status` reports the payload revision and no personal-tool drift.

## Dependencies / blocks

No longer blocked: TECHNE-TOOLS-OPS-014, which installed Rig, and the durability pilot, TECHNE-TOOLS-OPS-013, were both accepted on 2026-10-08. Paired for the current binding with DOTFILES-UE-073 in Kris's chezmoi source: this record defines the payload contract and DOTFILES-UE-073 renders to it, so delivery starts here and the two finish together at the offline check and live run; neither blocks the other's start. Blocks TECHNE-TOOLS-OPS-017. Takes over TECHNE-TOOLS-OPS-019's removal of `AGENT_HOST_INSTRUCTIONS`, `chezmoi cat` and the `chezmoi` requirement, so that removal and the hook land together; TECHNE-TOOLS-OPS-019 keeps the binding fields and the other person-specific defaults.

## Delegation

One session delivers both records in order, harness first; the work is too interlocked for parallel lanes.

## Documentation impact

### Decision Records

None in this repository: ADR-KI-ARCADIA-003 in `ki-arcadia-principal` records the model.

### Specifications

The payload contract is a new contract between the harness and the binding owner's source, carried by this record's Plan and the operator guide; no separate specification until a second source uses it.

### Guides

`docs/guides/operator/agent-host.md`, as listed in Steps.

### Roadmap

The pilot's lessons are written into TECHNE-TOOLS-OPS-016 and TECHNE-TOOLS-OPS-018 before they start, and TECHNE-TOOLS-OPS-019's boundary loses the `chezmoi cat` removal this record takes over.

## Review

### Delivered

- `setup.sh` takes a `techne/host-profile/v1` payload from `AGENT_HOST_PROFILE`, validates it with `host/profile-check.py` before anything is sent, and no longer needs `chezmoi` or `AGENT_HOST_INSTRUCTIONS`. `AGENT_HOST_SHELL` (default `zsh`) is passed to `converge.sh`.
- `converge.sh` validates the payload again on the host, refuses one whose `target_host` names another host, writes the files with their modes, removes only files the last payload installed, migrates the old `chezmoi cat` files, composes `~/.codex/AGENTS.md` with the recipe's rules first, records the applied manifest and runs `rig apply` for the payload's profile.
- The chosen shell gets a `~/.zshenv` block, mise activation for interactive zsh and a guarded `.bashrc` hand-off with its two escape hatches; a missing shell gives a warning and no hand-off.
- `status.sh` reports the applied payload revision and the owner's personal-tool drift in an optional `profile` member.
- The operator guide covers rendering and passing a payload, `target_host`, the shell choice, the escape hatches and recovery by re-running setup, and no longer names the retired `techne-agent-host` helper.
- The pilot's Rig lessons are recorded in TECHNE-TOOLS-OPS-016 and TECHNE-TOOLS-OPS-018.

### Change Summary

The plan is followed as written. One correction came from the live run: `rig apply` counts a tool it only re-verifies as completed, so `converge.sh` reported the personal tools as changed on every run. It now reads `rig status --profile <profile> --format json` before the apply and reports a change only when a tool was not already present.

### Verification

- `bun run test` passes, including the recipe-manifest and agent-host workspace checks for every payload, refusal, removal, migration, Codex composition and shell case in Steps.
- `ki repo audit --repo .` reports `FAIL=1 WARN=2`: the two warnings are the 2026-10-08 baseline, and the one failure is TECHNE-TOOLS-OPS-022's open live Step (ITEM-3), already present at `977abc9` and outside this record.
- Offline on 2026-10-09: DOTFILES-UE-073's rendered payload at `~/.cache/cheztoi/vega/` (revision `b3fb600...+d35b258...`, Linux, fourteen files, Rig profile `cheztoi`) passes `profile-check.py --os linux --hostname ki-techne-agent-host --shell zsh` with the recipe's `rig.toml`. Copies with a planted `/opt/homebrew` path, an AWS access key, a `[providers]` table in the fragment, or `target_host` `vega` against the host name `ki-techne-agent-host` are each refused with the matching problem.
- Live on 2026-10-09 under Decision 29(c), from the Mac checkout with the payload: `setup.sh` ended `CHANGES=0 FAILURES=0` on a host the earlier run had already converged; `status.sh --json` reports `outcome` `clean`, the payload revision, Rig profile `cheztoi` and no personal-tool drift. `mgit` is at `~/.local/bin/mgit`; an interactive SSH session lands in `/usr/bin/zsh` with the owner's prompt; `ssh ki-techne-agent-host 'echo $0; command -v mise ki mgit'` runs in bash and finds all three; `~/.claude/delegation.md` is the host variant; `~/.codex/AGENTS.md` starts with the recipe's rules and then the owner's under their heading; the `no-handoff` file kept an interactive session in bash and was removed afterwards.

### Outstanding concerns

- The payload carries no `target_host` until the host is renamed `vega`; the host check is proven offline only.
- The provider still creates `techne` with `/bin/bash`; the login-shell change waits for TECHNE-TOOLS-OPS-017.
- The environment-variable escape hatch did not travel over SSH as `SetEnv` in the live test; the guide's form, `ssh -t ki-techne-agent-host env KI_AGENT_HOST_NO_HANDOFF=1 bash -l`, is the route.
- The validator allows any Rig built-in provider in the owner's fragment, `chezmoi` among them, and does not refuse a fragment that declares a personal-configuration tool such as `chezmoi` itself; decision 6 is kept by the owner's allowlist, not yet enforced by the harness.

### Post-change review

The full diff from `977abc9` was reread against the plan and the boundary. It touches only the listed files and the two roadmap records the Roadmap impact names, installs neither `techne` nor a personal-configuration tool, puts no secret on a command line or in Git, uses `sudo` nowhere, and renames neither the recipe nor the binding. The payload is validated on the workstation before anything is sent and again on the host before anything is written.

### Mini recap

Commits `9e1de9c` and `854e12f` deliver the hook, shell and status changes and the change-reporting fix; this record's commit records the result.

## Discussion

### Sequencing

Selected as the workstation pilot on 2026-10-08 under Kris's grant. It starts after the durability pilot, TECHNE-TOOLS-OPS-013, and stage 1 in TECHNE-TOOLS-OPS-014, both done. It is planned and delivered together with DOTFILES-UE-073; the wider allowlist waits for its lessons. On 2026-10-09 Kris accepted the [workstation bundle walkthrough](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Streams/Projects/agent-host/design/workstation-bundle-walkthrough.md)'s recommendation (Decision 26(a)): the payload contract stays renderer-neutral, gains the optional `target_host`, and DOTFILES-UE-073 renders it chezmoi-natively. Kris approved this plan on 2026-10-09 and moved it to `ready` (Decision 28), with `target_host` checked against the host name.

### Profile argument

Settled at planning: `techne host setup` needs no profile argument for the pilot, because it passes the operator's environment to `setup.sh` and `AGENT_HOST_PROFILE` carries the payload path. A `profile` binding field and a `tools-techne` option come with TECHNE-TOOLS-OPS-019's paired binding-schema record, not here.

### Decisions

- The payload path and shell travel as `AGENT_HOST_PROFILE` and `AGENT_HOST_SHELL` until the binding fields exist.
- `~/.codex/AGENTS.md` is composed, recipe rules first, because Codex reads one global file.
- Removal acts only on files the harness recorded installing, plus the one-time migration of the old `chezmoi cat` files.
- The payload may name its `target_host`, which `converge.sh` checks against the host name (`host.hostname` in `techne host status --json`) and refuses on a mismatch; absent, no check is made (accepted on 2026-10-09, Decision 26(a); host name rather than `host.id` chosen on 2026-10-09, Decision 28). The host name survives a rebuild, unlike the AWS instance ID, so a host manifest need not change when the host is rebuilt.
- The hand-off has two escape hatches, an environment variable and a file, so a broken personal zsh file cannot shut the operator out of an interactive session.

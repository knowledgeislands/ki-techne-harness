---
id: TECHNE-TOOLS-OPS-017
area: OPS
title: Binding shell at rebuild
kind: deliver
purpose: debt
project: agent-host
component: infra
status: ready
horizon: next
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-015]
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-11T01:26:00Z
---

# Binding Shell at Rebuild

## Goal

The agent host's `techne` user has the binding's chosen shell (zsh by default) as its login shell from the provider itself, so the guarded `.bashrc` hand-off can be retired. The same rebuild renames the host to `vega` and removes the record identifiers that remain in the host's live artefacts.

## Context

[ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 4, as generalised on 2026-10-08 (generic-review proposal P6, approved by Kris with zsh as the default), makes the interactive shell a per-binding choice: the binding's optional `shell` field names it and the recipe's default is zsh. The workstation pilot (TECHNE-TOOLS-OPS-015) delivers it now through a guarded hand-off from `.bashrc`; where the provider sets the login shell, it sets the binding's shell at the next rebuild that happens for another reason.

On the AWS provider the stack creates `techne` with `/bin/bash`, hard-coded, and the user cannot `chsh`. A rebuild costs a fresh Tailscale key and removal of the old device, so no rebuild is made for this change alone.

On 2026-10-09 Kris named the AWS agent host `vega` under his machine-naming convention: physical machines take solar-system names, peripherals are moons, and a non-physical host takes its own star system (Decision 29(a) in the Techne thread's decisions log). Setting the OS hostname needs root, which the `techne` user lacks, and a new Tailscale name means a new device, so the rename lands at the same rebuild. Until then the bundle carries no `target_host` (TECHNE-TOOLS-OPS-015).

Record identifiers also sit in live artefacts that outlast their records, and records are pruned. `converge.sh` writes and searches for a start-up marker that names TECHNE-TOOLS-OPS-011 in `.profile`, `.bashrc` and the Husky start-up file. The instance's boot script names TECHNE-TOOLS-OPS-022 in comments, in an apt configuration file it writes and in the reboot unit's description. The stack's `ki-work-item` tags and its description, `provision.sh`, the recipe's provider tags and the operator guide name KI-ARCADIA-GOV-020, and the guide also names KI-ARCADIA-GOV-023. Tags and the description change only through a stack update and the boot script only on a new instance, so their removal waits for this rebuild.

## Boundary

- In scope: the AWS stack's boot script creating the `techne` user with the binding's shell (default zsh) rather than a hard-coded one, passed through the provider's parameters; retiring the hand-off guard once a rebuilt host runs the binding's shell as its login shell; and the shell-path tests carried over from the pilot.
- In scope: renaming the host to `vega` everywhere the name lives — the OS hostname, the Tailscale device name, the operator's SSH alias and its known_hosts file, the AWS `Name` tag, the binding's host name, and the personal bundle's manifest with its `target_host`. Parts owned by another repository, such as the binding and SSH configuration in chezmoi, go there as handoffs.
- In scope: removing those identifiers from the agent-host stack (resource tags, description, boot script and reboot unit), `provision.sh`, the recipe, `converge.sh`'s start-up marker, the offline checks and the operator guide. The new marker names no record. `converge.sh` still recognises the old marker, and the hand-made `mise shims` block, by pattern rather than by the record's name, so on a host converged before the rebuild it replaces the old block instead of adding a second; the rebuilt host only ever carries the new marker.
- Out of scope: triggering a rebuild, which the binding owner runs; the binding field itself (TECHNE-TOOLS-OPS-019); a login-shell change for any other provider.

## Current state

- The stack's boot script creates the operator user with `useradd --create-home --shell /bin/bash` (`infra/aws/agent-host-stack.yaml`); it already installs zsh. The shell choice reaches only `setup.sh` (`AGENT_HOST_SHELL`, recipe parameter `shell`, scripts `["setup"]`), not `provision.sh` or the stack.
- `converge.sh` writes the `.bashrc` hand-off that `exec`s the chosen shell for interactive sessions, guarded by `KI_AGENT_HOST_NO_HANDOFF` and `~/.config/ki-agent-host/no-handoff`, and warns when the chosen shell is missing. The offline checks in `tooling/checks/agent-host-workspace.sh` cover the hand-off's shell paths.
- `converge.sh` marks its managed block `# >>> ki-agent-host (TECHNE-TOOLS-OPS-011) >>>` and the hand-off `# >>> ki-agent-host hand-off (TECHNE-TOOLS-OPS-015) >>>`; `strip_managed` matches both, and the hand-made `# ki-agent-host: mise shims (TECHNE-TOOLS-OPS-011)` block, by exact text. The `.zshenv` back-to-bash branch tests the start marker by exact text too.
- Every stack resource and the stack itself carry `ki-work-item: KI-ARCADIA-GOV-020`, from the template, from `provision.sh --tags` and from `[providers.aws.tags]` in `recipes/agent-host/recipe.toml`; `tooling/checks/agent-host-stack.rb` and `tooling/checks/agent-host-aws-scripts.sh` assert the value. The stack description names KI-ARCADIA-GOV-020; the boot script names TECHNE-TOOLS-OPS-022 three times, once inside the apt configuration it writes and once in the reboot timer's `Description`.
- The operator guide names KI-ARCADIA-GOV-020 and KI-ARCADIA-GOV-023 for the exemption and the operator policy, TECHNE-TOOLS-OPS-017 for the shell install, and uses `ki-techne-agent-host` as the host, device and SSH name throughout its examples.
- Host names come from recipe defaults (`ki-techne-{name}`) unless the binding sets `AGENT_HOST_NAME` and `AGENT_HOST_TAILSCALE_NAME`; the stack name, host identifier and parameter prefix stay keyed on the binding name `agent-host`.

## Steps

- [ ] Pass the shell to the stack: add a `Shell` template parameter (allowed `bash` or `zsh`, default `zsh`), have the boot script create the operator user with `--shell "$(command -v <shell>)"`, add `provision` to the `shell` parameter's scripts in the recipe, and pass `Shell=` from `provision.sh`.
- [ ] Retire the hand-off: `converge.sh` stops writing the hand-off block and removes any existing one through `strip_managed`; it checks the login shell (`getent passwd`) against the choice and warns, without failing, when they differ, naming the rebuild as the fix. Remove the hand-off outright, with no dormant fallback for other providers, and the escape-hatch handling that only it needed; keep the `.zshenv` block.
- [ ] Rename the markers: the managed block becomes `# >>> ki-agent-host >>>`. `strip_managed` and the `.zshenv` test recognise any start line matching `# >>> ki-agent-host( (.*))? >>>` and any `# ki-agent-host: mise shims( (.*))?` line, so old markers on a host converged before the rebuild are replaced, not duplicated, and no record is named in the code.
- [ ] Remove the remaining identifiers: replace the `ki-work-item` tag with `ki-authority: GDR-KI-ARCADIA-004` across the template, `provision.sh` and `[providers.aws.tags]`, and update the guide's `provision.sh` example to match; reword the stack description, the boot-script comments, the apt configuration comment and the reboot unit's `Description` without record identifiers; reword the guide's exemption and operator-policy sentences around `GDR-KI-ARCADIA-004` and the Arcadia policy link. Remove every other record identifier from the agent-host code, recipe, checks and guide, including TECHNE-TOOLS-OPS-015, TECHNE-TOOLS-OPS-017, TECHNE-TOOLS-OPS-018, TECHNE-TOOLS-OPS-019 and other repositories' identifiers in comments.
- [ ] Rename the examples: the guide and diagrams use `vega` for this host's OS, device and SSH names; recipe defaults stay person-neutral (`ki-techne-{name}`).
- [ ] Update the offline checks: the shell parameter reaches the stack and the boot script; converge writes no hand-off and removes an old one; a fixture `.bashrc`, `.profile` and Husky file carrying the old marker converge to one new block; the tag and description checks follow step 4; add a check that the agent-host template, scripts and recipe contain no `[A-Z]+-[A-Z]+-[0-9]{3}` record identifier outside `ADR-`, `ODR-` and `GDR-` decision records.
- [ ] Hand off to chezmoi (the binding owner's dotfiles source) in plain terms, non-blocking for this repository: set the binding's `AGENT_HOST_NAME` and `AGENT_HOST_TAILSCALE_NAME` to `vega`, set the payload manifest's `target_host` to `vega`, rename the SSH alias and drop the old `known_hosts` entry once the rebuilt host is up.

## Files touched

- `infra/aws/agent-host-stack.yaml`
- `operations/aws/agent-host/provision.sh`, `operations/aws/agent-host/host/converge.sh`, and record-identifier comments in `setup.sh`, `status.sh` and `host/profile-check.py`
- `recipes/agent-host/recipe.toml`, `recipes/agent-host/rig.toml` (comment)
- `tooling/checks/agent-host-workspace.sh`, `tooling/checks/agent-host-aws-scripts.sh`, `tooling/checks/agent-host-stack.rb`, `tooling/checks/recipe-manifest.py` (comment)
- `docs/guides/operator/agent-host.md`, and the diagram sources and renders beside it where they show the host name

## Verify

- `bun run test` passes, with Python 3.11 or later on `PATH` for the `tomllib` checks, and `ki repo audit` reports no failure.
- `grep -rnE '\b(TECHNE|KI)-[A-Z]+-[A-Z]+-[0-9]{3}\b|TECHNE-OPS-[0-9]{3}' infra/aws/agent-host-stack.yaml operations/aws/agent-host recipes/agent-host tooling/checks docs/guides` finds nothing.
- `bun run self:aws:validate` accepts the template offline. No change set, deployment or host change is made by this work.
- At the last commit before this work lands, the guide's before-a-rebuild check has run against the current template; the rebuild then uses the new template.
- After the binding owner rebuilds (outside this record): `ssh vega 'getent passwd techne'` shows the chosen shell, a new session lands in it without the hand-off, `.bashrc` carries one `# >>> ki-agent-host >>>` block and no hand-off, and `status.sh` reports no drift.

## Dependencies / blocks

`blocked_by` keeps TECHNE-TOOLS-OPS-015 to match that record's `blocks`; the blocker is discharged because the pilot's hand-off and checks have landed. Defining the binding's `shell` field generically is TECHNE-TOOLS-OPS-019's and does not block this, because the recipe parameter already exists. The rebuild itself is the binding owner's, outside this record and under the remote-environment hold; delivery here is repository-only. chezmoi (Kris's dotfiles source) owns the binding values and SSH configuration for the `vega` rename; that handoff does not block this repository's work.

## Documentation impact

### Decision Records

None in this repository. ADR-KI-ARCADIA-003 in `ki-arcadia-principal` already makes the shell a per-binding choice, and GDR-KI-ARCADIA-004 there records the exemption the guide cites.

### Specifications

None: the recipe manifest's `shell` parameter gains a script, which `recipes/agent-host/recipe.toml` and its checks carry.

### Guides

`docs/guides/operator/agent-host.md`: the Shell section loses the hand-off and escape hatches and gains the login-shell check; the exemption and operator-policy sentences cite the decision record and policy only; examples use `vega`; Before a rebuild says the first rebuild after this change expects the tag, description and boot-script changes in its change set rather than `No changes`.

### Roadmap

[TECHNE-TOOLS-OPS-023](TECHNE-TOOLS-OPS-023-controller-target-stack-tags.md) captures the controller and target stacks' `ki-work-item` tags, which stay out of this record's scope.

## Discussion

Adopted into Next on 2026-10-10 under the owner's decision to adopt and plan it now. The rebuild itself still happens only when the binding owner runs it.

Kris settled the five decisions on 2026-10-11 (Decision 37 in the Techne thread's decisions log) and approved the plan on those terms for Ready. The plan above matches them.

1. **The `ki-work-item` tag.** Resolved: replace it with `ki-authority = GDR-KI-ARCADIA-004`, the durable decision record the exemption lives in, so cost and inventory views keep a governance link.
2. **Hand-off retirement.** Resolved: remove the hand-off outright once the provider sets the login shell, with converge warning when the login shell differs from the choice. No dormant fallback is kept.
3. **Breadth of the identifier sweep.** Resolved: remove every record identifier from the agent-host code, recipe, checks and guide and enforce it with a check. The controller and target stacks' `ki-work-item` tags are captured separately as [TECHNE-TOOLS-OPS-023](TECHNE-TOOLS-OPS-023-controller-target-stack-tags.md).
4. **Name examples.** Resolved: the guide uses `vega` for this host; recipe defaults stay person-neutral.
5. **Before-a-rebuild check.** Resolved: run the guide's check at the last commit before this work lands, expecting `No changes`, then rebuild from the new template.

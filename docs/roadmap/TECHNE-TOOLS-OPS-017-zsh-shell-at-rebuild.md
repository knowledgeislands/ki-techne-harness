---
id: TECHNE-TOOLS-OPS-017
area: OPS
title: Binding shell at rebuild
kind: deliver
purpose: debt
project: agent-host
component: infra
status: awaiting-review
horizon: now
blocks: []
blocked_by: [TECHNE-TOOLS-OPS-015]
baseline_ref: 7f1b70807950e3e6c0cd7270356d8a8b6b2592ed
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-11T03:10:44Z
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

- [x] Pass the shell to the stack: add a `Shell` template parameter (allowed `bash` or `zsh`, default `zsh`), have the boot script create the operator user with `--shell "$(command -v <shell>)"`, add `provision` to the `shell` parameter's scripts in the recipe, and pass `Shell=` from `provision.sh`.
- [x] Retire the hand-off: `converge.sh` stops writing the hand-off block and removes any existing one through `strip_managed`; it checks the login shell (`getent passwd`) against the choice and warns, without failing, when they differ, naming the rebuild as the fix. Remove the hand-off outright, with no dormant fallback for other providers, and the escape-hatch handling that only it needed; keep the `.zshenv` block.
- [x] Rename the markers: the managed block becomes `# >>> ki-agent-host >>>`. `strip_managed` and the `.zshenv` test recognise any start line matching `# >>> ki-agent-host( (.*))? >>>` and any `# ki-agent-host: mise shims( (.*))?` line, so old markers on a host converged before the rebuild are replaced, not duplicated, and no record is named in the code.
- [x] Remove the remaining identifiers: replace the `ki-work-item` tag with `ki-authority: GDR-KI-ARCADIA-004` across the template, `provision.sh` and `[providers.aws.tags]`, and update the guide's `provision.sh` example to match; reword the stack description, the boot-script comments, the apt configuration comment and the reboot unit's `Description` without record identifiers; reword the guide's exemption and operator-policy sentences around `GDR-KI-ARCADIA-004` and the Arcadia policy link. Remove every other record identifier from the agent-host code, recipe, checks and guide, including TECHNE-TOOLS-OPS-015, TECHNE-TOOLS-OPS-017, TECHNE-TOOLS-OPS-018, TECHNE-TOOLS-OPS-019 and other repositories' identifiers in comments.
- [x] Rename the examples: the guide and diagrams use `vega` for this host's OS, device and SSH names; recipe defaults stay person-neutral (`ki-techne-{name}`).
- [x] Update the offline checks: the shell parameter reaches the stack and the boot script; converge writes no hand-off and removes an old one; a fixture `.bashrc`, `.profile` and Husky file carrying the old marker converge to one new block; the tag and description checks follow step 4; add a check that the agent-host template, scripts and recipe contain no `[A-Z]+-[A-Z]+-[0-9]{3}` record identifier outside `ADR-`, `ODR-` and `GDR-` decision records.
- [x] Hand off to chezmoi (the binding owner's dotfiles source) in plain terms, non-blocking for this repository: set the binding's `AGENT_HOST_NAME` and `AGENT_HOST_TAILSCALE_NAME` to `vega`, set the payload manifest's `target_host` to `vega`, rename the SSH alias and drop the old `known_hosts` entry once the rebuilt host is up. Delivered as a plain-terms handoff in this record's review and the run report; this run's authority covered this repository only, so nothing was written to chezmoi.

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

## Review

### Delivered

The approved boundary, in code, tests and guide only, from baseline `7f1b70807950e3e6c0cd7270356d8a8b6b2592ed` to commit `508793e`: the stack sets the operator user's login shell from the binding's choice, `converge.sh` retires the `.bashrc` hand-off and warns when the login shell differs, the markers and every work-record identifier leave the agent-host stack, scripts, recipe, checks and guide, and the guide uses `vega` for this host and calls the recipe the AWS base for a remote agentic rig (Decision 40(2a) in the Techne thread's decisions log). Excluded, as planned: the rebuild itself, any AWS, Tailscale or host change, and the chezmoi values.

### Change Summary

- `infra/aws/agent-host-stack.yaml`: new `Shell` parameter (`bash` or `zsh`, default `zsh`); the boot script runs `useradd --shell "$(command -v <shell>)"`; `ki-work-item: KI-ARCADIA-GOV-020` becomes `ki-authority: GDR-KI-ARCADIA-004` on every resource; the description, patching comment, apt configuration comment and reboot timer `Description` name no record.
- `operations/aws/agent-host/provision.sh`: reads `AGENT_HOST_SHELL` (refusing anything but `bash` or `zsh`), passes `Shell=`, tags the stack `ki-authority=GDR-KI-ARCADIA-004`. `recipes/agent-host/recipe.toml`: `shell` reaches `provision` too, and the provider tag follows.
- `operations/aws/agent-host/host/converge.sh`: the managed marker is `# >>> ki-agent-host >>>`; `strip_managed` drops any `# >>> ki-agent-host( label)? >>>` block, which includes the old hand-off, and any `# ki-agent-host: mise shims( label)?` block; the `.zshenv` test matches by the same pattern; no hand-off or escape hatch is written; a `getent passwd` check warns without failing when the login shell differs from the choice, or cannot be read.
- Identifier comments removed from `setup.sh`, `status.sh`, `host/status.sh`, `host/profile-check.py`, `rig.toml` and `recipe-manifest.py`.
- Checks: `agent-host-stack.rb` asserts the `Shell` parameter, both rendered `useradd` lines and an identifier-free description; `agent-host-aws-scripts.sh` asserts `Shell=` passes through, a second binding's `bash`, a refused `fish`, and the new tag; `agent-host-workspace.sh` stubs `getent`, seeds `.profile`, `.bashrc` and Husky's `init.sh` with the old managed marker, the old hand-off and the hand-made block, and asserts one new block, no old markers, no hand-off, and the login-shell warnings; the hand-off shell-path and missing-shell checks are gone with the feature. New `tooling/checks/agent-host-record-ids.sh`, run from `controller.sh`, fails on any work-record identifier in the agent-host template, scripts and recipe outside `ADR-`, `ODR-` and `GDR-` records.
- Guide `docs/guides/operator/agent-host.md` and the two Archify diagrams with their SVG renders: `vega` for the host, device, SSH, OS and `Name` tag; the tailnet tag, stack name, destroy confirmation and operator role keep their recipe names. The exemption sentence cites `GDR-KI-ARCADIA-004` only; the Shell section describes the provider-set login shell and the warning; Before a rebuild names the first rebuild after this change as the one expected exception.
- Deviation: the workspace fixture assembles the old marker's record name from parts, so the check script holds no identifier while still exercising a real old marker.

### Verification

- `bun run test` with mise's Python 3.12.13 first on `PATH`: passed (2 of 2 tasks; root layout, controller unit tests, agent-host stack, workspace, AWS script, record identifier and recipe manifest checks).
- Mutation check: restoring exact-text marker matching and changing the warning text in `converge.sh` made the workspace check fail on both; restored before commit.
- Plan's identifier `grep` over the agent-host stack, `operations/aws/agent-host`, `recipes/agent-host`, `tooling/checks` and `docs/guides`: no match.
- `ki repo audit`: PASS=16, WARN=2, FAIL=0. Both warnings predate this work (`ki-engineering` CI-1 on the inline `KI_VERSION` pin; `ki-repo` HOOK-1 on `.githooks/pre-commit`).
- Not run: `bun run self:aws:validate` and the guide's Before a rebuild change set both call AWS, which this run's authority excludes. One attempt at `self:aws:validate` at the baseline failed locally on an expired SSO token before reaching CloudFormation; no other remote call was made. The template's offline structural check passed instead.

### Outstanding concerns

- The before-rebuild check at the last commit before this work (`7f1b708`) has not run against AWS; Kris runs it before the rebuild, from that commit, expecting `No changes to deploy`.
- `bun run self:aws:validate` on the new template is Kris's, with `assume knowledge-islands-techne`.
- chezmoi handoff, non-blocking for this repository: set the binding's `AGENT_HOST_NAME` and `AGENT_HOST_TAILSCALE_NAME` to `vega`, set the payload manifest's `target_host` to `vega`, rename the SSH alias to `vega` and drop the old `known_hosts` entry once the rebuilt host is up.
- Until the rebuild, `converge.sh` on the current host warns that its login shell is `/bin/bash`, not `zsh`, and interactive sessions stay in bash because the hand-off is gone. Rerunning setup before the rebuild therefore loses the zsh hand-off on the current host.

### Post-change review

The goal holds in the repository: the provider now owns the login shell, and nothing in the agent-host artefacts names a work record, with a check keeping it so. Scope held to the planned files plus the new check script and its `controller.sh` line, which the plan's check step implies. The main regression risk is the interim period above: a setup rerun on the current host before the rebuild drops the hand-off. Tests cover the marker migration on a fixture carrying every old marker. Ready for review; acceptance should wait for, or explicitly defer, the post-rebuild checks in Verify.

### Mini recap

Delivered the shell-at-build change, hand-off retirement, marker and identifier sweep with an enforcing check, and the `vega` guide examples in one commit; offline tests and the repository audit pass. Open: the AWS before-rebuild check and validation, the rebuild, and the chezmoi values, all Kris's. Learning route: the run shows that the guide's Before a rebuild step needs AWS, so a run without AWS authority cannot discharge it; a future plan should name it as the owner's step.

## Discussion

Adopted into Next on 2026-10-10 under the owner's decision to adopt and plan it now. The rebuild itself still happens only when the binding owner runs it.

Kris settled the five decisions on 2026-10-11 (Decision 37 in the Techne thread's decisions log) and approved the plan on those terms for Ready. The plan above matches them.

1. **The `ki-work-item` tag.** Resolved: replace it with `ki-authority = GDR-KI-ARCADIA-004`, the durable decision record the exemption lives in, so cost and inventory views keep a governance link.
2. **Hand-off retirement.** Resolved: remove the hand-off outright once the provider sets the login shell, with converge warning when the login shell differs from the choice. No dormant fallback is kept.
3. **Breadth of the identifier sweep.** Resolved: remove every record identifier from the agent-host code, recipe, checks and guide and enforce it with a check. The controller and target stacks' `ki-work-item` tags are captured separately as [TECHNE-TOOLS-OPS-023](TECHNE-TOOLS-OPS-023-controller-target-stack-tags.md).
4. **Name examples.** Resolved: the guide uses `vega` for this host; recipe defaults stay person-neutral.
5. **Before-a-rebuild check.** Resolved: run the guide's check at the last commit before this work lands, expecting `No changes`, then rebuild from the new template.

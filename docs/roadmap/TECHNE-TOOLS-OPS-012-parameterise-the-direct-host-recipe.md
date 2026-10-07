---
id: TECHNE-TOOLS-OPS-012
area: OPS
title: Parameterise direct-host recipe
kind: deliver
purpose: capability
project: agent-host
component: recipes
transferred_from: knowledgeislands/ki-arcadia-principal:KI-ARCADIA-GOV-025
status: done
blocks: []
blocked_by: []
baseline_ref: cda3304a9dc80473f41555e0b71f703b0e2daf61
created_at: 2026-10-07T12:58:15Z
updated_at: 2026-10-07T16:56:47Z
---

# Parameterise Direct-Host Recipe

## Goal

The agent host becomes the first instance of a harness-defined recipe, `direct-host`, rather than a single hard-coded host. Every value that identifies the host reaches the stack and scripts from a person's binding, so the same recipe can describe more than one agent host while today's host stays exactly as it is.

## Context

Handoff from Arcadia Principal, [KI-ARCADIA-GOV-025](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Streams/Roadmap/KI-ARCADIA-GOV-025-model-agent-hosts-as-recipes-and-bindings.md) ("Model agent hosts as recipes and bindings"), step H1, placed on Kris Brown's instruction of 2026-10-07. This repository owns its priority, plan and execution; the handoff transfers no ownership, and ADR-TECHNE-003 still decides what each repository owns.

GOV-025 decides the model. A **recipe** is a harness-defined kind of agent host; a **binding** is a person's named, configured instance of one, held outside both repositories at `~/.config/techne/hosts/<name>.toml`; a **provider** is the infrastructure a binding's footprint lives on; the **footprint** is what a binding leaves there and on the host. `direct-host` is the prototype recipe, whose agents run on the host itself, and the existing host - tag `ki-agent-host-id=agent-host`, stack `ki-techne-agent-host` - is its first binding, named `agent-host`. AWS is the first provider, not the only one, so recipes declare which providers they support and keep provider-specific detail in a per-provider section.

A binding names its provider by carrying exactly one provider table, such as `[aws]`; there is no `provider` key, and a binding with no provider table or several is invalid. Kris decided this at about 14:50 CEST on 2026-10-07. `tools-techne` reads bindings and this repository's recipe manifest, and passes binding values to these scripts through environment variables; that manifest and environment-variable contract is the only join between the two repositories.

GOV-025 read this repository at `de05a78` and found these single-host literals:

| Value today | Where it is fixed | Binding field |
| --- | --- | --- |
| Tag `ki-agent-host-id=agent-host` | stack `AgentHostId` parameter; `provision.sh` `--parameter-overrides AgentHostId=agent-host` and `--tags`; `stop.sh` and `destroy.sh` stack-tag filters | `aws.tag` |
| Host name `ki-techne-agent-host` | stack: literal `Name` tag, cloud-init `set-hostname` and `/etc/hosts`, `tailscale up --hostname`, `TailscaleHostname` output - none a parameter; `stop.sh` `Name` filter; `setup.sh` and `status.sh` `AGENT_HOST_SSH` default | `host_name`, `tailscale_name` |
| Stack `ki-techne-agent-host` | `provision.sh` and `destroy.sh` `AGENT_HOST_STACK_NAME` default and the `CONFIRM_DESTROY_AGENT_HOST` guard | `aws.stack_name` |
| Parameters `/ki/techne/agent-host/` | stack `ParameterPrefix`; literal `parameter_prefix` in `provision.sh` and `destroy.sh`; the operator policy's parameter ARNs | `aws.parameter_prefix` |
| Tailnet tag `tag:ki-techne-agent-host` | stack `TailscaleTag` | `tailscale_tag` |
| Admin profile `knowledge-islands-techne` | `provision.sh` and `destroy.sh` `AWS_PROFILE` default | `aws.admin_profile` |
| Operator profile and role `ki-techne-agent-host-operator` | `stop.sh` profile default; the role and its inline policy, created by hand | `aws.operator_profile`, `aws.operator_role` |
| Account `655383751458`, region `eu-west-1` | every script's `EXPECTED_AWS_ACCOUNT` and `AWS_REGION` default | `aws.account`, `aws.region` |
| Repository set | `operations/aws/agent-host/host/repositories.txt`; `setup.sh` `AGENT_HOST_REPOSITORIES` | `repositories` |
| Workspace `~/workspaces/kit` | `host/converge.sh` and `host/status.sh` `KI_AGENT_HOST_WORKSPACE` | `workspace` |
| Instance size `t3.medium`, 40 GiB | `provision.sh` `AGENT_HOST_INSTANCE_TYPE` and `AGENT_HOST_VOLUME_SIZE` | `aws.instance_type`, `aws.volume_size` |
| Personal instructions and Git identity | `setup.sh` renders five named `~/.claude/*.md` files with `chezmoi cat` and copies the Mac's global Git identity | person-specific; made configurable here |

Every per-host name already follows the host id: stack and host `ki-techne-<id>`, parameters `/ki/techne/<id>/`, tailnet tag `tag:ki-techne-<id>`, operator role `ki-techne-<id>-operator`. A binding named `agent-host` therefore reproduces today's footprint exactly.

## Boundary

- In scope: a `recipes/direct-host/recipe.toml` manifest; a stack parameter for the host name; environment-variable inputs in the stack scripts and host scripts for every binding value; a configurable personal instruction file list; offline checks; the operator runbook.
- Out of scope: the `techne` CLI, binding loader and provider adapter, which are `TECHNE-TOOL-CLI-005` in `tools-techne`; Kris's binding files, which are `DOTFILES-UE-070` in chezmoi; moving the existing stack template or scripts, which the manifest points at in place; a second recipe, binding or provider other than as offline test fixtures.
- No remote authority beyond [GDR-KI-ARCADIA-004](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/GDR-KI-ARCADIA-004-standing-agent-host-exemption-from-the-techne-programme-hold.md), the standing exemption for the one existing host. The only remote check is a CloudFormation change set for the first binding, run by Kris under that exemption, which must show no change. No second live binding, other provider or tailnet change.

## Current state

No `recipes/` directory exists. The stack, `operations/aws/agent-host/` scripts and runbook carry the literals in the table above; the existing host and stack are the only footprint.

## Steps

- [x] Add `recipes/direct-host/recipe.toml`: `schema = "techne/recipe/v1"`, `name`, `summary`, `runtime = "direct"`, `providers = ["aws"]`; provider-neutral `[paths]` for `setup.sh` and `status.sh` and `[parameters.<field>]` for `host_name`, `tailscale_name`, `tailscale_tag`, `repositories` and `workspace`, each stating whether it is required or derived from the binding name and the environment variable the scripts read; one `[providers.aws]` section with `[providers.aws.paths]` for `infra/aws/agent-host-stack.yaml`, `provision.sh`, `stop.sh` and `destroy.sh`, `[providers.aws.parameters.<field>]` for `tag`, `stack_name`, `parameter_prefix`, `account`, `region`, `admin_profile`, `operator_profile`, `operator_role`, `instance_type` and `volume_size`, and the resource selectors the adapter needs (tag key, derived names, operator role); the recipe-owned tags (`ki-lifecycle`, `ki-work-item`); and a `footprint` list for `aws` (stack, parameters, operator role and profile) and provider-neutral (tailnet device and tag, SSH entry) that `teardown` reports as remaining.
- [x] Turn the literal host name in `infra/aws/agent-host-stack.yaml` into a stack parameter defaulting to `ki-techne-agent-host`, used by the `Name` tag, cloud-init `set-hostname` and `/etc/hosts`, `tailscale up --hostname` and the `TailscaleHostname` output.
- [x] Read the AWS values (tag, stack, parameter prefix, profiles, account, region, instance type, volume size) from environment variables in `provision.sh`, `destroy.sh` and `stop.sh`, each defaulting to today's value, including the `stop.sh` `Name` filter and the `CONFIRM_DESTROY_AGENT_HOST` guard.
- [x] Read the provider-neutral values (host name, repositories, workspace) from environment variables in `setup.sh`, `status.sh`, `host/converge.sh` and `host/status.sh`, so those need nothing AWS-specific.
- [x] Make the personal instruction file list in `setup.sh` configurable through an environment variable, defaulting to today's five files.
- [x] Extend the offline checks: template parameter and default checks, ShellCheck of every changed script, and a manifest check that every binding field in the table above is declared exactly once, as provider-neutral or under `[providers.aws]`, and that no provider-neutral entry names an AWS concept.
- [x] Update `docs/guides/operator/agent-host.md` to describe `direct-host` as a recipe, the binding fields and the environment variables each script reads.
- [x] Hand Kris the no-change change set command for the first binding's values; record the result in Review.

## Files touched

- `recipes/direct-host/recipe.toml`
- `infra/aws/agent-host-stack.yaml`
- `operations/aws/agent-host/provision.sh`, `destroy.sh`, `stop.sh`, `setup.sh`, `status.sh`
- `operations/aws/agent-host/host/converge.sh`, `host/status.sh`
- `tooling/checks/agent-host-stack.rb`, `tooling/checks/agent-host-workspace.sh` and a manifest check beside them
- `docs/guides/operator/agent-host.md`
- This record

## Verify

- Local: `bun run test` (offline template, ShellCheck and manifest checks), `bun run self:aws:validate`, `bunx biome ci .`, `bunx rumdl check .`, `ki repo audit --repo .` and `git diff --check`.
- The manifest check passes and fails on a fixture that declares a field twice, omits one, or names an AWS concept outside `[providers.aws]`.
- `tooling/checks/agent-host-workspace.sh` runs `setup.sh` and `status.sh` with binding variables set and with no AWS variable set.
- Every script run with no binding variable set behaves as it does today: each default equals today's literal.
- Live, by Kris under GDR-KI-ARCADIA-004: a CloudFormation change set for `ki-techne-agent-host` with the first binding's values shows no change; it is then deleted unexecuted.

## Dependencies / blocks

No `blocks` or `blocked_by`. This record and `TECHNE-TOOL-CLI-005` in `tools-techne` are built in parallel against the GOV-025 schema; neither blocks the other's build. CLI-005's release reads this manifest, so it is integrated against this record's delivered manifest before it ships, and that release is applied together with Kris's binding (`DOTFILES-UE-070` in chezmoi). These are sequencing conditions, not recorded dependencies.

## Documentation impact

### Decision Records

None here. ADR-TECHNE-003 is amended in Arcadia through GOV-025 to name recipes, bindings, providers and footprints and their ownership.

### Specifications

The recipe manifest schema `techne/recipe/v1` is specified by the manifest check and the runbook section; no separate specification exists in this repository.

### Guides

`docs/guides/operator/agent-host.md` describes the `direct-host` recipe, its binding fields and its environment-variable contract.

### Roadmap

This record. Its origin is KI-ARCADIA-GOV-025, which records this identifier.

## Review

### Delivered

GOV-025's H1 within the boundary, offline only: the `direct-host` manifest, a parameterised stack, binding inputs in every stack and host script, the configurable instruction list, offline checks and the runbook. Delivery in `b37b16c` and the commit that moves this record to `awaiting-review`. No remote call was made.

### Change Summary

- `recipes/direct-host/recipe.toml`: the `techne/recipe/v1` manifest, with each field's recipe default or `required = true`, its variable and the scripts that read it, the AWS selectors, recipe-owned tags and both footprints.
- `infra/aws/agent-host-stack.yaml`: `HostName` and `TailscaleHostname` parameters, both defaulting to `ki-techne-agent-host`, used by every `Name` tag, `set-hostname`, `/etc/hosts`, `tailscale up --hostname` and the `TailscaleHostname` output. With the defaults the rendered boot script is byte-identical to before.
- `provision.sh`, `stop.sh`, `destroy.sh`: tag, host name, Tailscale name and tag, stack name and parameter prefix from variables, alongside the existing profile, region, account and size variables; the `Name` filter, the stack tag check and the `CONFIRM_DESTROY_AGENT_HOST` guard follow them.
- `setup.sh`, `status.sh`, `host/converge.sh`, `host/status.sh`: Tailscale name, host name, repositories and workspace from variables, none AWS-specific; `AGENT_HOST_INSTRUCTIONS` lists the instruction files, each checked to be a plain Markdown file name.
- `tooling/checks/recipe-manifest.py` and `.sh`: the manifest check and its refusal fixtures (twice, omitted, misplaced, AWS concept, AWS-named neutral variable, provider field read by a neutral script, `providers` list); with `tooling/checks/fixtures/agent-host.binding.toml`, each script default must equal the first binding's value.
- `tooling/checks/agent-host-aws-scripts.sh`: a stub `aws` records every call of `provision.sh`, `stop.sh` and `destroy.sh`, which must match today's calls with no variable set and carry a second binding's values with no first-binding value left.
- `tooling/checks/agent-host-stack.rb` and `agent-host-workspace.sh`: parameter defaults, no host literal left in resources or outputs, a second binding's render, and `setup.sh` and `status.sh` under a second binding with no AWS variable.
- `docs/guides/operator/agent-host.md`: a "Recipe and binding" section with the field and variable table.

### Verification

`bun run test`, `bunx biome ci .`, `bunx rumdl check .` and `git diff --check` pass. `ki repo audit --repo .` reports `PASS=17 WARN=1 FAIL=0`; its warnings are earlier records' roadmap-schema migrations. `bun run self:aws:validate` was not run: it calls CloudFormation, a remote call this delivery had no authority for.

### Outstanding concerns

- **The no-change change set was not run.** The live Verify check, a CloudFormation change set for `ki-techne-agent-host` with the first binding's values showing no change, needs the admin profile, and this delivery had no authority for a remote call. It moves to the planned host rebuild, where it is run before anything is executed:

  ```sh
  aws cloudformation deploy --profile knowledge-islands-techne --region eu-west-1 \
    --stack-name ki-techne-agent-host --template-file infra/aws/agent-host-stack.yaml \
    --capabilities CAPABILITY_IAM --no-execute-changeset \
    --parameter-overrides AgentHostId=agent-host HostName=ki-techne-agent-host \
      TailscaleHostname=ki-techne-agent-host TailscaleTag=tag:ki-techne-agent-host \
      ParameterPrefix=/ki/techne/agent-host InstanceType=t3.medium VolumeSize=40 \
    --tags ki-agent-host-id=agent-host ki-lifecycle=prototype ki-work-item=KI-ARCADIA-GOV-020
  ```

  Expected: `No changes to deploy`. If it creates a change set instead, read it with `aws cloudformation describe-change-set` and delete it unexecuted with `aws cloudformation delete-change-set`; any listed resource change is a defect in this delivery.
- **`bun run self:aws:validate` was not run** for the same reason: it calls CloudFormation. The offline template, ShellCheck, stub-`aws` and manifest checks passed.
- **Recipe manifest contract decision.** `providers = ["aws"]` beside a `[providers.aws]` table is invalid TOML, so the manifest has no `providers` list: supported providers are named only by `[providers.<name>]` tables, and the manifest check refuses the list form. `tools-techne`'s reader for CLI-005 (`src/recipes.ts`) currently expects both and must take the table keys instead.
- **`AGENT_HOST_SSH` is replaced by `AGENT_HOST_TAILSCALE_NAME`.** Anyone setting `AGENT_HOST_SSH` for `setup.sh` or `status.sh` must switch to the new variable; the default still reaches today's host.
- **No `baseline_ref` was recorded.** The delivery commit `b37b16c`'s parent is `cda3304`, the commit that placed this record.

### Post-change review

The goal is met offline: `direct-host` is a harness-defined recipe, every host-identifying value is a binding field read through one environment variable, and with no variable set each script and the stack render today's host unchanged, which the stub-`aws` checks and the byte-identical boot script show. A second binding renders with no first-binding value left. Scope held to GOV-025's H1 step; no remote call was made. Regression risk is low: defaults equal today's literals, and the one renamed variable is listed above. The live no-change proof is still owed and moves to the host rebuild. Kris's live read-only checks of `techne host list`, `techne host status`, `techne host status --host agent-host --json` and `techne controller status` passed on 2026-10-07. The review was the delivering agent's own check against the plan and gates, not an independent reviewer.

### Mini recap

OPS-012 makes the agent host the first binding of the `direct-host` recipe: a `techne/recipe/v1` manifest, a parameterised stack and binding inputs in all seven scripts, with offline checks proving today's host is unchanged and a second binding is possible. Outstanding: the no-change change set at the host rebuild, and `tools-techne` adopting the provider-table contract. Proposed learning route: the provider-table contract to `tools-techne` CLI-005 through its own record, if Kris wants it carried there.

## Done

Accepted 2026-10-07 by Kris Brown on the review packet above.

## Discussion

### Handoff origin

Placed from Arcadia Principal KI-ARCADIA-GOV-025 step H1, which records this record's identifier. Kris Brown approved capture, adoption into Now and planning on 2026-10-07, and the plan is GOV-025's H1 step and acceptance checks, so it is placed Ready. Implementation has not started.

### Script defaults

The scripts keep defaults equal to today's values so that running one by hand, with no binding, behaves as now. That is separate from the CLI, which has no built-in defaults and refuses a host command without a binding; the CLI always sets every variable from the selected binding.

### Manifest location

The manifest points at the existing `infra/aws/agent-host-stack.yaml` and `operations/aws/agent-host/` rather than moving them, so the runbook and existing script paths stay valid.

### Supported providers are the provider tables

The record's step names `providers = ["aws"]` beside a `[providers.aws]` table, but TOML forbids a key that is both an array and a table, so no manifest can carry both. Taking the most literal reading that is valid TOML, the manifest has no `providers` list: each `[providers.<provider>]` table names a supported provider, matching the binding's own provider table. The manifest check refuses the list form. The `tools-techne` reader for CLI-005 must take the supported providers from the table's keys.

### Parameter keys

Each parameter carries `required = true` or a `default`, which may be derived through `{name}`, `{<field>}` and `{<provider>.<field>}` placeholders; `env` names its one variable and `scripts` the scripts that read it. `summary` and `scripts` are additions a reader may ignore. Footprint entries are strings and selectors are string templates.

### Variables

One variable per field. Existing names are kept (`AWS_PROFILE`, `AWS_REGION`, `EXPECTED_AWS_ACCOUNT`, `AGENT_HOST_STACK_NAME`, `AGENT_HOST_INSTANCE_TYPE`, `AGENT_HOST_VOLUME_SIZE`, `AGENT_HOST_REPOSITORIES`, `KI_AGENT_HOST_WORKSPACE`); the new ones are `AGENT_HOST_ID`, `AGENT_HOST_NAME`, `AGENT_HOST_TAILSCALE_NAME`, `AGENT_HOST_TAILSCALE_TAG` and `AGENT_HOST_PARAMETER_PREFIX`. `AGENT_HOST_SSH` is replaced by `AGENT_HOST_TAILSCALE_NAME`, since the SSH target is the Tailscale name. `admin_profile` and `operator_profile` both reach `AWS_PROFILE`, in disjoint scripts. `operator_role` has no variable because only the CLI's adapter uses it. A trailing `/` on the parameter prefix is ignored.

### Two stack parameters

The record names one host-name parameter; the stack takes two, `HostName` and `TailscaleHostname`, so the binding's `host_name` and `tailscale_name` stay independent. Both default to today's name.

### Repositories, workspace and instructions

`repositories` is the path of a repository list file, defaulting to the harness's own; `workspace` is a path on the host whose leading `~/` the host scripts expand. `AGENT_HOST_INSTRUCTIONS` is person-specific rather than a binding field, so the manifest does not declare it. The Git identity is still copied from the Mac's global configuration.

### Neutral paths under operations/aws

`setup.sh` and `status.sh` stay at their existing paths under `operations/aws/agent-host/`. The manifest check exempts existing harness paths from its AWS-concept rule, because a location is not a concept.

### Acceptance - 2026-10-07

Kris Brown accepted every awaiting-review record in the Agora on 2026-10-07 ("everything that's awaiting review can be considered to be done and we can get pruned"; decision 12, state-of-play design loop). Outstanding concerns now live elsewhere: the no-change change set and `self:aws:validate` run are the operator guide's "Before a rebuild" step; `tools-techne` already reads only `[providers.<name>]` tables (`src/recipes.ts`); no consumer still sets `AGENT_HOST_SSH`.

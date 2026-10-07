---
id: TECHNE-TOOLS-OPS-009
area: OPS
title: Prepare agent-host build
theme: operations
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: f4e4ba22dbd65368f5a85216e8c0233789854dac
created_at: 2026-10-07T00:10:08Z
updated_at: 2026-10-07T00:31:22Z
---

# Prepare Agent-Host Build

## Goal

Kris can build, reach, stop and remove the prototype agent host from a reviewed, repository-owned path, without changing the retained controller in any way.

## Context

This record takes the implementation handoff from `KI-ARCADIA-GOV-020` in `ki-arcadia-principal`, which Kris accepted on 2026-10-07. That record defines a limited remote agent prototype: a new EC2 instance, `ki-techne-agent-host`, in account `655383751458`, region `eu-west-1`, beside the existing controller instance `ki-techne-ops-007-primary`. Kris reaches the host only through Tailscale SSH, from Zed or a terminal, and runs Claude Code sessions on the node's operating system. Its bounds exclude Paperclip, Kitteth, Telegram and controller workloads, and fix the tags, the Parameter Store prefix `/ki/techne/agent-host/`, the tailnet tag `tag:ki-techne-agent-host` and the egress destinations.

`KI-ARCADIA-GOV-020` resolved this repository's [TECHNE-TOOLS-OPS-008](TECHNE-TOOLS-OPS-008-provision-the-controller-as-a-supervised-agent-host.md) owner question in favour of a separate host. The controller stack, `infra/aws/controller-stack.yaml`, and its `operations/aws/controller/` scripts set the conventions reused here: CloudFormation, an account-checked provisioning script and a confirmation-gated teardown.

The Techne Programme Hold still forbids remote operations by agents. Under it, local implementation, testing and review proceed; building the host is Kris's own operation once the GOV-020 gate clears.

## Boundary

- No change to the controller stack, its template, its scripts or any controller resource; the agent host shares no network, security group, role or profile with it.
- No AWS, Tailscale or GitHub call, no plan or deploy, and no credential handling by an agent. Running the build, verifying over Tailscale, the kill switch and teardown are Kris's operations under the amended hold.
- No tailnet policy, permission set, AWS profile or chezmoi helper; those belong to Kris and the chezmoi source.
- No K3s, Paperclip, Kitteth, Telegram or execution-fabric change on the host; the `TECHNE-TOOLS-FAB-001` agent-host Kubernetes profile stays as declared.

## Current state

Before this item the repository provisioned only the retained controller and disposable execution targets. Nothing could build a separate agent host, and the operator guides had no agent-host runbook.

## Steps

- [x] Reserve `TECHNE-TOOLS-OPS-009` in the issue ledger.
- [x] Add `infra/aws/agent-host-stack.yaml`: its own VPC, subnet, route and internet gateway; a security group with no ingress and port-limited egress; an instance role that may read only `/ki/techne/agent-host/*`; an instance profile; the instance with the four GOV-020 tags; boot user data; outputs.
- [x] Add `operations/aws/agent-host/provision.sh`, `stop.sh` (kill switch) and `destroy.sh` (teardown of only the agent-host stack and its parameters).
- [x] Add the offline structural check `tooling/checks/agent-host-stack.rb` and wire it, with shellcheck of the new scripts, into `tooling/checks/controller.sh`; add the template to `operations/aws/validate-cloudformation.sh`.
- [x] Write the operator runbook `docs/guides/operator/agent-host.md` and link it from the operator guide index and `operations/README.md`.
- [x] Run the local gates.

## Files touched

- `docs/roadmap/_ISSUES.md`
- `docs/roadmap/TECHNE-TOOLS-OPS-009-prepare-the-agent-host-build.md`
- `infra/aws/agent-host-stack.yaml`
- `operations/aws/agent-host/provision.sh`, `stop.sh`, `destroy.sh`
- `operations/aws/validate-cloudformation.sh`
- `operations/README.md`
- `tooling/checks/agent-host-stack.rb`
- `tooling/checks/controller.sh`
- `docs/guides/operator/agent-host.md`
- `docs/guides/operator/README.md`

## Verify

`bun run test`, `bunx biome check .`, `bunx rumdl check .`, `ki repo audit --repo .` and `git diff --check` pass, and `tooling/checks/agent-host-stack.rb` rejects deliberately broken copies of the template.

## Dependencies / blocks

None in this repository. Running the build depends on the GOV-020 gate in `ki-arcadia-principal`: Kris's acceptance, the hold amendment and Kris's access grant.

## Documentation impact

### Decision Records

None. The authorising decision is `KI-ARCADIA-GOV-020` and the hold amendment in Arcadia; this item implements it.

### Specifications

None. The repository has no specification for AWS provisioning; the structural check holds the stack's invariants.

### Guides

Adds the operator runbook `docs/guides/operator/agent-host.md` and links it from the operator guide index.

### Roadmap

`TECHNE-TOOLS-OPS-008` can be closed or merged once Kris accepts this item, since GOV-020 answered its owner question with a separate host. That disposition is Kris's.

## Review

### Delivered

A complete local provisioning path for the agent host, within the boundary above. Baseline `f4e4ba22dbd65368f5a85216e8c0233789854dac` (the ledger reservation); the delivery is the commit that adds this record. Nothing was deployed and no remote system was contacted.

### Change Summary

- `infra/aws/agent-host-stack.yaml`: a new, self-contained stack. Material decisions:
  - **Own VPC** (`10.90.0.0/24`) rather than the controller's, so the host shares nothing with the controller and teardown removes every resource. Its public IPv4 address exists only for outbound traffic, avoiding a NAT gateway.
  - **No ingress; SSM and OpenSSH disabled.** Access is Tailscale SSH only, so the role has no session-manager policy and the boot script disables the SSM agent and the OpenSSH listener. If Tailscale fails, the recovery is the console log and rebuild.
  - **Egress:** TCP 443, TCP 80 for signed Ubuntu archives (the Tailscale installer uses apt), UDP 3478 and UDP 41641. DNS needs no rule because the VPC resolver is unfiltered.
  - **Role:** `ssm:GetParameter` and `ssm:GetParameters` on `/ki/techne/agent-host/*` only, and `kms:Decrypt` only through Parameter Store.
  - **Boot:** reads the auth key into a mode-0600 file under `/run`, joins with `tailscale up --auth-key=file:... --ssh --advertise-tags=tag:ki-techne-agent-host`, and deletes the file; the key never reaches a command argument or log. Installs Git, `tmux`, `jq`, checksum-verified Node.js `24.x`, the AWS CLI and Claude Code for the operator user.
  - **Operator OS user `techne`**, non-root and without `sudo`. The first delivery used `kris`; Kris directed the change to `techne` on 2026-10-07.
  - **GitHub credential helper:** the boot script installs `git-credential-ki-agent-host`, which answers only HTTPS `get` requests for `github.com` by reading `/ki/techne/agent-host/github-token` through the instance role, and sets it as `techne`'s helper for `https://github.com`. It writes nothing to disk.
  - **Defaults:** `t3.medium`, 40 GB encrypted `gp3`, IMDSv2 required; the controller's pinned image.
- `operations/aws/agent-host/provision.sh`, `stop.sh`, `destroy.sh`: account-checked; provisioning refuses an existing stack or a missing auth-key parameter (metadata check only); the kill switch uses the least-privilege `knowledge-islands-techne-agent-host` profile and matches all three identifying tags; teardown requires `CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host`, refuses a stack without `ki-agent-host-id = agent-host`, and deletes the three parameters after the stack.
- `tooling/checks/agent-host-stack.rb`: offline invariants — no controller reference, no ingress, exact tags on every tagged resource, the exact egress set, the role scope, IMDSv2, encryption, the single security group, every `Fn::Sub` reference resolving to a parameter, the Tailscale join line, and `bash -n` plus shellcheck of the rendered user data.
- `tooling/checks/controller.sh`, `operations/aws/validate-cloudformation.sh`, `operations/README.md`, `docs/guides/operator/README.md`, `docs/guides/operator/agent-host.md`: wiring and the runbook.
- Follow-up on 2026-10-07: the operator user became `techne`; `tooling/checks/agent-host-stack.rb` now pins that default, rejects `sudo` or extra groups for the user, and runs the extracted credential helper against a stub `aws`; the runbook gained a paste-ready tailnet policy, the auth-key settings, and the Claude Code and GitHub credential steps.

No deviation from the GOV-020 bounds. Points where a bound needed an implementation choice are listed under Outstanding concerns for Kris.

### Verification

All local and offline; nothing contacted AWS, Tailscale or GitHub.

- `bun run test` (dependency layout, controller unit tests, manifest and template parsing, `tooling/checks/agent-host-stack.rb`, shellcheck including `operations/aws/agent-host/*.sh`): pass.
- `bunx biome check .`: pass, no issues.
- `bunx rumdl check .`: pass, no issues.
- `ki repo audit --repo .`: PASS, 18 skills.
- `git diff --check`: clean.
- Negative checks of `tooling/checks/agent-host-stack.rb` against altered copies: a braced shell variable in the user data, a changed `ki-lifecycle` tag, an added ingress list and an unquoted shell expansion were each rejected.
- Follow-up on 2026-10-07, for the `techne` user and the credential helper: `bun run test`, `bunx biome check .`, `bunx rumdl check .`, `ki repo audit --repo .` and `git diff --check` pass. Altered copies of the template were each rejected: operator default `kris`, the user added to `sudo`, a helper that answers any host, and a helper that reads `model-api-key`. The tailnet policy snippet is unvalidated against a live tailnet; the runbook names the points to check.
- Not run, because they contact AWS: `bun run self:aws:validate`, `provision.sh`, `stop.sh`, `destroy.sh`.

### Outstanding concerns

- **Not built or tested remotely.** The template has had no `validate-template`, the image has not been confirmed as Ubuntu with `snap`, and the boot script has not run. The Ruby structural check uses Ruby 2.6 locally. The first build is the first live test.
- **Egress a security group cannot express:** TCP 443 and 80 reach any address, DNS through the VPC resolver resolves any name, and direct peer UDP to a NAT-translated port falls back to DERP. The runbook states these limits.
- **Choices for Kris to confirm:** instance size and cost (`t3.medium`, 40 GB), the operator user `kris` without `sudo`, the TCP 80 egress rule, disabling session-manager access, and Node.js tracking the latest `24.x` at build time rather than an exact pin.
- **Tailnet policy location:** no repository records the tag owner, grant and `ssh` rule. This is a GOV-020 open question for Kris.
- **Follow-on:** `TECHNE-TOOLS-OPS-008` disposition, as noted under Roadmap.

### Post-change review

The goal is met locally: the path to build, reach, stop and remove the host exists, is reviewed and is documented, and the controller's files are untouched. Scope held. Regression risk to existing work is low: the only shared files are the check script and the validation script, which gain lines; the controller template and scripts are unchanged and their checks still pass. Acceptance readiness depends on Kris confirming the choices above; the remote build is Kris's operation after the gate, not part of this item.

### Mini recap

Added a separate CloudFormation stack, three operations scripts, an offline structural check and an operator runbook for the GOV-020 agent host, with local gates passing and nothing run remotely. Proposed learning routes: the component-naming principle and the security-group limits on name-based egress could inform a Techne Engineering Practice note in Arcadia; a DNS firewall or egress proxy is a candidate future item if the prototype continues.

## Done

Accepted 2026-10-07 by Kris Brown on the review packet above, with express authority given at 02:25 CEST. Kris confirmed the build choices listed under Outstanding concerns: `t3.medium` with 40 GB, the outbound TCP 80 rule, no session-manager access and Node.js tracking the latest `24.x`. The exception was the operator user, which Kris changed from `kris` to `techne`, still without `sudo`; that change, the credential helper, the tailnet policy and the credentials decision landed before acceptance and are recorded above. The tailnet policy now has a paste-ready form in the runbook, which answers the policy-location concern by keeping the admin console as its only record. Kris also delegated the `TECHNE-TOOLS-OPS-008` disposition. The remote build remains Kris's operation under `KI-ARCADIA-GOV-020`.

## Discussion

### Credentials decision - 2026-10-07

Decided by Claude under Kris's delegation, 2026-10-07. Claude Code on the host signs in interactively as Kris, by the device or browser flow over SSH, so no model API key is stored and `/ki/techne/agent-host/model-api-key` stays unused. GitHub uses a fine-grained personal access token that Kris creates, limited to the Knowledge Islands repositories Kris selects, with Contents read and write and Metadata read only, expiring after 30 days. It is stored at `/ki/techne/agent-host/github-token` and used by `techne`'s Git credential helper, which the boot script installs. Rationale: an interactive login keeps model access tied to Kris's own account and revocable there, with no long-lived key to store; a fine-grained, short-lived, repository-limited token bounds what a session on the host can change on GitHub.

### Why a separate stack

GOV-020 bound 16 and the brief require the controller to remain unchanged. A parameterised controller template would have coupled the two; a separate template with its own network keeps the stacks independent and lets `destroy.sh` remove everything the prototype added without touching the controller.

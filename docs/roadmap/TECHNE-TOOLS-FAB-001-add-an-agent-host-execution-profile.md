---
id: TECHNE-TOOLS-FAB-001
area: FAB
title: Add agent-host profile
theme: execution-fabric
horizon: now
status: done
blocks: []
blocked_by: []
baseline_ref: 6cd3e92fd61bbe95d3b51e6a2fe64144f836bf7f
created_at: 2026-09-26T15:55:00Z
updated_at: 2026-10-06T22:43:40Z
---

# Add Agent-Host Profile

## Goal

Add a second, additive execution profile that can host an interactive or long-running agent session, without relaxing any of the constraints that make the existing deterministic execution profile trustworthy.

## Context

The current execution profile is correct for the deterministic dispatch work it was built for, and every one of its constraints is load-bearing for that purpose: an empty egress allowance for the namespace, an active deadline that terminates a job after five minutes, a read-only root filesystem with no mounted volumes, and a restart policy and backoff limit that make pod termination final.

Each of those is also a reason an agent session cannot run under that profile. With no egress there is no model API, so an agent cannot make its first call. A five-minute deadline terminates precisely the sessions whose purpose is to outlive a connection. A read-only root with no volumes leaves nowhere to check out a repository and nothing to restore on reattach. A terminal restart policy leaves nothing to reattach to at all.

The correct response is not to loosen the deterministic profile. It is to add a separate profile, so that the existence of one does not weaken the other.

## Boundary

This item does not change the deterministic execution profile, widen its egress, raise its deadline, or grant it a volume. It does not deploy an agent host, install an agent runtime, or authorise any spend. It designs and declares the additive profile and the guard that keeps the two apart.

## Current state

One execution profile exists, hard-coded in `build_job()` in `apps/controller/src/controller.py` (`backoffLimit: 0`, `activeDeadlineSeconds: 300`, `restartPolicy: Never`, `readOnlyRootFilesystem: True`) and mirrored in `deploy/kubernetes/execution/job.example.json`. Both execution namespaces default-deny all egress (`techne-execution-default-deny` in `deploy/kubernetes/controller/network-policy.yaml`, `deny-execution-network` in `deploy/kubernetes/target/access.yaml`). No test pins the four fields or compares the fixture with `build_job()`.

## Steps

- [x] Add `deploy/kubernetes/execution/agent-host.job.example.json`: a second Job literal with the decided fields - including `activeDeadlineSeconds: 28800`, `ttlSecondsAfterFinished: 600`, the `/workspace` `emptyDir` with `sizeLimit: 8Gi`, and `env: IDLE_TIMEOUT_SECONDS=1800` on the workload container - and pod label `techne.knowledgeislands.dev/profile: agent-host`.
- [x] Add `deploy/kubernetes/execution/agent-host-network-policy.yaml`: namespace `techne-execution`, podSelector on the profile label, egress DNS to `kube-system` plus TCP 443 only, and a comment block naming the placeholder destinations (model API, repository host).
- [x] Add `build_agent_host_job()` to `apps/controller/src/controller.py` as a separate literal; leave `build_job()` untouched and do not wire the new builder to `/run` dispatch.
- [x] Add `test_deterministic_profile_fields_are_unchanged` to `apps/controller/tests/test_controller.py`, asserting the four fields of `build_job()`, that its `spec` equals the `spec` of `deploy/kubernetes/execution/job.example.json`, and that `metadata` matches once the fixture's `namespace` key is dropped (the builder does not set it).
- [x] Add `test_agent_host_profile_shares_no_base`, asserting the agent-host Job carries the profile label and `activeDeadlineSeconds == 28800`, and that `build_job()` output is identical before and after calling `build_agent_host_job()`.
- [x] Extend `tooling/checks/controller.sh` so its `jq` check covers the new JSON and its `validate-manifests.rb` call covers `deploy/kubernetes/execution/*.yaml`.
- [x] Add a short "Execution profiles" section to `docs/guides/developer/README.md` naming both profiles and the non-regression rule, and stating that the idle reaper and operator-chat notification are declared, not yet implemented.

## Files touched

- `apps/controller/src/controller.py`
- `apps/controller/tests/test_controller.py`
- `deploy/kubernetes/execution/agent-host.job.example.json` (new)
- `deploy/kubernetes/execution/agent-host-network-policy.yaml` (new)
- `tooling/checks/controller.sh`
- `docs/guides/developer/README.md`
- This roadmap record

## Verify

All local; nothing is applied to a cluster.

```sh
bun install --frozen-lockfile && bun run test
bunx biome check . && ki repo audit --progress never && git diff --check
python3 -c 'import sys; sys.path.insert(0,"apps/controller/src"); import controller as c; j=c.build_job("telegram:42:local","techne-local-42"); s=j["spec"]; p=s["template"]["spec"]; assert (s["activeDeadlineSeconds"],s["backoffLimit"],p["restartPolicy"],p["containers"][0]["securityContext"]["readOnlyRootFilesystem"])==(300,0,"Never",True)'
jq -e '.spec.activeDeadlineSeconds==300 and .spec.backoffLimit==0 and .spec.template.spec.restartPolicy=="Never" and .spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem==true' deploy/kubernetes/execution/job.example.json
git diff --quiet "$(sed -n 's/^baseline_ref: //p' docs/roadmap/TECHNE-TOOLS-FAB-001-add-an-agent-host-execution-profile.md)" -- deploy/kubernetes/controller/network-policy.yaml deploy/kubernetes/target/access.yaml deploy/kubernetes/execution/job.example.json
```

The last three commands are the non-regression acceptance test: the deterministic profile's egress, deadline, read-only root and terminal restart policy are unchanged.

## Dependencies / blocks

Blocked by nothing. [TECHNE-TOOLS-OPS-008](TECHNE-TOOLS-OPS-008-provision-the-controller-as-a-supervised-agent-host.md) is a non-blocking boundary: substrate capacity and concrete egress destinations are decided there. Any `kubectl apply`, image build, agent-runtime install or cluster change remains under the Techne Programme Hold and is outside this item.

## Documentation impact

### Decision Records

None; the profile split is an additive declaration within existing architecture.

### Specifications

None.

### Guides

`docs/guides/developer/README.md` gains an "Execution profiles" section naming both profiles and the non-regression rule.

### Roadmap

None beyond this record.

## Review

### Delivered

The additive agent-host execution profile is declared locally: a separate `build_agent_host_job()` builder, a matching Job fixture, a label-scoped egress allow-list, two non-regression tests, extended offline checks and a developer-guide section. Excluded, as the boundary states: no change to the deterministic profile, no wiring to `/run` dispatch, no image build, no agent-runtime install and nothing applied to any cluster. Baseline `6cd3e92fd61bbe95d3b51e6a2fe64144f836bf7f`; the result is the local commit that carries this packet.

### Change Summary

- `apps/controller/src/controller.py`: adds `build_agent_host_job()` as an independent literal with the profile label, `activeDeadlineSeconds: 28800`, `ttlSecondsAfterFinished: 600`, a `/workspace` `emptyDir` with `sizeLimit: 8Gi` and `IDLE_TIMEOUT_SECONDS=1800`. `build_job()` is untouched.
- `apps/controller/tests/test_controller.py`: adds `ExecutionProfileTests` with `test_deterministic_profile_fields_are_unchanged` and `test_agent_host_profile_shares_no_base`.
- `deploy/kubernetes/execution/agent-host.job.example.json` (new): the builder's output plus the `techne-execution` namespace, formatted by Biome.
- `deploy/kubernetes/execution/agent-host-network-policy.yaml` (new): `techne-execution-agent-host-egress`, selecting the profile label, allowing DNS to `kube-system` and TCP 443, with a comment block naming the placeholder model-API and repository-host destinations.
- `tooling/checks/controller.sh`: the `jq` check covers the new fixture and `validate-manifests.rb` covers `deploy/kubernetes/execution/*.yaml`.
- `docs/guides/developer/README.md`: new "Execution profiles" section.
- Choices within the plan's latitude: the agent-host literal keeps the deterministic profile's placeholder image, command, resources, non-root user and read-only root, with `/workspace` as the only writable path; `test_agent_host_profile_shares_no_base` also checks that the builder matches its fixture, as the deterministic test does.

### Verification

- `bun install --frozen-lockfile && bun run test`: pass, 16 controller tests OK, 8 manifest files validated, offline checks passed.
- `bunx biome check .`: pass, after formatting the new fixture.
- `ki repo audit --progress never`: PASS, 18 skills.
- `git diff --check`: clean.
- Deterministic-field `python3` assertion: pass.
- Deterministic-fixture `jq -e`: `true`.
- `git diff --quiet` from the baseline over `network-policy.yaml`, `access.yaml` and `job.example.json`: exit 0, unchanged.

### Outstanding concerns

- The TCP 443 egress rule has no destination selector, so until the placeholders are filled from TECHNE-TOOLS-OPS-008 it allows 443 to any address for agent-host pods. That is the recorded decision; it must be narrowed before any apply.
- Nothing has been checked against a live API server: the manifests have only been checked for structure, offline.
- The idle reaper and operator-chat notification are declared only.

### Post-change review

Goal met: a second profile exists and cannot change the first without a test failing, because the deterministic builder is compared field by field and against its fixture. Scope held to the listed files. Regression risk is low: dispatch still calls only `build_job()`, and the new policy selects only pods with the agent-host label, which no current code path creates. Ready for review.

### Mini recap

Declared the agent-host profile and its guard locally, with all stated gates green and the deterministic profile shown to be unchanged. The main open concern is the destination-unbounded 443 rule pending OPS-008. Proposed learning route: none beyond the developer-guide section already added.

## Done

Accepted 2026-10-07 by Kris Brown on the review packet above.

## Discussion

### Named differences from the deterministic profile

The agent-host profile needs a scoped egress allowance rather than an open one, naming the model API and the repository hosts it is authorised to reach. It needs a writable workspace with a stated per-worker allocation rather than one shared root. It needs no fixed active deadline, but does need a stated maximum lifetime and an idle reaper, because a session with no ceiling is a standing bill. It needs a declared behaviour on pod termination, which the deterministic profile answers by making termination final.

### Non-regression is the acceptance test

The deliverable is only acceptable if the deterministic profile is demonstrably unchanged: same empty egress, same deadline, same read-only root, same terminal restart policy. A shared default that both profiles inherit is the most likely way for this to regress silently, so the two profiles should not share a mutable base for any of those four fields.

### Cost per idle hour

An agent host that runs while nothing is assigned is a standing charge. The profile should prefer a wake-on-demand shape, and if it cannot, it must state the idle cost explicitly so that the choice is made rather than inherited.

### Open questions

- Which exact egress destinations does an agent session require, and can they be expressed as a policy rather than an open allowance?
- How is a workspace allocated per session so that two sessions never write one repository root?
- What idle timeout and maximum lifetime are acceptable, and who is notified when one fires?
- Does the substrate have the capacity to host a session at all, given the measured node size and free disk recorded in `TECHNE-TOOLS-OPS-008`?

### Decisions - 2026-10-05

The open questions that are reversible local declarations were decided by the Fable reviewer under delegated autonomy, reversible:

- **Egress** is a `NetworkPolicy` allow-list, not an open allowance: DNS plus TCP 443 for pods with the agent-host profile label. Concrete model-API and repository-host FQDN or CIDR values need live information and stay recorded placeholders.
- **Workspace** is a per-session `emptyDir` with a `sizeLimit` placeholder of `8Gi` mounted at `/workspace`; one Job per session, so two sessions never share a repository root. Persistence across reattach is outside this item.
- **Lifetime** is `activeDeadlineSeconds: 28800` (eight hours), `ttlSecondsAfterFinished: 600`, and a declared `IDLE_TIMEOUT_SECONDS=1800` for the idle reaper; notification goes to the operator chat, as for deterministic failures.
- **Termination** stays final for this iteration (`restartPolicy: Never`, `backoffLimit: 0`); reattach survivability is deferred rather than silently relaxed.
- **No shared base**: `build_job()` is untouched and `build_agent_host_job()` is a separate literal.
- **Capacity** is the OPS-008 decision and does not block a declaration that validates without a node.

Adopted from Triage to `now` and made Ready in the same pass.

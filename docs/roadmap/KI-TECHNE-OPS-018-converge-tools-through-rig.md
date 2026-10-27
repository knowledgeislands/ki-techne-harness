---
id: KI-TECHNE-OPS-018
area: OPS
title: Converge tools through Rig
purpose: debt
project: agent-host
component: operations
kind: deliver
status: draft
horizon: now
size: l
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-27T04:16:43Z
---

# Converge Tools Through Rig

## Goal

The agent host's shared tools - Bun, Node, Codex and `ki` - are installed by `rig apply --profile agent-host` from the recipe's one declaration, rather than by `converge.sh`'s own install steps.

## Context

[ADR-KI-PRINCIPAL-003](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) in `ki-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 2 stages Rig: stage 1 (TECHNE-TOOLS-OPS-014) declares the `agent-host` profile and observes drift through `rig status`; the pilot installs personal tools through Rig; this record is stage 3.

This record is gated. It starts only when both conditions hold:

1. Rig can install `ki`'s signed release, through the provider this record now carries (merged from KI-TECHNE-OPS-016 on 2026-10-12).
2. Stage 1's `rig status` has reported clean on the host through at least one pin bump.

`converge.sh` keeps bootstrapping Rig and mise at pinned versions, because Rig does not bootstrap the managers it drives. Claude Code stays installed by the stack's boot script and observed against its declared minimum.

## Boundary

- In scope: a small custom provider under `rig-provider-v1`, beside the recipe's own `rig.toml` (never in an owner's payload), that installs an exact `ki` version through `ki`'s own signed installer into the user's home without root and reports the installed version for `rig status`; the provider must keep `ki`'s signature check over its signed archives and checksum manifest, never falling back to a SHA-256-only download or mise's GitHub-release backend; replacing `converge.sh`'s Bun, Node, Codex and `ki` installs with `rig apply --profile agent-host`; generating or checking the global mise manifest from the same declaration so one file stays authoritative; offline tests; the operator guide.
- Out of scope: a release-archive install kind in `tools-rig`, taken up only if a second archive-shipped tool needs Rig; any change to `ki`'s installer or release signing; Rig and mise bootstrap; Claude Code's install; Git settings, startup files, the repository set, `ki bootstrap`, the registry and projections, and Claude settings, which are not tool installs and stay in `converge.sh`; any live remote action.
- Merged from KI-TECHNE-OPS-025 on 2026-10-14: the role-profile move to a `roles/` folder, with the Goal and Boundary carried into Discussion below.
- Merged from KI-TECHNE-OPS-026 on 2026-10-14: the tailnet-only listener firewall declaration, with the Goal and Boundary carried into Discussion below.

## Current state

On 27 October 2026 this existing adopted record is selected from Future into Now under SUCCESSIVE-WAVES and CONFIDENT-UNATTENDED in the principal ways-of-working decisions, and the explicit wow-agent-host-role brief. Only the independently approved 14 October role/profile extraction is selected for delivery. The parent remains `draft`: its installation, version-policy and firewall phases are not planned or Ready. This is a separately approved, fully bounded partial phase, not a normal Ready-item outcome batch; no batch authorisation hash, whole-record Ready transition or completion claim is made.

The Techne Programme Focus permits this local work for vega and sol. It grants no live operation here. The brief explicitly approves the following exact phase before implementation; neither acceptance nor pruning is authorised.

### Baseline and delivery boundary

Immutable baseline: `4ead291c9061854764643f4ef969eac79f8f3d8f` on local `main`, matching `origin/main` after the authorised origin-only fetch. The primary checkout was clean and uncontested. Delivery uses this background run's isolated `wow-agent-host-role` branch with local fast-forward integration only. The root work-adapter audit passed; the roadmap preflight warned only that this record lacked `size`, now classified `l` for the full parent. Re-audit must clear that warning before code edits. Frozen source profile/provider hashes and modes are retained in this phase's review evidence. No push is authorised.

### Delegation

No subagents. This run owns selection, planning, implementation and evidence for the bounded phase only; the supervisor receives the outcome and the unfinished parent remains for later planning.

## Steps

- [x] Move `recipes/agent-host/rig.toml` and `rig-pins.sh` together to `roles/agent-host/`, byte-identically with Git modes 100644 and 100755 respectively, keeping one source and the `agent-host` profile name.
- [x] Rewire recipe metadata, setup validation/staging, workstation status and checkout convergence to the role. Resolve recipe-owned `host-instructions.md` independently. Keep the staged `rig.toml`, `rig-pins.sh` and `host-instructions.md` basenames unchanged.
- [x] Extend existing offline fixtures to prove staged and checkout invocation use the same role payload and provider mode, retaining recipe instructions in both modes. Reuse existing provider verdict and status coverage; add no move-only tests.
- [x] Run the single sufficient aggregate `bash tooling/checks/agent-host-workspace.sh` with temporary output outside the repository, then compulsory commit hooks. Review the full bounded diff, byte/mode invariants and committed paths; integrate locally by verified fast-forward and retire only this run's worktree.
- [ ] Plan the remaining parent installation, version-policy and firewall scope under later authority; this step is outside the delivered extraction phase and has no implementation approval here.

## Files touched

- `docs/roadmap/KI-TECHNE-OPS-018-converge-tools-through-rig.md`
- `recipes/agent-host/rig.toml`
- `roles/agent-host/rig.toml`
- `recipes/agent-host/rig-pins.sh`
- `roles/agent-host/rig-pins.sh`
- `recipes/agent-host/recipe.toml`
- `operations/aws/agent-host/setup.sh`
- `operations/aws/agent-host/status.sh`
- `operations/aws/agent-host/host/converge.sh`
- `tooling/checks/agent-host-workspace.sh`
- `docs/guides/operator/agent-host.md`

No additional tracked path is permitted. Reference closure covers current executable consumers and the operator guide; historical prose in this record and the deferred pin-bump idea remains provenance, not a current consumer. That idea already says its old paths are read as the lasting role path after this move. The declared general Project and repository directory standards require no new `roles/` README or declaration. No public schema or directory contract is introduced.

## Verify

The existing aggregate checker substitutes SSH, curl, tools, system state and local Git origins, using temporary homes; it performs no real host operation. Its existing setup path exercises flat staging and its direct convergence path exercises checkout lookup. Extend those fixtures for the unchanged role bytes and executable provider and exact recipe instructions; a single aggregate pass is sufficient. Do not invoke setup, status or convergence outside those fixtures. Mandatory hook failure stops affected work without bypass.

## Dependencies / blocks

The extraction has no release, Rig role-sharing, pin-bump observation or remote prerequisite. LOCAL-SYMLINKS removes release ceremony, not genuine prerequisites. Remaining parent scope stays undelivered: switching shared-tool installation to Rig, minimum versions, signed-release or clone/pin policy, Claude installation and firewall/package declarations. No package install, host/provider contract change, remote observation, rollout, network/security change or principal queue edit belongs to this phase.

## Documentation impact

### Decision Records

None: this applies the already-approved role extraction without changing architecture.

### Specifications

None: the profile/provider bytes, schema, names and staged payload contract stay unchanged.

### Guides

The operator guide names the recipe-independent role as the shared pin source and preserves existing installation and operation instructions.

### Roadmap

This record retains the phase plan and review evidence; the broader parent remains draft and unfinished. The deferred pin-bump idea already interprets its historical pin paths as the lasting role path after extraction.

## Review

### Delivered

Only the independently approved role extraction is delivered for review, against immutable baseline `4ead291c9061854764643f4ef969eac79f8f3d8f`. The parent remains `draft / now` while this partial is reviewed; its broader goal is not Ready, delivered or accepted. `baseline_ref` remains null for the unstarted full parent. No normal outcome batch, acceptance, pruning, push or live operation was used.

The two files have a single source under `roles/agent-host/` and retain their original bytes and Git modes. SHA-256 for `rig.toml` (100644): `f0274b52b3ec553463660bfa31d2d095fa729ae6e745ea9e293d76379baa9430`. SHA-256 for `rig-pins.sh` (100755): `1539178380cac6addf8432593caa28e93a7f3f3bc95acc7f40955e6cd35b5891`.

### Change Summary

Recipe metadata, setup validation and flat staging, workstation status, checkout convergence and offline fixtures use the role source. Convergence resolves recipe instructions separately, preserving recipe ownership and staged payload basenames. The operator guide identifies the shared role. The profile name and observe-only provider contract are unchanged. All tracked changes stay within the frozen Files touched list.

### Verification

The final draft-parent audit also required an unchecked remaining-parent Step; that real planning obligation is retained above rather than changing the parent lifecycle.

- `ki repo audit --skill ki-work --repo <primary>` passed adapter selection.
- `ki repo audit --skill ki-work-roadmap --repo <worktree>` passed before implementation after adding the missing parent size and correcting the planned record's required heading/task-list shape. Initial planning validation failures stopped code edits until resolved.
- The first `bash tooling/checks/agent-host-workspace.sh` attempt failed new instruction assertions because the fixture omitted the existing blank separator after the generated header. Correcting the running checker also invalidated that attempt's shell read; no result from that attempt is claimed as passing.
- The corrected `bash tooling/checks/agent-host-workspace.sh` passed once in full, with temporary homes, local origins, stubs and system fixtures. Staged setup preserves role/profile bytes, payload basenames and modes; checkout convergence restores deliberately stale installed files and provider mode while retaining recipe instructions. Existing provider verdicts, status and owner-payload fixtures remain covered.
- Exact SHA-256 and filesystem-mode predicates matched the immutable baseline; current executable/guide references contain no obsolete recipe pin/provider path. Compulsory commit hooks remain enforced on the phase commit, without bypass.

### Outstanding concerns

No unresolved extraction concern. The rest of this record remains undelivered: the Rig installation switch, minimum versions, firewall/package declarations, signed-release or clone/pin policy, and host rollout. No real host behaviour was observed; any live operation remains the binding owner's work under the Programme Focus. No new record or principal package/queue change is made.

### Post-change review

The extraction is independently useful: recipes and checkout invocations share one unchanged role without consuming another recipe's files. Regression coverage exercises both invocation modes, unchanged staging and exact instruction rendering. This phase is available for owner review only; the full parent still needs planning and cannot honestly enter whole-record Awaiting review or Done.

### Mini recap

The approved role source is extracted and its current consumers are rewired, with offline verification. The operator guide carries the lasting path; this record preserves partial authority, evidence and the remaining scope. No further knowledge route or replacement record is needed. Delivery is local only on sol.local; the supervisor receives the exact repository and branch handoff.

## Discussion

This record stays in triage until both gate conditions hold; the lessons of the pilot and of stage 1 are written into it before it is adopted.

Lessons from the workstation pilot, TECHNE-TOOLS-OPS-015, on 2026-10-09: `rig apply` counts a tool it only re-verifies as completed, so its `completed=` summary cannot tell a change from none. `converge.sh` reads `rig status --profile <profile> --format json` before the apply and reports a change only when a tool was not already present; the shared tools should follow the same pattern. Run Rig with `RIG_PROGRESS=never` and stdin closed, as the pilot does, so its output stays parseable over SSH.

Merged from KI-TECHNE-OPS-016 on 2026-10-12: [ADR-KI-PRINCIPAL-003](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) decision 3 chooses the custom provider that wraps `ki`'s signed installer. Rig's built-in `direct-download` `executable` kind covers a single binary checked by SHA-256 but not `ki`'s signed `tar.gz` archives, and the payload validator refuses a custom provider in an owner's fragment, so the provider ships with the recipe and needs no `tools-rig` release.

### Adoption

On 12 October 2026 Kris approved the triage review's proposal as written (state-of-play run, 'TRIAGE-APPROVE (all 13 proposals)'): adopted as `deliver / Hold`. Its existing gates are the hold condition: Rig must install a signed `ki` release, and `rig status` must stay clean through a pin bump. vega has been deleted and is not yet rebuilt, so the second gate cannot clear now. Remote work stays within the Techne Programme Hold. Adoption grants no implementation, acceptance or remote authority.

### Boundary audit handoff

Handed over by `ki-principal` on 2026-10-13. On 2026-10-11 Kris Brown accepted the decisions of the [Rig and Techne boundary audit](https://github.com/knowledgeislands/ki-principal/blob/main/Streams/Projects/agent-host/design/rig-techne-boundary-audit.md) ([Hosts, Roles and Layers](https://github.com/knowledgeislands/ki-principal/blob/main/Pillars/Engineering%20Practice/Architecture/Hosts%2C%20Roles%20and%20Layers.md) summarises them). Decision 5 replaces this record's harness signed-release provider with a built-in signed-release install kind in `tools-rig`, and ADR-KI-PRINCIPAL-003 decision 3 is amended to match. The audit also moves Claude Code's install from the boot script into this record's scope, as a self-updating `minimum` tool. The Boundary above still describes the harness provider; reshaping it is this repository's to do when the record is next planned. Gate 1 then reads "Rig's signed-release install kind installs `ki`", which `tools-rig` delivers. Nothing here changes the record's status, horizon or hold.

### Merged from KI-TECHNE-OPS-025 on 2026-10-14

Kris approved merging KI-TECHNE-OPS-025 into this record on 14 October 2026, in the state-of-play thread's triage burn-down, because it matters only to this record's role-profile reshape when vega is rebuilt. Its Goal and Boundary, carried as written:

**Goal.** The agentic-rig role profile, today the Rig `agent-host` profile in `recipes/agent-host/rig.toml`, lives in a recipe-independent `roles/` folder in this repository. The `agent-host` recipe refers to it rather than owning it, so a second recipe, and an owned host such as `sol`, can include the same role without copying it or reaching into another recipe's folder.

**Boundary.**

- In: moving the profile and its observe-only pins provider to `roles/`, the profile's name (whether it becomes `agentic-rig` is this repository's choice), updating every reference named below, offline checks and the operator guide.
- Out: any remote action or host rebuild; the version-policy minimums for workstations, which follow once `sol` includes the role; Rig's signed-release install kind and any Rig change for sharing a role across sources, which `tools-rig` delivers.

**References to update, from its Context.** Today the path `recipes/agent-host/rig.toml` is named by `recipe.toml` (`pins`), `recipes/agent-host/rig-pins.sh`, `operations/aws/agent-host/setup.sh`, `status.sh` and `host/converge.sh`, `tooling/checks/agent-host-workspace.sh` and the operator guide. `tools-techne` does not read the pin path, so the move needs nothing there.

**Dependencies at merge.** Not blocked. It is the sequencing prerequisite for KI-TECHNE-OPS-024's pin-bump tool, which waits for the profile's lasting path. `tools-rig` is separately asked for a way for one agentic-rig role to serve both `sol` and `vega`; this move does not wait for that.

### Merged from KI-TECHNE-OPS-026 on 2026-10-14

Kris approved merging KI-TECHNE-OPS-026 into this record on 14 October 2026, in the state-of-play thread's triage burn-down, because it matters only to this record's role-profile reshape when vega is rebuilt. Its Goal and Boundary, carried as written:

**Goal.** The `agent-host` recipe declares Rig's tailnet-only firewall for the listeners its agents start, so a development server, preview or tool port on the host is reachable only from loopback and the tailnet. The AWS stack keeps opening no public inbound port. Kris's Macs and the agent host then share one firewall model.

**Boundary.**

- In: a `linux-nftables` firewall declaration in the recipe's Rig profile for its agents' listener ports; adding `nftables` to the host's package install; moving the Rig pin to a release that contains the provider; an offline check that the stack keeps no public ingress rule; the operator guide's rollback (`sudo systemctl disable --now LOCATOR.service` and `sudo nft delete table inet rig_NAME`).
- Out: any `rig apply`, host rebuild or AWS change. Applying the firewall to the running host waits for the Techne Programme Hold to allow remote-environment management. Rig's provider itself, its review and release belong to `tools-rig`.

**Dependencies at merge.** Not blocking anything. It depends on a Rig release containing KI-TOOL-RIG-CORE-051, after that record is reviewed and accepted, and on the Techne Programme Hold for any change to the running host. KI-TECHNE-OPS-025 may move the profile to `roles/` first; the declaration then belongs wherever the role profile lives.

### Techne Programme Focus

On 20 October 2026 the [Techne Programme Focus](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Policies/Techne%20Programme%20Focus.md) in `ki-principal` replaced the Techne Programme Hold. Building, rebuilding and setting up `vega`, and changes to its running host, now fall within the focus's agent-host scope and stay the binding owner's live operations; the references to the Techne Programme Hold above are historical and read against the focus's operating bounds. The same day the agent-host work's resume run re-validated this hold: neither gate is met, because Rig cannot yet install a signed `ki` release and stage 1's `rig status` has not been shown clean through a pin bump on the rebuilt `vega`. The hold stands unchanged.

### Release dependency dropped

On 27 October 2026 the roadmap sweep dropped this record's release dependency and moved it to the `future` horizon, Later, under Kris's steer that releases are deprioritised. It no longer waits for a Rig release containing KI-TOOL-RIG-CORE-051 or for a signed `ki` release: vega's `converge.sh` can clone `tools-rig` and `tools-ki` at pinned commits instead of installing releases. Whether `rig status` has been shown clean through a pin bump on the rebuilt vega is a planning consideration when the record is next taken up, no longer a hold.

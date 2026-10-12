---
id: KI-TECHNE-OPS-016
area: OPS
title: Rig provider for ki
purpose: capability
project: agent-host
component: recipes
status: cancelled
resolution: merged
resolution_target: KI-TECHNE-OPS-018
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-08T07:32:00Z
updated_at: 2026-10-12T05:25:30Z
---

# Rig Provider for ki

## Goal

Rig can install and verify `ki`'s signed release on the agent host, keeping `ki`'s own signature check, so the recipe's `agent-host` profile can install every shared tool it declares.

## Context

[ADR-KI-PRINCIPAL-003](https://github.com/knowledgeislands/ki-principal/blob/main/Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) in `ki-principal` records the agent-host workstation model; Kris Brown approved it on 2026-10-08. Its decision 3 chooses a small harness custom provider under `rig-provider-v1` that wraps `ki`'s own signed installer.

`ki` ships signed `tar.gz` archives with a signed checksum manifest that its installer (`tools-ki/install.sh`) verifies. Rig's direct-download provider handles only a single executable checked by SHA-256, and mise's GitHub-release backend would drop the signature check. The provider lives with the recipe and needs no `tools-rig` release.

## Boundary

- In scope: the provider under `rig-provider-v1`, installing an exact `ki` version through its signed installer into the user's home without root; observing the installed version for `rig status`; offline tests with stubs.
- Out of scope: switching `converge.sh`'s `ki` install to Rig (KI-TECHNE-OPS-018); a release-archive install kind in `tools-rig`, taken up only if a second archive-shipped tool needs Rig; any change to `ki`'s installer or release signing.

## Cancelled

Cancelled 2026-10-12 by Kris Brown as merged into KI-TECHNE-OPS-018 (Decision 107 of the state-of-play thread, approving the roadmap minimisation batch 3). Rig installing `ki` is one of the four tools KI-TECHNE-OPS-018 already converges through Rig; its Boundary now carries this record's provider scope and the requirement to keep `ki`'s own signature check. No provider was built.

## Discussion

Whether the provider ships beside the recipe or in a shared provider location in this repository is settled when it is planned. It is independent of the workstation pilot and may be planned once Kris adopts it.

Lessons from the workstation pilot, TECHNE-TOOLS-OPS-015, on 2026-10-09: Rig's built-in `direct-download` `executable` kind installed the owner's `mgit` into `~/.local/bin` on the Linux host without root or Homebrew, which confirms it covers a single checked binary but not `ki`'s signed archives. The payload validator refuses a custom provider in an owner's fragment, so this provider belongs with the recipe's own `rig.toml`, never in a payload.

---
note_type: streams/index
updated: 2026-10-11T03:45:00Z
author: Written with Claude
---

# Design

## Overview

This folder holds the working papers for design questions in the work [`ki.agent-host`](../work.md) of the [Agent host](../../../../Streams/Projects/agent-host.md) Project that are still open. Its first paper explains, for Kris, what the workstation bundle sends to the agent host and weighs where the per-host sharing manifest should live, ahead of the approval of PERSONAL-DOTFILES-UE-073 and TECHNE-TOOLS-OPS-015. A second paper audits the boundary between Rig and Techne across every repository involved, and is cross-project: the state-of-play thread picks up its decisions. The papers are temporary: once their outcome is consolidated into those records or into [ADR-KI-PRINCIPAL-003](../../../../Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md), they are deleted in one commit.

## Workstation bundle walkthrough

[workstation-bundle-walkthrough](workstation-bundle-walkthrough.md) lists the files the host receives today and after the pilot, shows an example manifest, explains how Kris controls what is shared and compares four homes for the manifest capability, ending with a recommendation and its effect on the two pilot records.

## Rig and Techne boundary audit

[rig-techne-boundary-audit](rig-techne-boundary-audit.md) answers the question Kris put to the Techne thread on 2026-10-11, when Kris questioned the Rig and Techne boundary and 'asked for sense-making and an audit across Rig and Techne': whether Kris's framing of Techne provisioning a host, Rig rigging it for a role, chezmoi and Cheztoi personalising it and packaging supplying the tools holds against what the repositories actually do. It maps every current responsibility to a layer, names the overlaps, gaps and naming confusions, and proposes a host-role taxonomy of workstation, remote agentic rig and appliance, with the hand-off from Techne to Rig. It also weighs packaging options across macOS, Debian and Arch, assesses an Omarchy move for `vega`, and ends with numbered decisions and their effect on open records in `ki-techne-harness`, `tools-rig` and elsewhere.

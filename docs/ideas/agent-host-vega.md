# Agent host vega

> **Idea, not on the roadmap.** The Techne agent host vega: a machine that runs agents, built from harness recipes with person-owned bindings. It was the KI work package `ki.prj.agent-host`, on hold from 29 October 2026, and was removed on 9 November 2026 when the agoranomos consolidated the work packages in the Agora store. Kris asked for it to come back here as one idea, to consider adding back into the roadmap.

## What there is

- [The host design](agent-host-vega/design.md).
- [The Rig and Techne boundary audit](agent-host-vega/rig-techne-boundary-audit.md).
- [The workstation bundle walkthrough](agent-host-vega/workstation-bundle-walkthrough.md).

## Open points it left

- **DEV-MODE and RIG-LINK:** Rig owns `rig dev local|release <tool>`, and `~/.local/bin/rig` linked to a retired path; both were held by KI's State of play, ki.sop.main.
- **Firewall:** KI-TOOL-RIG-CORE-047 (macOS) and KI-TOOL-RIG-CORE-051 (Linux nftables) were delivered by the Mac Studio work; nothing was planned here.
- **HARNESS-INSTRUCTIONS:** Kris wants the Claude and Codex instructions to become skills from a personal harness, leaving thin `CLAUDE.md` and `AGENTS.md`; for the harness.

Since then, sol running Orca as a headless server has covered some of the same ground.

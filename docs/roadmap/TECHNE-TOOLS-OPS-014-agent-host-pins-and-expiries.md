---
id: TECHNE-TOOLS-OPS-014
area: OPS
title: Agent-host pins and expiries
kind: deliver
purpose: capability
project: agent-host
component: operations
horizon: now
status: ready
blocks: [TECHNE-TOOLS-OPS-015, TECHNE-TOOLS-OPS-018]
blocked_by: []
baseline_ref: null
created_at: 2026-10-07T20:50:00Z
updated_at: 2026-10-08T13:31:00Z
---

# Agent-Host Pins and Expiries

## Goal

The agent host can be reproduced with known tool versions from the host alone, the operator sees approaching credential expiries without looking for them, both Claude and Codex on the host follow the recipe's own working rules, and the host is marked as a checkout that must not write roadmap records.

## Context

This is the harness's wave-2 record in the agent-host durability rollout. Kris Brown approved the design on 2026-10-07; [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) in `ki-arcadia-principal` records it, with the merged report and decisions in that collection's `references/agent-host-durability-*` files.

- **Pins (decision 7).** One harness file - the recipe's Rig fragment, below - declares exact versions for `ki`, mise, Bun, Node and Codex and a minimum for Claude Code, bumped by ordinary commits, with `ki` moving to the current release. `converge.sh` applies the global pins and leaves each repository's `mise.toml` alone. `status.sh` reports drift from the pins and, when run from the operator's workstation, from that machine's versions as a signal only. `converge.sh` currently selects Node by major version only.
- **Rig profile (workstation stage 1).** [ADR-KI-ARCADIA-003](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ADR-KI-ARCADIA-003-the-agent-host-workstation-model.md) in `ki-arcadia-principal`, approved by Kris Brown on 2026-10-08, folds the first stage of the workstation model into this record. The pin file is the recipe's Rig fragment declaring the `direct-host` profile with a variant for each target OS (Linux for the current host, macOS when an owned Mac is a target) and no managed resources, and the recipe names it. `converge.sh` installs Rig at a pinned tag and keeps installing the tools itself, at the declared pins; `status.sh` reports drift through `rig status --profile direct-host --format json`. This is Rig's first proof on a real Linux host, the current host's OS: its Linux coverage today is Bats with faked native commands, and how the mise pins are expressed - Rig locators or the native mise manifest Rig observes - is settled when this record is planned. Moving the installs themselves to `rig apply` is TECHNE-TOOLS-OPS-018.
- **Expiries.** The status run writes a cached expiry file covering the GitHub token, the Tailscale key and pin drift. An interactive login prints a banner from the cache with no network or credential call. The exemption review-date line is removed from `host/status.sh`: the exemption has no fixed review date, so host status shows none.
- **Recipe instructions (P7).** `setup.sh` renders the binding owner's personal `~/.claude` files and no Codex `AGENTS.md`, so the working rules reach only one of the host's two runtimes, and only when the owner supplies them. The recipe itself renders a small host-instructions file for both Claude and Codex carrying the two-checkout rule and the writing-checkout rule, as [ODR-KI-ARCADIA-001](https://github.com/knowledgeislands/ki-arcadia-principal/blob/main/Admin/Governance/Decisions/ODR-KI-ARCADIA-001-keeping-work-safe-on-the-agent-host.md) now records, so a host without a personal payload still carries them. The binding owner's personal source adds only its own wording.
- **Host marker (decision 6).** The checkout on the operator's workstation is the designated roadmap writing checkout for every Knowledge Islands repository. `converge.sh` sets a host marker that `ki` honours; until `tools-ki` enforces it, the rule sits in the recipe's host instructions.

## Boundary

- In scope: the declared pin file as the recipe's `direct-host` Rig fragment, its application, installing Rig at a pinned tag, drift reporting through `rig status`, the cached expiry file and login banner, removing the review-date line from host status, the recipe's own host instructions for both Claude and Codex, and the host marker.
- Out of scope: the status contract, guards and operations (TECHNE-TOOLS-OPS-013, the pilot, which goes first); the `ki` refusal itself, which belongs to `tools-ki`; the binding owner's personal wording of the rules (for Kris, DOTFILES-UE-072); installing personal tools, and the owner's profile payload and instructions it carries (the workstation pilot, TECHNE-TOOLS-OPS-015); `rig apply` for the shared tools (TECHNE-TOOLS-OPS-018); the `techne` binary and any personal-configuration tool, which the host does not get; and any remote action.

## Current state

- `host/converge.sh` hard-codes the pins in shell variables (`ki` 0.7.1, mise 2026.10.3, Bun 1.4.2, Node major 24, Codex 0.160.1), writes `~/.config/mise/config.toml` from them and installs mise and `ki` itself. Nothing installs or configures Rig, and nothing declares a Claude Code minimum.
- `host/status.sh` text mode prints the GitHub token and Tailscale key expiries, read live through `git credential fill`, the GitHub API and `tailscale status`, and an `Exemption review 2026-11-06` line; it writes no cache and reports no drift. The guide's Status section and the architecture diagram's source still name the review date. `--json` (`techne/host-workspace/v1`) carries no expiry or pin data.
- `setup.sh` stages only `converge.sh`, `status.sh`, the repository list and the owner's rendered `~/.claude` files. No Codex instructions are rendered, the recipe renders no instructions of its own, and no host marker exists.
- Rig v0.4.0 is the current release. Its built-in mise observation runs `mise which LOCATOR`, which cannot see a version: a versioned locator such as `bun@1.4.2` never resolves, and an unversioned one is present at any version. A custom provider declaring only `observe` is supported (`rig-provider-v1`, one state token on stdout), so a harness observe-only provider gives `rig status` exact and minimum version drift without changing Rig. `ki`, mise and Claude Code have no Rig install path at all.
- Lessons from TECHNE-TOOLS-OPS-013: text-mode status calls `git credential fill`, the GitHub API and `tailscale status`, so checks run it only against stubs; every network tool is stubbed in checks; `--json` stays the `techne/host-workspace/v1` contract `tools-techne` consumes, so this record adds nothing to it.

## Design

- **Pin file.** `recipes/direct-host/rig.toml`, named by `recipe.toml` as `[paths] pins`, is a complete Rig configuration: `[rig] default-profile = "direct-host"`, the `direct-host` profile, one `agent-host` category and a tool each for Rig, `ki`, mise, Bun, Node, Codex and Claude Code. Each tool has a `linux` and a `macos` variant whose locator is the exact version (kind `exact`), or the minimum for Claude Code (kind `minimum`), through the observe-only custom provider `direct-host-pins`. No managed resources. Node becomes an exact version. The pins match the operator's workstation on 2026-10-08: Rig 0.4.0, `ki` 0.9.0, mise 2026.10.4, Bun 1.4.2, Node 24.21.0, Codex 0.161.0, Claude Code at least 2.1.285.
- **Observing drift.** `recipes/direct-host/rig-pins.sh` is the provider: it runs `<tool> --version`, extracts the version and prints `present`, `drifted`, `missing` or `unknown`; it refuses `apply`. Tool identities are the command names.
- **Applying pins.** `converge.sh` reads each locator for its own OS from the pin file, installs mise, `ki` and Rig (through Rig's `install.sh` at the pinned tag) at those versions, writes the global mise configuration with exact Bun, Node and Codex, installs the pin file as `~/.config/rig/rig.toml` and the provider as `~/.local/share/rig/providers/direct-host-pins`, and leaves each repository's `mise.toml` alone. `setup.sh` stages the recipe files; run from the host's checkout, `converge.sh` finds them in the checkout.
- **Drift and expiries in status.** `host/status.sh` text mode adds a Pins section from `rig status --profile direct-host --format json` (unknown when Rig is absent or fails), writes `~/.cache/ki-agent-host/expiry` with the GitHub and Tailscale expiry dates, the drifted tools and the check time, and marks any expiry within 14 days. The exemption review line goes. `--json` is unchanged. The Mac-side `status.sh`, in text mode only, then prints the workstation's own versions against the pins as a signal that never changes the exit status.
- **Login banner.** `converge.sh` writes `~/.config/ki-agent-host/banner.sh`; the environment file sources it once per interactive shell. It reads only the cache and the clock: an expiry within 14 days, pin drift, or no recent check (cache older than 7 days or absent) prints one line each, and nothing otherwise. No network or credential call.
- **Host instructions.** `recipes/direct-host/host-instructions.md` carries the two-checkout rule and the writing-checkout rule of ODR-KI-ARCADIA-001 and names the host marker. `converge.sh` renders it as `~/.claude/rules/ki-agent-host.md`, which Claude Code loads as a user-level rule beside whatever `~/.claude/CLAUDE.md` the owner supplies, and as `~/.codex/AGENTS.md`, Codex's global instructions. The owner's personal wording stays in their own files.
- **Host marker.** `converge.sh` writes `~/.config/ki/host-marker`, a short plain-text file naming the recipe and saying that roadmap writes belong to the operator's workstation checkout. The path is the one KI-TOOL-CLI-115 names as its candidate; that record agrees the shape before `ki` honours it, and until then the rule lives in the host instructions.

## Steps

- [ ] Add `recipes/direct-host/rig.toml` and `recipes/direct-host/rig-pins.sh`; name the pin file in `recipe.toml` under `[paths]`.
- [ ] Change `host/converge.sh` to read the pins from the pin file, pin Node exactly, install Rig at its tag, install the pin file and provider, write the banner, the host instructions for both runtimes and the host marker; change `setup.sh` to stage the recipe files.
- [ ] Change `host/status.sh`: drop the exemption review line, add the Pins section through `rig status`, write the expiry cache and mark expiries within 14 days. Add the workstation signal to the Mac-side `status.sh` text mode.
- [ ] Extend the offline checks: the pin file loads under a stubbed `rig` and the provider's verdicts; converge's pin reading against the pin file; status text mode with stubbed `git`, `curl`, `tailscale` and `rig` writing the cache, showing drift and the 14-day mark and carrying no review line; the banner from a cache alone with no network tool on `PATH`; the rendered instructions and marker.
- [ ] Update the operator guide (Workspace setup, Status, a short Expiries and pins part) and the architecture diagram's source, removing the review date.
- [ ] Run `bun run test`, `ki repo audit --repo .` and the grep for any remaining review line.

## Files touched

- `recipes/direct-host/rig.toml`, `recipes/direct-host/rig-pins.sh`, `recipes/direct-host/host-instructions.md`, `recipes/direct-host/recipe.toml`
- `operations/aws/agent-host/setup.sh`, `operations/aws/agent-host/status.sh`, `operations/aws/agent-host/host/converge.sh`, `operations/aws/agent-host/host/status.sh`
- `tooling/checks/agent-host-workspace.sh`, `tooling/checks/controller.sh` (shellcheck scope) and any new check fixture
- `docs/guides/operator/agent-host.md`, `docs/guides/operator/agent-host-architecture.archify.json`

## Verify

- `bun run test` passes, including the extended offline checks; every network tool (`git credential`, `curl`, `tailscale`, `rig` installers) is stubbed.
- The pin file loads in Rig v0.4.0 for both `linux` and `macos`, and the provider reports `present`, `drifted` and `missing` correctly.
- `grep -rn "Exemption review\|2026-11-06\|6 November" operations docs/guides tooling` finds nothing.
- `ki repo audit --repo .` reports no failures.
- No host, AWS, Tailscale, SSM or GitHub API call is made.

## Dependencies / blocks

- Blocks TECHNE-TOOLS-OPS-015 (the workstation pilot builds on stage 1) and TECHNE-TOOLS-OPS-018 (`rig apply` after stage 1 runs clean through a pin bump).
- Related, not blocking: KI-TOOL-CLI-115 in `tools-ki` honours the marker this record sets; KI-HARNESS-GOV-157 in `ki-agentic-harness` decides where writing-checkout designations live.

## Delegation

One agent, sequentially; no parallel lanes.

## Documentation impact

### Decision Records

None here: ODR-KI-ARCADIA-001 and ADR-KI-ARCADIA-003 in `ki-arcadia-principal` record the model.

### Specifications

None: the pin file is a Rig configuration and `techne/host-workspace/v1` is unchanged.

### Guides

`docs/guides/operator/agent-host.md`, as listed in Steps.

### Roadmap

The first live run of the pins on the host is the operator's, after review; its result feeds TECHNE-TOOLS-OPS-018's clean-through-a-bump condition.

## Discussion

### Sequencing

This record started after the pilot, TECHNE-TOOLS-OPS-013, was delivered; its lessons are in Current state. It stays one record: the pins, expiry cache and host instructions share `converge.sh`, `status.sh` and one set of checks.

### Review date

The exemption review it was to show, `KI-ARCADIA-GOV-021`, was decided early as keep and is accepted. Kris decided on 2026-10-07 (Decision 6 of the Techne run's decisions log) that the exemption has no fixed review date and is revisited when the Techne Programme Hold is reshaped, so host status stops showing a review date rather than reading one from the binding.

### Planning choices

- ADR-KI-ARCADIA-003 left open whether the mise pins are Rig locators or the native mise manifest Rig observes. Neither lets Rig v0.4.0 see a version, so every pin is a Rig locator read by a harness observe-only provider; converge still writes the mise manifest from the same locators.
- Decision 13 of the Techne run's decisions log (2026-10-08) authorises planning and delivering this record to Awaiting review.

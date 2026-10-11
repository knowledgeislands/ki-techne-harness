---
id: TECHNE-TOOLS-OPS-024
area: OPS
title: Weekly pin bump
kind: deliver
purpose: upkeep
project: agent-host
component: recipes
status: draft
horizon: next
blocks: []
blocked_by: []
baseline_ref: null
created_at: 2026-10-11T01:38:30Z
updated_at: 2026-10-11T01:38:30Z
---

# Weekly Pin Bump

## Goal

Once a week, a housekeeping run on the Mac checks every tool pinned in `recipes/agent-host/rig.toml` for a newer release, raises the pins, runs `bun run test`, and leaves the change for Kris's review. It never accepts its own run or pushes. The agent host picks up the new versions the next time setup runs. The same change stops `status.sh` from reporting the Mac's own tools against the host's pins as drift, because Homebrew and Rig govern the Mac, not the recipe.

## Context

Kris chose this on 2026-10-11 (Decision 38 in the Techne thread's decisions log): option 1 for now, a weekly pin-bump housekeeping job, and no more comparing the Mac against the host's pins.

The pin file is Rig's `agent-host` profile. Each tool has a Linux and a macOS variant whose `locator` is the version. Six pins are `exact` (rig, ki, mise, bun, node, codex) and Claude Code's is a `minimum`, because it updates itself. `converge.sh` reads the locators and installs those versions on the host; `rig status --profile agent-host` reports drift through the observe-only `agent-host-pins` provider (`rig-pins.sh`). The pin file's own comment says a bump is an ordinary commit followed by a setup rerun. Nothing raises the pins today, so they fall behind until someone notices.

The repository has no housekeeping mechanism yet. The KI way to do recurring work in a Project repository is a `ki-work-housekeeping` template under `docs/housekeeping/`: `ki-next` notices when it is due and spawns a run record, which then goes through the normal lifecycle (`ki-plan`, `ki-implement`, then `awaiting-review` for Kris, then `ki-accept`). That fits "leave it for Kris's review" exactly, and nothing needs a scheduler of its own.

The Techne programme hold bars managing remote environments, not local work. This job runs only on the Mac, in the primary checkout of this repository. Its only outward calls are read-only lookups of public release metadata. It changes no host: the host changes only when Kris reruns setup, which stays his action under the hold.

## Boundary

- In scope: a pin-bump tool in this repository that looks up each pinned tool's latest release and rewrites both locators, plus a read-only `--check` mode; offline tests for it; a housekeeping template and the `.ki.toml` declaration it needs; making the existing offline checks read tool versions from the pin file, so a bump does not break `bun run test`; and removing the Mac-versus-pins section from `status.sh`, its check and the operator guide.
- Out of scope: running setup on the host or any other remote-environment change; installing a Mac scheduler (launchd or similar), which is an environment change that needs its own approval; changing how the Mac's own tools are governed (Homebrew and Rig, through chezmoi); the record-identifier comments in `status.sh`, which [TECHNE-TOOLS-OPS-017](TECHNE-TOOLS-OPS-017-zsh-shell-at-rebuild.md) owns.

## Current state

- `recipes/agent-host/rig.toml` pins rig 0.4.0, ki 0.10.0, mise 2026.10.6, bun 1.4.2, node 24.21.0 and codex 0.162.0 exactly, and claude 2.1.285 as a minimum. The Linux and macOS locators are equal. The macOS variants exist for a macOS agent host, not for the operator's Mac, and stay.
- `operations/aws/agent-host/status.sh` lines 54–69 print "This workstation against the pins (signal only)" after the host report. They run `rig-pins.sh` against each macOS locator on the operator's own machine. Lines 6–7 of its header describe this. It never changes the exit status, and `--json` does not include it.
- `tooling/checks/agent-host-workspace.sh` line 259 asserts that section is present. `docs/guides/operator/agent-host.md` (Status section) says "Last, it compares the Mac's own tools with the same pins".
- The same check script hard-codes pinned versions in its host stubs: mise `2026.10.6` (line 54), ki `0.10.0` (line 67), codex `0.162.0` (line 81), rig `0.4.0` (line 87), and the literal `"npm:@openai/codex" = "0.162.0"` assertion (line 219). Bun and node are already read from the pin file (lines 215–218). After a bump, the stale stubs would make `converge.sh` try to reinstall through the failing `curl` stub, so `bun run test` would fail. The provider verdict checks (lines 228–238) use their own literal pins against their own stubs and are unaffected.
- `tooling/checks/recipe-pins.py` checks the shape of the pin file (both variants, provider, exact or minimum, numeric versions). It does not check that the two variants agree.
- `package.json` has `self:*` scripts and `test` = `self:deps:layout` plus `turbo run typecheck test`; the agent-host checks run through `tooling/checks/controller.sh`. The `tomllib` checks need Python 3.11 or later on `PATH`.
- `.ki.toml` does not declare `[skills.ki-work-housekeeping]` and there is no `docs/housekeeping/`.

## Steps

- [ ] Pin-bump tool: add `tooling/pins/bump.py` and a `self:pins:bump` package script. For each `[tool.*]` it looks up the latest stable release: rig and ki from their `tools-rig` and `tools-ki` release tags (`git ls-remote --tags`), mise from `jdx/mise` tags, bun from `oven-sh/bun` `bun-v*` tags, node from `https://nodejs.org/dist/index.json`, codex and claude from the npm registry (`npm view <package> version`). It rewrites both the Linux and macOS `locator` lines in place, keeping every other line byte-for-byte, and prints one line per tool (`unchanged`, `raised <old> → <new>`, `held: <reason>`, or `lookup failed`). `--check` changes nothing and exits non-zero when anything could be raised. A failed lookup leaves that pin alone and fails the run. Node and Claude Code follow decisions 1 and 2. Tests can supply releases through a fixture file (`PINS_RELEASES=<file>`) so they make no network call.
- [ ] Offline tests for the tool, on a copy of the pin file with fixture releases: raises exact pins, keeps both variants equal, leaves comments and formatting intact, makes no change on a second run, holds node to its line, handles the Claude minimum as decided, refuses to lower a pin, and fails without writing when a lookup fails. Wire them into `bun run test` beside the existing checks.
- [ ] Variants agree: `recipe-pins.py` also fails when a tool's Linux and macOS locators differ, so a half-applied bump cannot land.
- [ ] Version-neutral checks: in `agent-host-workspace.sh`, read mise, ki, codex and rig from the pin file (the helper already used for bun and node) for the host stubs and the Codex `mise` assertion, so the checks pass at any pinned version.
- [ ] Stop the Mac comparison: remove the workstation section and its header sentence from `status.sh`; change the line 259 check to assert the text report no longer contains "This workstation against the pins"; remove the guide's "Last, it compares the Mac's own tools…" sentence and say instead that the Mac's tools are governed by Homebrew and Rig, not the recipe.
- [ ] Housekeeping template: declare `[skills.ki-work-housekeeping]` in `.ki.toml` and add `docs/housekeeping/TECHNE-TOOLS-HK-001-weekly-pin-bump.md` with `status: active`, `cadence: P1W`, `grace: P2D`, `spawn-policy` and trigger as decision 3 settles, `spawn-horizon: now`, `last-run: null`, `active-run: null`, `project: agent-host`, `component: recipes`, `purpose: upkeep`. Its procedure: on the Mac, in the primary checkout, with mise's Python first on `PATH`, run `bun run self:pins:bump`; if nothing changed, record a no-change result; otherwise run `bun run test`, commit `recipes/agent-host/rig.toml` alone (`chore(recipes): raise agent-host pins`) and stop at `awaiting-review`. It never accepts, pushes or reruns setup. Successful-run evidence: each tool's old and new version or no-change, test result and commit. Accepting the run tells Kris to rerun setup when convenient.
- [ ] Update the operator guide's pins paragraph and the comment at the top of `rig.toml` to name the weekly run and `bun run self:pins:bump`.

## Files touched

- `tooling/pins/bump.py` (new) and its tests and fixtures under `tooling/checks/`
- `package.json` (`self:pins:bump`, test wiring)
- `tooling/checks/recipe-pins.py`, `tooling/checks/agent-host-workspace.sh`
- `operations/aws/agent-host/status.sh`
- `recipes/agent-host/rig.toml` (comment only; the pins change in the weekly runs, not here)
- `.ki.toml`, `docs/housekeeping/TECHNE-TOOLS-HK-001-weekly-pin-bump.md` (new)
- `docs/guides/operator/agent-host.md`

## Verify

- `bun run test` passes with mise's Python 3.12 first on `PATH`, including the new pin-bump tests, which make no network call.
- With a copy of `rig.toml` whose locators are all raised by hand, `bun run test` still passes once the copy is in place (version-neutral checks), and fails when one variant differs from the other.
- `ki repo audit` reports no failure, including `ki-work-housekeeping` on the new template, and `ki-next` on the Mac lists TECHNE-TOOLS-HK-001 as due (no `last-run`).
- `bash operations/aws/agent-host/status.sh` against the stubbed host in the checks prints no workstation section; its exit status and `--json` output are unchanged.
- After approval, one live `bun run self:pins:bump --check` on the Mac reports each tool's latest release without writing. No host is touched.

## Dependencies / blocks

None blocking. [TECHNE-TOOLS-OPS-017](TECHNE-TOOLS-OPS-017-zsh-shell-at-rebuild.md) also edits `status.sh` (comments only) and `agent-host-workspace.sh`; whichever lands second rebases. [TECHNE-TOOLS-OPS-018](TECHNE-TOOLS-OPS-018-converge-tools-through-rig.md) may later make Rig install these tools; the pin file stays the source either way, so the job carries over. Landing a bumped pin on the host needs Kris to rerun setup, which stays under the remote-environment hold and outside this record.

## Documentation impact

### Decision Records

None. Decision 38 in the Techne thread's decisions log records Kris's choice; it does not change architecture.

### Specifications

None. The pin file's shape and the provider are unchanged, apart from the new rule that both variants agree.

### Guides

`docs/guides/operator/agent-host.md`: the Status section loses the Mac comparison; the pins paragraph gains the weekly run and `bun run self:pins:bump`.

### Roadmap

None beyond the overlaps under Dependencies / blocks. Each weekly run is spawned from the template as its own record.

## Discussion

Captured, adopted into Next and planned on 2026-10-11 under Decision 38. Kept `draft` for Kris's approval. The decisions below need settling before it can be Ready; the plan above assumes the recommendations.

1. **Node's release line.** Recommended: stay on the pinned major (24, the current LTS line) and only raise within it; the run reports a newer LTS major as a note, and moving to it is a separate decision. Alternative: follow the newest LTS major automatically.
2. **Claude Code's minimum.** Recommended: leave the minimum alone in the weekly run, because Claude Code updates itself and the pin is only a floor; raise it by hand when a needed feature requires it. Alternative: raise it to the latest release each week, at the cost of the host showing drift until it updates itself.
3. **How the run is triggered.** Recommended: `spawn-policy: when-due`, so whenever Kris or an agent runs `ki-next` on the Mac and the week has passed, the run is spawned and done there (interactively or through `ki agent launch`), with no scheduler for now. Alternative: a launchd job on the Mac that queues the run weekly, which is a Mac environment change made through chezmoi and needs its own approval.
4. **Other tools' major versions.** Recommended: raise rig, ki, mise, bun and codex to their latest stable release whatever the size of the jump, and rely on `bun run test` and Kris's review as the gate. Alternative: hold major jumps for a separate decision, like node.

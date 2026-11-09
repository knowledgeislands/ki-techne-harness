---
note_type: streams/design
updated: 2026-10-11T02:19:55Z
author: Written with Claude
---

# Workstation bundle walkthrough

**For:** Kris Brown - **Project:** [Agent host](../../../../Streams/Projects/agent-host.md) - **Date:** 2026-10-09 - **Authority:** Kris's 2026-10-09 decisions in the Techne run: '(a) workstation bundle approved in principle' and '(b) Cheztoi manifest capability: a per-target-host manifest of what to share, ideally not a new tool ... to be weighed in the walkthrough before DOTFILES-UE-073 is approved'

A reading document. It explains what the agent host receives from Kris's Mac, how Kris controls it, and where the "what to share with this host" manifest should live. It changes no record; the recommendation is for Kris to accept, amend or reject before PERSONAL-DOTFILES-UE-073 and TECHNE-TOOLS-OPS-015 are approved.

**Outcome:** Kris accepted the recommendation on 2026-10-09 in the Techne run ('Workstation bundle walkthrough accepted, including the chezmoi-native per-host manifest recommendation'), including the chezmoi-native per-host manifest (one `chezmoi archive` call with `--override-data`, `scripts/cheztoi-render` as a thin wrapper) and the optional `target_host` field checked against `host.id`. PERSONAL-DOTFILES-UE-073 and TECHNE-TOOLS-OPS-015 have been replanned to match and await Kris's approval.

---

## 1. What the host receives

**Today.** `setup.sh` in `ki-techne-harness` runs `chezmoi cat` on the Mac for five files and copies them into `~/.claude/` on the host, each with a "Rendered from the Mac's chezmoi source" header. Nothing is ever removed, Codex gets no personal file, and no personal tool or shell setting reaches the host.

| File                       | What it says (summary)                                                                                     |
| -------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `~/.claude/CLAUDE.md`      | Where shared versus personal guidance belongs; plan before non-trivial work; commit and never push unasked |
| `~/.claude/communication.md` | The `quiet` reporting level, full work-record identifiers, the "chezmoi" and "Rig" speech-to-text rules  |
| `~/.claude/delegation.md`  | Delegate substantive work to detached background agents through `ki agent` †                               |
| `~/.claude/memory-scope.md` | Choose the durable owner (repository, personal config, memory) before saving guidance                     |
| `~/.claude/markdown.md`    | Use `ki-authoring` for KI documents; footnote markers in chat tables                                       |

† Wrong for the host: the exemption allows agents only in sessions Kris opens, so the host needs a variant without detached agents.

**After the pilot.** The same files arrive as one bundle (the "profile payload") with a manifest, plus the Codex file, a minimal zsh profile and one Rig fragment. Every file is checked on the Mac before it leaves and again on the host.

| File on the host                     | Content                                                                                       |
| ------------------------------------ | --------------------------------------------------------------------------------------------- |
| The five `~/.claude/*.md` files      | As above, with `delegation.md` replaced by the host variant (in-session subagents only)        |
| `~/.codex/AGENTS.md` (composed)      | Recipe rules first, then Kris's Codex preferences: communication, Markdown, workflow          |
| `~/.zshrc`                           | Sources `~/.zsh/*`, without the Mac-only iTerm2 line                                          |
| `~/.zsh/00_xdg_base_dirs`, `00_path` | XDG directory variables; de-duplicated `PATH`                                                 |
| `~/.zsh/00_utils`                    | Small process helpers (`psfind`, `psup`, `pszombie`)                                          |
| `~/.zsh/50_mise`, `50_ki`            | Activate mise in zsh (with the Homebrew manual path guarded); the `ki` MCP source variable    |
| `~/.zsh/99_prompt`                   | Kris's prompt; its chezmoi status segment stays empty because chezmoi is absent               |
| `~/.config/rig/conf.d/cheztoi.toml`  | A `cheztoi` profile selecting `mgit`, installed on Linux by checksum-pinned direct download    |

An example manifest is in [Appendix A](#appendix-a-example-manifest).

## 2. How Kris controls it

- **The allowlist.** Only files named in the per-host manifest in the chezmoi source are rendered. Anything not named is not sent, so adding a file to the Mac never adds it to the host. Dropping a name sends a `removed` entry, and the host deletes only files it recorded installing.
- **Preview on the Mac.** Rendering writes the bundle to `~/.cache/cheztoi/<host>/` and changes nothing in `$HOME`. Kris can read every file there, and `tar tvf` or `ls -l` shows names and modes, before running `techne host setup`.
- **Checks on both ends.** The Mac refuses a bundle containing a secret, a path or command that is wrong for the target system (for Linux, `/Users/`, `/opt/homebrew`, `pbcopy`), a symbolic link, an unlisted file, a reserved destination such as `~/.ssh/` or `~/.claude/settings.json`, or a Rig fragment declaring a provider or managed resource. The host repeats the structural checks before writing, and `status` reports the applied revision and any personal-tool drift.

## 3. Alternatives not chosen

- **chezmoi on the host:** the source resolves 1Password at apply time, has no OS gating and cannot be reached from the host, and [ADR-KI-PRINCIPAL-003](../../../../Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) rules out personal-configuration tools there.
- **Nothing personal:** a recipe-only host works, but would not feel like Kris's workstation, which is the point of the model.
- **A git clone of the chezmoi source:** puts the whole private source, including Mac-only and credential-adjacent material, on a host Kris may not own, and needs a new read credential.

## 4. Where the manifest capability should live

Kris's idea: a small per-target-host manifest naming what to share, not a new tool. Four homes were weighed.

| Option                                    | Cost                                                                                                          | Generality                                                                                         | Fit with ownership                                                                                                                        |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| (i) `scripts/cheztoi-render` as planned   | Medium: a bespoke renderer calling `chezmoi cat` per file, its own modes, revision and tests                  | Low: lives in Kris's source; another owner copies it                                               | Good: [ADR-KI-PRINCIPAL-003](../../../../Admin/Governance/Decisions/ADR-KI-PRINCIPAL-003-the-agent-host-workstation-model.md) gives the renderer to the owner's source                                                                         |
| (ii) In the `ki-binding-chezmoi` skill    | Medium-high: new standard and rubric, and the executable still has to live somewhere                          | Medium: any chezmoi user, but only them                                                            | Poor: the skill governs the MCP render path only, is declaration-only and proposes no writes; a payload renderer is a different concern   |
| (iii) A Rig extension for chezmoi         | High: a new verb or exporter in `tools-rig` and a spec change                                                 | High in principle                                                                                  | Poor: Rig reconciles the machine it runs on and leaves chezmoi's source and templates native (PDR-KI-TOOL-RIG-001); exporting for another host inverts that |
| (iv) chezmoi-native, driven by a manifest | Low: `chezmoi archive` renders exactly the named targets with templates resolved and modes kept; a thin wrapper adds `manifest.json` and validation | High: the manifest file and wrapper are the same for any chezmoi user; other owners render to the same contract with their own tool | Good: chezmoi keeps templating, the owner's source keeps the allowlist, the harness keeps the contract                                    |

**Recommendation: (iv).** Keep one small manifest file per target host in the owner's chezmoi source, and render it with `chezmoi archive <targets...>` plus `--override-data` to tell templates which host and OS they are rendering for. The planned `scripts/cheztoi-render` stays, but shrinks to a wrapper: read the host manifest, call `chezmoi archive`, unpack it to `home/`, write `manifest.json`, compute `removed` and validate. Rig is not extended; it only consumes the fragment on the host, as already planned. `ki-binding-chezmoi` is not the home either: once a second owner uses the pattern, write it up as a standard in `ki-repo-dotfiles-chezmoi`, which owns general chezmoi structure. A test on the Mac confirmed that `chezmoi archive` emits exactly the eight pilot files it was given (the five Claude files, the Codex file, `.zshrc` and `50_ki`) with their `0600` and `0644` modes.

`.chezmoiignore` with a host variable is not needed: naming targets explicitly is already default-deny, and an ignore-based guard would also run during every Mac apply. Details and caveats are in [Appendix B](#appendix-b-the-chezmoi-native-mechanism).

**What it changes in PERSONAL-DOTFILES-UE-073.**

- The flat `config-fragments/cheztoi/allowlist` becomes a per-host manifest, for example `config-fragments/cheztoi/hosts/ki-techne-agent-host.toml`, naming the target OS and the targets.
- Rendering uses one `chezmoi archive` call instead of `chezmoi cat` per file, and takes modes from the archive.
- Host variants become ordinary templated sources rather than files under `config-fragments/`, because `chezmoi archive` cannot render ignored paths: `private_delegation.md`, `dot_zshrc` and `50_mise` branch on a `cheztoi` data value that defaults to empty in `.chezmoidata`, so the Mac's `chezmoi diff` stays empty. Templates test that value, not `.chezmoi.os`, which still reports macOS during the render.
- The "renderer refuses its own output" and harness-validator steps, the Rig fragment, the revision and the tests are unchanged.

**What it changes in TECHNE-TOOLS-OPS-015.** The payload contract is renderer-neutral and stays as written. One addition is recommended: an optional `target_host` field in `manifest.json`, which `converge.sh` checks against the host's `host.id`, so a bundle rendered for one host is refused on another. The operator guide should show the chezmoi-native render as the Cheztoi example.

## 5. Long-term direction

Kris, 2026-10-09: Claude and Codex instructions should eventually arrive as skills from a personal harness, which does not exist yet, leaving `CLAUDE.md` and `AGENTS.md` thin. Shipping the instruction files in the bundle is the interim route until that harness is designed; the bundle mechanism stays useful for the shell profile and the Rig fragment after that.

---

## Appendix A: example manifest

```json
{
  "schema": "techne/host-profile/v1",
  "revision": "chezmoi@f8be37b+clean;sha256:4c1e...9a",
  "target_os": "linux",
  "target_host": "ki-techne-agent-host",
  "files": [
    { "path": ".claude/CLAUDE.md", "mode": "0600" },
    { "path": ".claude/communication.md", "mode": "0600" },
    { "path": ".claude/delegation.md", "mode": "0600" },
    { "path": ".claude/memory-scope.md", "mode": "0600" },
    { "path": ".claude/markdown.md", "mode": "0600" },
    { "path": ".codex/AGENTS.md", "mode": "0600" },
    { "path": ".zshrc", "mode": "0644" },
    { "path": ".zsh/00_xdg_base_dirs", "mode": "0644" },
    { "path": ".zsh/00_path", "mode": "0644" },
    { "path": ".zsh/00_utils", "mode": "0644" },
    { "path": ".zsh/50_mise", "mode": "0644" },
    { "path": ".zsh/50_ki", "mode": "0644" },
    { "path": ".zsh/99_prompt", "mode": "0644" },
    { "path": ".config/rig/conf.d/cheztoi.toml", "mode": "0644" }
  ],
  "removed": [],
  "rig": { "fragment": ".config/rig/conf.d/cheztoi.toml", "profile": "cheztoi" }
}
```

`target_host` is the proposed addition; every other field is contract version 1 as planned in TECHNE-TOOLS-OPS-015.

## Appendix B: the chezmoi-native mechanism

The per-host manifest in the chezmoi source might read:

```toml
host = "ki-techne-agent-host"
target_os = "linux"
targets = [
  ".claude/CLAUDE.md", ".claude/communication.md", ".claude/delegation.md",
  ".claude/memory-scope.md", ".claude/markdown.md", ".codex/AGENTS.md",
  ".zshrc", ".zsh/00_xdg_base_dirs", ".zsh/00_path", ".zsh/00_utils",
  ".zsh/50_mise", ".zsh/50_ki", ".zsh/99_prompt", ".config/rig/conf.d/cheztoi.toml",
]
```

The wrapper then runs, in effect:

```sh
chezmoi archive --format=tar \
  --override-data '{"cheztoi":{"host":"ki-techne-agent-host","targetOS":"linux"}}' \
  ~/.claude/CLAUDE.md ~/.claude/communication.md ... | tar -x -C "$out/home"
```

- **`chezmoi archive [target]...`** renders only the named targets, resolving templates as an apply would, and writes nothing to `$HOME`.
- **`--override-data`** sets the `cheztoi` values for this render only; templates use them to choose host variants.
- **`--include` / `--exclude`** filter by entry type, not path; `--exclude=scripts,encrypted` is a cheap extra guard against run scripts and encrypted files.
- **`--destination`** only changes the base the target paths are relative to; archive paths are already home-relative, so it is not needed.
- **`.chezmoiignore` with a host variable** could hide everything except the manifest's targets when `cheztoi.host` is set, but it is redundant with explicit targets and is evaluated on every Mac apply, so it is left out.

Caveats: a named target whose template reads 1Password or another secret source would resolve that secret, so such targets must never be listed and the secret check must stay; `modify_` targets run their modify script and should not be listed; `.chezmoi.os` reports the Mac, so host branching must use the `cheztoi` values.

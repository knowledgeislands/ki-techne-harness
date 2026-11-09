---
note_type: streams/design
updated: 2026-10-11T14:00:00Z
author: Written with Claude
---

# Rig and Techne boundary audit

**For:** Kris Brown - **Project:** [Agent host](../../../../Streams/Projects/agent-host.md), with [Rig](../../../../Streams/Themes/rig.md) and [Techne](../../../../Streams/Themes/techne.md) - **Date:** 2026-10-11 - **Authority:** Kris's 2026-10-11 instruction in the Techne run, questioning the Rig and Techne boundary and asking 'for sense-making and an audit across Rig and Techne', with 'read-only audit and one written assessment in Arcadia; no record changes' - **Scope:** cross-project, for the state-of-play thread to pick up

A reading document. It inventories what Rig, the Techne harness and CLI, chezmoi and Cheztoi, the Homebrew tap and `tools-ki` actually do today, tests Kris's four-layer framing against that, and ends with numbered decisions. It changes no record. The hold on building KI-TECHNE-OPS-017 and approving KI-TECHNE-OPS-024 stands until Kris answers the decisions below.

## Am I confusing things?

No. The framing is sound, and it is closer to what the tools already do than the labels suggest. The confusion comes from the labels and from one bundle. `tools-rig` is not a macOS tool: its core is portable Bash, tested on Linux, with Linux-capable providers. Only Kris's catalogue in chezmoi is macOS-only (404 of 406 entries). Arcadia's Rig Initiative and the Mac Studio Project describe Rig as "the workstation", and that is what makes Rig look like a Mac-only thing. Separately, the Techne `agent-host` recipe does three jobs at once. It provisions the host (base), it declares and installs the host's tools (a Rig profile, installed by its own setup script rather than by Rig), and it applies Kris's personal layer (the Cheztoi payload). What is missing is a word: a **role**. With roles, `vega` and `sol` become the same role, a remote agentic rig, on different bases (a cloud instance and an owned Mac). The recipe then shrinks to base plus hand-off, and the tool pins become a role profile that Rig applies. Two refinements to the framing follow. First, a **workspace** layer (repositories, `ki bootstrap`, the writing-checkout rules) sits between rigging and personalising, and it belongs to Techne and KI, not to Rig. Second, packaging is better seen as one release contract with several thin channels than as one package manager per OS.

## Layers at a glance

| Layer | Question it answers | Owner (proposed) | `terra` | `sol` | `vega` | Appliance (future) |
| --- | --- | --- | --- | --- | --- | --- |
| Base | Is there a reachable, patched, identified host with an operator user? | Techne: `ki-techne-harness` recipes and provider stacks, `tools-techne` commands | Kris by hand | Kris by hand; an owned-host provider later | AWS stack and boot script | A Techne recipe |
| Role | Which tools, at which versions, does this kind of host need? | Rig: `tools-rig` engine; role profiles from their owners (decision 3) | `laptop` on `core` | `studio` on `core`, plus the agentic-rig role | agentic-rig role (today the recipe's `agent-host` profile) | appliance role |
| Workspace | Which repositories, skills and working rules? | Techne recipe through `ki` (`ki bootstrap`, registry, host marker) | Kris's checkout, the writing checkout | as `vega` | `converge.sh` | none or a fixed set |
| Personal | How does this person like it? | chezmoi (trusted hosts) and Cheztoi (less-trusted hosts) | chezmoi | chezmoi | Cheztoi payload | none |
| Packaging | How does each tool reach each OS? | Each `tools-*` repository's release, plus thin channels | Homebrew tap | Homebrew tap | installers and direct download | to decide (decision 6) |

---

## 1. Responsibilities mapped to layers

Each line is a responsibility that exists today, where it lives, and the layer it belongs to under the framing. "Differs" marks a split that does not match the framing.

| Responsibility today | Where it lives | Layer | Differs? |
| --- | --- | --- | --- |
| VPC, EC2 instance, AMI (Ubuntu), security group, IAM operator role | `ki-techne-harness` `infra/aws/agent-host-stack.yaml` | Base | - |
| Tailscale install and join, tailnet tag, SSH entry | stack boot script, `provision.sh` | Base | - |
| Secrets from SSM (GitHub token, Tailscale key, Ubuntu Pro token) | stack boot script and IAM policy | Base | - |
| Unattended security patching, reboot window, Livepatch, `updates` report | recipe `[patching]`, AWS provider patching table, boot script | Base | - |
| Operator user `techne` created with `/bin/bash` | boot script | Base | the shell is a binding choice applied only by a `.bashrc` hand-off (KI-TECHNE-OPS-017 fixes) |
| Base OS packages: `curl`, `git`, `jq`, `tmux`, `xz-utils`, `zsh` | boot script, `apt-get` | Base | - (Rig needs these to start) |
| Claude Code install | boot script, as the operator user | Role | yes: a role tool installed by the base |
| Lifecycle: status verdict, stop, rebuild, withdraw, expiries | harness scripts, `tools-techne` `techne host` | Base | - |
| Bindings (`~/.config/techne/hosts/agent-host.toml`), controller config | chezmoi `dot_config/techne/` | Base (per-person instance data) | - |
| Tool pins: rig, ki, mise, bun, node, codex exact; claude minimum | `ki-techne-harness` `recipes/agent-host/rig.toml`, a Rig profile | Role | yes: a role profile owned by one recipe and named after the host kind |
| Installing Rig and mise | `converge.sh` (curl installers) | Base-to-role bootstrap | - (Rig cannot install itself) |
| Installing bun, node, codex through mise, and `ki` through its signed installer | `converge.sh` | Role | yes: setup installs tools itself; Rig only observes, through the custom `agent-host-pins` provider |
| Drift of the host's tools | `status.sh` via `rig status --profile agent-host` | Role | - |
| Drift of the Mac against the host's pins | `status.sh`, "This workstation pins" | none | yes: compares two different roles; KI-TECHNE-OPS-024 removes it |
| Repository set, clone, `ki bootstrap`, Git settings, startup files, host marker, host instructions | `converge.sh`, `host-instructions.md`, `repositories.txt` | Workspace | the framing does not name this layer |
| Personal files (zsh fragments, Claude and Codex instructions) and personal Rig fragment | chezmoi `config-fragments/cheztoi/hosts/vega.toml`, `scripts/cheztoi-render`, applied by `converge.sh` | Personal | - |
| Personal tools on `vega` (only `mgit`, by direct download) | chezmoi `private_cheztoi.toml.tmpl` selecting catalogue variants | Personal through Rig | - |
| Kris's Mac catalogue, profiles `core`, `laptop`, `studio`, macOS defaults, Dock, launchd jobs | chezmoi `dot_config/rig/conf.d/` | Role and personal | `terra` and `sol` are machine names; the profiles are `laptop` and `studio` |
| Rig engine: catalogue, profiles, providers (homebrew, uv, mise, npm, chezmoi, direct-download, custom), state, apply, upgrade | `tools-rig` | Role engine | - |
| `ki`, `techne`, `rig`, `mgit`, `git-almanac` formulae | `homebrew-tap` | Packaging | - |
| `ki` and `techne` signed or checksummed archives for darwin-arm64, darwin-x64 and linux-x64 | `tools-ki` and `tools-techne` releases and `install.sh` | Packaging | no linux-arm64 |
| `sol` build | Kris by hand, with chezmoi and Rig (Mac Studio bootstrap) | Base by hand, role and personal by Rig and chezmoi | - |

Three differences stand out. The tool pins are a Rig profile, but they live inside a Techne recipe and are named after it. Setup installs tools itself while Rig only watches (KI-TECHNE-OPS-018 already exists to fix that). Claude Code is installed by the base, not by the role.

## 2. Overlaps, gaps and naming confusions

### Overlaps

- **Recipe and role.** `recipes/agent-host/` holds both the base (stack, patching, lifecycle) and the role (`rig.toml`). A second recipe, such as an appliance or an owned-host one, would have to copy the role or reach into another recipe's folder.
- **Two ways to say what a host needs.** For `vega` it is the recipe's pins. For `sol` it is Kris's `studio` profile. Both are remote agentic rigs, yet nothing tells you they should carry the same KI toolchain. On 2026-10-11 Kris told the Techne thread to 'stop comparing the Mac against the host's pins (Mac governed by Homebrew/Rig, not the recipe)'. That was right for `terra`, but it leaves `sol` and `vega` with no shared definition either.
- **Version policy in two places.** The recipe pins exact versions for reproducible rebuilds. The Mac takes the newest from Homebrew. KI-TECHNE-OPS-024 would add a third mechanism, a pin-bump job, beside `rig upgrade`.

### Gaps

- **No role concept.** Rig has profiles but no published, person-neutral role that more than one source can include.
- **Rig cannot install a signed release archive.** That is why `converge.sh` installs `ki` itself (KI-TECHNE-OPS-016 and -018). `techne` and `ki` share the same archive pattern, so a second archive-shipped tool already exists. ADR-KI-PRINCIPAL-003 set that as the condition for a built-in kind in `tools-rig`.
- **Linux coverage of the personal catalogue.** Only `mgit` has a Linux variant. Cheztoi's fragment accepts only built-in providers, so personal tools on Linux are limited to mise, uv, npm and direct download.
- **No linux-arm64 builds** of `ki` or `techne`. This rules out Graviton instances and small ARM appliances.
- **Rig's platforms are `macos`, `linux` and `any`.** Nothing distinguishes Debian from Arch, which an Arch base would need wherever native packages differ.
- **No appliance recipe, no owned-host provider.** Both are ideas only. Anything that runs Paperclip remotely stays held by the [Techne Programme Hold](<../../../../Admin/Governance/Policies/Techne Programme Focus.md>).
- **Pin lag.** The recipe pins Rig 0.4.0, while the tap and the latest release are 0.5.0.

### Naming confusions

| Term | Means today | Problem |
| --- | --- | --- |
| profile | a Rig profile (`core`, `laptop`, `studio`, `agent-host`, `cheztoi`); the Cheztoi "host profile" payload (`techne/host-profile/v1`, `AGENT_HOST_PROFILE`); an AWS CLI profile | Three meanings in one setup path. Suggest "payload" for Cheztoi's and "profile" only for Rig's |
| recipe | a Techne host kind: base, workspace and role together | Should mean the base plus hand-off only |
| role | (not used) | The missing word for what a host is for |
| binding | one person's instance of a recipe | Clear; keep |
| agent host | the Project, the recipe, the binding, the EC2 instance name `ki-techne-agent-host`, the Rig profile, the Rig category and the tag `ki-agent-host-id` | One phrase for seven things |
| `direct-host` | ADR-KI-PRINCIPAL-003, ADR-KI-PRINCIPAL-006, ODR-KI-PRINCIPAL-001 and GDR-KI-PRINCIPAL-004 still use it | Kris renamed it to `agent-host` on 2026-10-09 in the Techne run ("let's just call it agent-host"), but Arcadia's Decision Records were not updated |
| `terra`, `sol`, `vega` | machine names under the convention Kris set on 2026-10-09 in the Techne run: 'physical machines are our solar system (sol = Mac Studio, terra = laptop), peripherals are moons' and 'the AWS agent host is to be named vega' | Rig profiles are `laptop` and `studio`, and the host is still `ki-techne-agent-host` until its rebuild |
| Rig | in `tools-rig`, a portable manager for a person's working setup; in Arcadia's Rig Initiative, "the workstation" | The Initiative's wording is narrower than the tool's |

"Agent host" and "remote agentic rig" are the same idea at two levels. "Remote agentic rig" names the role, and `vega` and `sol` are both one. "Agent host" names a Techne recipe that builds one kind of base for that role. Keep "remote agentic rig" for the role and rename or narrow the recipe (decision 2).

## 3. Proposed boundary and host-role taxonomy

### Roles

A host has exactly one base and one or more roles.

| Role | What it is for | Interactive personal layer | Example hosts | Hold position |
| --- | --- | --- | --- | --- |
| **Workstation** | A person at the keyboard: GUI applications, Dock, macOS defaults, services | chezmoi | `terra`, `sol` | outside the hold |
| **Remote agentic rig** | Agent sessions the owner opens over Tailscale SSH: the KI toolchain, a workspace of repositories and the personal layer | chezmoi on owned hosts, Cheztoi on less-trusted hosts | `vega`, `sol` | exempt under [GDR-KI-PRINCIPAL-004](../../../../Admin/Governance/Decisions/GDR-KI-PRINCIPAL-004-techne-focus-on-the-agent-host-and-the-mac-studio.md) |
| **Appliance** | Runs a service or runtime, such as a Paperclip environment, with no remote desktop and no personal shell | none, or a minimal Cheztoi payload for the operator | none yet | held; needs a hold reshape |

`sol` carries two roles, workstation and remote agentic rig. That is why the Mac Studio Project sits in Rig while also being an exempt remote agent host. Roles compose: it does not have to be one or the other.

### Ownership

| Piece | Owner |
| --- | --- |
| Base recipes (cloud and owned), provider stacks, patching, identity and secrets delivery, operator user and login shell, lifecycle, status verdict | `ki-techne-harness` |
| Operator commands, binding schema, provider adapters | `tools-techne` |
| Workspace layer: repository set, `ki bootstrap`, host marker, host instructions | `ki-techne-harness` recipe, through `tools-ki` behaviour |
| Rig engine, providers, install kinds (including a signed-release kind) | `tools-rig` |
| Role profiles: agentic-rig, appliance | see decision 3; recommended home is `ki-techne-harness` `roles/`, outside any recipe |
| Workstation profiles (`core`, `laptop`, `studio`), personal catalogue, Cheztoi | chezmoi |
| Release artefacts per tool | each `tools-*` repository |
| Homebrew formulae | `homebrew-tap` |
| Meaning, roles, invariants, the hold | Arcadia |

### The hand-off from Techne to Rig

Techne's job ends at a **ready host**, defined as a contract the recipe can check:

1. The host is reachable over the tailnet by SSH as the operator user, whose login shell is the binding's shell.
2. Base packages are present: `curl`, `git`, `ca-certificates`, a supported shell. Unattended security patching is set up, and secrets are delivered.
3. Rig is installed at the recipe's pinned version (the one bootstrap Rig cannot do for itself), with mise beside it.
4. A small host-facts file names the host, its platform and its roles, such as `roles = ["agentic-rig"]`. Rig and Cheztoi read it instead of guessing.

Setup then runs, in order: `rig apply --profile <role>` (the role layer), the workspace step (repositories and `ki bootstrap`), and the personal payload (Cheztoi files plus `rig apply --profile cheztoi`). On a ready owned host such as `sol`, the same three steps apply, with chezmoi in place of Cheztoi. The owned-host provider idea only has to reach step 4, with no provisioning.

Under this split `converge.sh` stops installing tools (KI-TECHNE-OPS-018's goal), and Claude Code moves from the boot script into the role, as a self-updating `minimum` tool.

## 4. Packaging strategy

The need is for Kris's and KI's own tools (`ki`, `techne`, `rig`, `mgit`, `git-almanac` and future ones) to install on macOS, Ubuntu/Debian and Arch/Omarchy, on x64 and arm64, without root where possible, and with integrity checks kept.

| Option | Reach | Integrity | Root needed | Effort | Fit |
| --- | --- | --- | --- | --- | --- |
| Homebrew tap (today) | macOS; Linux via Linuxbrew | sha256 in the formula | Linuxbrew needs a `/home/linuxbrew` prefix set up once with root | low, exists | right for Macs; heavy and unidiomatic on servers and Arch |
| Signed GitHub Releases plus installer (today for `ki`; `techne` checksummed) | any OS with `curl` and `tar` | Ed25519-signed checksum manifest, key embedded in the installer | no | low, exists | the right canonical artefact |
| Rig signed-release install kind | anywhere Rig runs | verifies the same signed manifest | no | medium, one `tools-rig` feature | lets roles install KI tools declaratively; replaces KI-TECHNE-OPS-016's custom provider |
| mise (`github` or `ubi` backend) | any OS | checksums; drops `ki`'s signature check | no | low per tool | fine for third-party tools; not for signed KI tools |
| aqua registry | any OS | checksum, cosign, SLSA | no | medium; needs a registry, public or private | a second mise-adjacent channel; no gain over the Rig kind |
| apt repository | Debian, Ubuntu | signed repository | yes, to add it | high: signing key, hosting, tooling | only for an appliance fleet patched by `unattended-upgrades` |
| AUR (`-bin` PKGBUILDs) | Arch, Omarchy | sha256 in the PKGBUILD | installs with root | low per tool, but public publication | only if an Arch or Omarchy workstation becomes real; needs Kris's explicit approval to publish |
| Nix flake | any OS with Nix | content-addressed | Nix needs a daemon set up with root | medium; a whole second package world | overlaps Rig, mise and Homebrew; not recommended |

**Recommendation.** Make one **KI release contract** the canonical artefact for every KI and personal tool. Each release has per-platform archives (darwin-arm64, darwin-x64, linux-x64 and linux-arm64), a checksum manifest, an Ed25519 signature and an installer with the key embedded, as `tools-ki` already does. Then keep three thin channels. Use the Homebrew tap for Macs. Use a Rig built-in signed-release install kind in `tools-rig`, so any role or Cheztoi fragment can install KI tools on any OS. Keep the installer for bootstrap. Single-file Bash tools (`mgit`, `rig`) can keep direct download with a pinned checksum until they adopt the contract. Defer apt, AUR and Nix until an appliance fleet or an Arch workstation actually exists. None of this publishes anywhere new, except the linux-arm64 builds on existing release pages.

## 5. What an Omarchy move would mean

As understood here (not re-checked in this run, which made no network calls), Omarchy is an opinionated desktop distribution built as a script on top of Arch Linux. It has the Hyprland Wayland desktop, mise for language runtimes, its own update command and its own dotfiles under `~/.config`. It bundles base, role and personal into one opinionated set, which is exactly the layering this audit separates.

**For the AWS provider:**

- There is no first-party Arch AMI. The stack would need a community image or one Kris builds, and the `ImageId` default becomes an OS choice. That makes the AWS provider table need an OS (base image) axis: `providers.aws` × base `ubuntu` or `arch`.
- The boot script is apt- and snap-specific throughout: `apt-get`, the AWS CLI and the SSM agent from snap, `unattended-upgrades`, `/var/run/reboot-required`, Ubuntu Pro and Livepatch. Each part needs an Arch equivalent, and some have none.
- **Patching changes meaning.** Arch is a rolling release with no security-only channel and no Livepatch. The recipe's `unattended = "security"` and `livepatch = "opt-in"` cannot be honoured. The choice becomes full scheduled updates (accepting breakage, recovered by rebuild) or manual updates. The status `updates` fields (pending, security, reboot required) need new sources.
- A remote desktop on Hyprland needs a Wayland VNC or RDP server and is awkward without a GPU. Without the desktop, Omarchy is mostly Arch plus dotfiles.

**For the recipe and Rig:**

- The role profile carries over almost unchanged, because mise, direct download, the KI signed installers and Claude Code's installer all work on Arch. Rig would need a Debian-versus-Arch platform distinction only where native packages are used.
- Omarchy's own update command and dotfiles overlap Techne's patching and chezmoi or Cheztoi. Someone has to own each file or the layers fight.

**Assessment.** For `vega` the cost is high and the gain is mainly a desktop it does not need. Keep `vega` on Ubuntu LTS for its security channel, Livepatch and AMIs, and give it the "Omarchy feel" through the role profile and the personal layer. Omarchy fits better as a future owned Linux **workstation**, where Rig would then need a pacman provider and the personal catalogue would need Arch variants.

## 6. Effect on open records

Plain words only. No record is changed by this audit.

- **KI-TECHNE-OPS-017** (binding shell at rebuild, rename to `vega`, remove record identifiers), `ki-techne-harness`: **stands**. It is base-layer work and fits any outcome below. Before the build, decide whether the rebuild also carries a recipe rename (decision 2). A rebuild costs a fresh Tailscale key and device, so it should happen once. If the recipe keeps its name, build as planned. Also update the GDR-KI-PRINCIPAL-004 scope in Arcadia when the rename lands, because it names the instance `ki-techne-agent-host`, alongside the tag and parameter prefix, which keep their values.
- **KI-TECHNE-OPS-018** (shared tools through Rig), `ki-techne-harness`: **stands and grows in importance**. It is the change that turns the recipe into "base plus hand-off". Two changes are suggested. Its first gate (the `ki` provider) becomes the `tools-rig` signed-release kind. Claude Code's install moves into its scope, out of the boot script.
- **KI-TECHNE-OPS-016** (Rig provider for `ki`), `ki-techne-harness`: **should move**. It would be replaced by a `tools-rig` record for a built-in signed-release install kind, since `techne` already makes `ki` not the only archive-shipped tool. This needs a small amendment to ADR-KI-PRINCIPAL-003 in Arcadia, whose decision 3 chose the harness provider.
- **KI-TECHNE-OPS-024** (weekly pin bump), `ki-techne-harness`: **split it**. The part that stops comparing the Mac with the host's pins is correct under any outcome and can be approved now. Hold the pin-bump tool until the role profile's home is decided (decision 3), because the job should follow the profile. If roles become a general idea, pin bumping of exact locators could be a Rig capability next to `rig upgrade` rather than a harness script.
- **KI-TECHNE-OPS-019** (person-neutral recipe defaults) and **KI-TECHNE-OPS-023** (controller and target tags), `ki-techne-harness`: **stand**, unaffected.
- **KI-TOOL-TECHNE-CLI-006** and **KI-TOOL-TECHNE-CLI-008**, `tools-techne`: **stand**. Both are base lifecycle work.
- **Rig's roadmap** (`tools-rig`: unwanted software removal, profile-filtered Dock items, self-updating applications, single sudo prompt): **stands**. All are workstation-role items. New work would be raised there: the signed-release install kind, a Debian-versus-Arch platform distinction (only if an Arch base is chosen), and role profiles that can be included from another source (if not already covered by `conf.d` fragments).
- **chezmoi**: PERSONAL-DOTFILES-UE-074 (host delegation) **stands**. A future item would add Linux variants for the personal tools Kris wants on remote agentic rigs.
- **`tools-ki` and `tools-techne`**: a new item each for linux-arm64 release builds, if Kris wants ARM hosts.
- **Arcadia**: the Rig Initiative's direction would widen from "the workstation" to "rigs any host for its role", and the Techne Initiative's would say it "takes hosts to ready". ADR-KI-PRINCIPAL-003 would gain the base, role, workspace and personal split and the signed-release kind. The four Decision Records still saying `direct-host` would take the rename Kris chose on 2026-10-09 ("let's just call it agent-host").

---

## Decisions for Kris

**Outcome:** Kris accepted all ten decisions as recommended on 2026-10-11. [Hosts, Roles and Layers](<../../../../Pillars/Engineering Practice/Architecture/Hosts, Roles and Layers.md>) holds the plain-language summary.

1. **Adopt the four layers plus workspace.** Base (Techne), role (Rig), workspace (Techne through `ki`), personal (chezmoi or Cheztoi), with packaging as a separate supply concern. _Recommended: yes._
2. **Name the role "remote agentic rig" and narrow the recipe.** Options: (a) keep the recipe called `agent-host` and only describe it as "the AWS base for a remote agentic rig"; (b) rename it now, in KI-TECHNE-OPS-017's single rebuild. _Recommended: (a)._ Renaming touches the tags, parameter prefix, GDR-KI-PRINCIPAL-004 scope and the controller tooling for little gain. Revisit when a second recipe (appliance or owned host) exists.
3. **Home of the agentic-rig role profile** (today `recipes/agent-host/rig.toml`). Options: (a) `ki-techne-harness`, moved to a recipe-independent `roles/` folder; (b) `tools-ki`, beside `ki bootstrap`, as "what a KI session needs"; (c) chezmoi, as part of Kris's catalogue. _Recommended: (a) now._ `sol` can then include the same role later, so both agentic rigs share one definition, with variants for Homebrew on macOS.
4. **Version policy per role.** Exact pins for rebuildable hosts (`vega`), newest through Homebrew for workstations (`terra`, `sol`), with the role declaring minimums both satisfy. _Recommended: yes._
5. **Signed-release install kind in `tools-rig`**, replacing KI-TECHNE-OPS-016's harness provider and amending ADR-KI-PRINCIPAL-003 decision 3. _Recommended: yes._
6. **Packaging strategy**: one KI release contract (per-platform archives including linux-arm64, signed manifest, embedded-key installer) with the Homebrew tap, the Rig kind and the installer as channels. Defer apt, AUR and Nix. _Recommended: yes._
7. **Omarchy for `vega`.** Options: (a) stay on Ubuntu LTS and get the feel through role and personal layers; (b) move `vega` to Arch or Omarchy, adding an OS axis to the AWS provider and dropping security-only patching; (c) keep Omarchy for a future owned Linux workstation. _Recommended: (a) with (c)._
8. **Release the holds.** Build KI-TECHNE-OPS-017 as planned (if decision 2 is (a)), and approve KI-TECHNE-OPS-024's status change while holding its pin-bump tool until decision 3 lands. _Recommended: yes._
9. **Appliance role.** Record it as a third role in the taxonomy now, with no recipe until the hold is reshaped. _Recommended: yes._
10. **Hand to state-of-play.** State-of-play turns the accepted decisions into handoffs to `ki-techne-harness`, `tools-rig`, `tools-ki`, `tools-techne`, chezmoi and Arcadia (the Initiative wording, ADR-KI-PRINCIPAL-003 and the `direct-host` rename). _Recommended: yes._

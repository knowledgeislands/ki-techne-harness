#!/usr/bin/env bash
# check() evaluates its single-quoted conditions later, so they must not expand
# here, and a ~/ in a message or payload path is literal.
# shellcheck disable=SC2016,SC2034,SC2088
set -euo pipefail

# Offline checks of the agent-host workspace scripts (TECHNE-TOOLS-OPS-015). A
# temporary Mac home and host home, local Git origins and stub ssh, chezmoi,
# curl, tailscale, zsh, mise, ki, rig, bun, codex and claude stand in for the
# network and the host; an empty system root, or a fixture one, stands in for
# the OS.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
scripts=${repo_root}/operations/aws/agent-host
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

failures=0
check() {
  if eval "$1"; then return 0; fi
  echo "agent-host-workspace: $2" >&2
  failures=$((failures + 1))
}

export GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 GIT_AUTHOR_DATE='2026-10-07T00:00:00Z' GIT_COMMITTER_DATE='2026-10-07T00:00:00Z'
unset XDG_CONFIG_HOME GIT_DIR GIT_WORK_TREE
mac_home=${work}/mac
host_home=${work}/host
state=${work}/state
stubs=${work}/stubs
mkdir -p "${mac_home}" "${host_home}/.local/bin" "${host_home}/.config/husky" "${host_home}/.claude" "${state}" "${stubs}"
HOME=${mac_home} git config --global user.name 'Test Operator'
HOME=${mac_home} git config --global user.email 'operator@example.invalid'

stub() {
  printf '#!/usr/bin/env bash\n%s\n' "$2" >"$1"
  chmod +x "$1"
}

# Mac-side tools. ssh skips its options and runs the remote command locally as
# the host user.
stub "${stubs}/ssh" "while [[ \$1 == -o ]]; do shift 2; done; echo \"\$1\" >>'${state}/ssh.log'; HOME='${host_home}' exec bash -c \"\$2\""
# setup no longer reads the operator's chezmoi source (TECHNE-TOOLS-OPS-015).
stub "${stubs}/chezmoi" "echo \"\$*\" >>'${state}/chezmoi.log'"
stub "${stubs}/curl" "echo \"\$*\" >>'${state}/curl.log'; exit 1"
# tailscale reports a node key only once a check writes one.
stub "${stubs}/tailscale" "cat '${state}/tailscale.json' 2>/dev/null"
# The chosen shell: the hand-off's exec lands here and records itself.
stub "${stubs}/zsh" "echo \"zsh \$*\" >>'${state}/handoff.log'"

# Host-side tools, where converge.sh expects them.
key='$(pwd | tr / _)'
stub "${host_home}/.local/bin/mise" "case \$1 in
  --version) echo '2026.10.6 linux-x64 (stub)' ;;
  ls) [[ -f '${state}'/mise-${key} ]] || echo 'node 24 (missing)' ;;
  install) touch '${state}'/mise-${key} ;;
  activate) echo \"ki_mise_hook=\$2\" ;;
  trust) if [[ \$2 == --show ]]; then
      if [[ -f '${state}'/trust-${key} ]]; then echo \"\$(pwd): trusted\"; else echo \"\$(pwd): untrusted\"; fi
    else cd \"\$(dirname \"\$3\")\" && touch '${state}'/trust-${key}; fi ;;
esac"
stub "${host_home}/.local/bin/ki" "config=\$HOME/.config/ki/config.toml
render() { mkdir -p \"\$(dirname \"\$config\")\"; cat '${state}/ki-agents' '${state}/ki-dev' 2>/dev/null >\"\$config\"; }
# Like ki, bootstrap detects agents only on its first run or with --refresh.
detect() { { echo '\"claude-code\",'; [[ -d \$HOME/.agents ]] && echo '\"chatgpt-codex\",'; } >'${state}/ki-agents'; }
case \$1 in
  --version) echo 0.10.0 ;;
  bootstrap) [[ \$2 == --refresh || ! -f '${state}/ki-agents' ]] && detect; render; mkdir -p \"\$HOME/.claude/skills\"; ln -sfn /stub/ki-next \"\$HOME/.claude/skills/ki-next\" ;;
  dev) case \$3 in
      set) [[ -f '${state}/ki-active' ]] && { echo 'ki: error: local development is active' >&2; exit 1; }
        printf '[locals.\"%s\"]\npath = \"%s\"\n' \"\$4\" \"\$5\" >'${state}/ki-dev' ;;
      on) touch '${state}/ki-active' ;;
    esac; render ;;
  registry) if [[ \$2 == list ]]; then cat '${state}/registry' 2>/dev/null; else echo \"\$4\" >>'${state}/registry'; fi ;;
  repo) if [[ \$3 == diag ]]; then
      if [[ -f '${state}/repaired' ]]; then echo 'summary: REPAIRABLE=0 UNREPAIRABLE=0'; else echo 'summary: REPAIRABLE=1 UNREPAIRABLE=0'; fi
    elif [[ -f '${state}/repair-fails' ]]; then echo 'ki: error: projection is stale' >&2; exit 1
    else touch '${state}/repaired'; fi ;;
esac"
stub "${host_home}/.local/bin/bun" 'if [[ -d node_modules ]]; then echo "Checked 1 install across 1 package (no changes)"; else mkdir node_modules; echo "1 package installed"; fi'
stub "${host_home}/.local/bin/codex" 'echo "codex-cli 0.162.0"'
stub "${host_home}/.local/bin/claude" 'echo "2.2.0 (Claude Code)"'
# rig status reports Codex drifted once a check asks it to, and the owner's
# profile's ripgrep likewise; ripgrep is missing until rig apply installs it,
# and like Rig the stub counts every applied tool as completed.
stub "${host_home}/.local/bin/rig" "case \$1 in
  --version) echo 'rig 0.4.0' ;;
  apply) echo \"\$*\" >>'${state}/rig-apply.log'
    [[ \$* == 'apply --profile owner --scope tools' ]] || exit 2
    touch '${state}/rig-applied'
    echo 'Summary: planned=1 completed=1 failed=0 skipped=0' ;;
  status) if [[ \$* == 'status --profile owner --format json' ]]; then
      tool=missing; [[ -f '${state}/rig-applied' ]] && tool=present; [[ -f '${state}/owner-drift' ]] && tool=drifted
      echo \"{\\\"tools\\\":[{\\\"id\\\":\\\"ripgrep\\\",\\\"state\\\":\\\"\${tool}\\\"}]}\"
      [[ \${tool} == present ]]; exit
    fi
    [[ \$* == 'status --profile agent-host --format json' ]] || exit 2
    if [[ -f '${state}/rig-drift' ]]; then
      echo '{\"tools\":[{\"id\":\"bun\",\"state\":\"present\"},{\"id\":\"codex\",\"state\":\"drifted\"}],\"healthy\":false}'; exit 1
    fi
    echo '{\"tools\":[{\"id\":\"bun\",\"state\":\"present\"},{\"id\":\"codex\",\"state\":\"present\"}],\"healthy\":true}' ;;
esac"

# Origins: alpha is a KI repository with Bun and mise; beta and gamma are plain.
origin() {
  local name=$1 seed=${work}/seed-$1
  git init --quiet --bare --initial-branch=main "${work}/origins/${name}.git"
  git init --quiet --initial-branch=main "${seed}"
  echo node_modules/ >"${seed}/.gitignore"
  echo "${name}" >"${seed}/README.md"
  if [[ ${name} == alpha ]]; then
    echo '[repo]' >"${seed}/.ki.toml"
    echo '{}' >"${seed}/package.json"
    : >"${seed}/bun.lock"
    printf '[tools]\nbun = "1.4.2"\n' >"${seed}/mise.toml"
  fi
  git -C "${seed}" add --all
  git -C "${seed}" -c user.name=seed -c user.email=seed@example.invalid commit --quiet -m seed
  git -C "${seed}" push --quiet "${work}/origins/${name}.git" main
}
for name in alpha beta gamma; do origin "${name}"; done
repositories=${work}/repositories.txt
{
  echo '# test set'
  for name in alpha beta gamma; do echo "knowledgeislands/${name} ${work}/origins/${name}.git"; done
} >"${repositories}"

# Existing host state: beta is behind its origin, gamma has uncommitted work, and
# the start-up files carry the hand-made blocks of 2026-10-07.
workspace=${host_home}/workspaces/kit/knowledgeislands
mkdir -p "${workspace}"
git clone --quiet "${work}/origins/beta.git" "${workspace}/beta"
git clone --quiet "${work}/origins/gamma.git" "${workspace}/gamma"
echo local >>"${workspace}/gamma/README.md"
echo more >>"${work}/seed-beta/README.md"
git -C "${work}/seed-beta" -c user.name=seed -c user.email=seed@example.invalid commit --quiet -am more
git -C "${work}/seed-beta" push --quiet "${work}/origins/beta.git" main

legacy='# ki-agent-host: mise shims (TECHNE-TOOLS-OPS-011)
case ":$PATH:" in *":$HOME/.local/share/mise/shims:"*) ;; *) PATH="$HOME/.local/share/mise/shims:$PATH" ;; esac
export PATH
# end ki-agent-host: mise shims'
hand_env='[ -f "$HOME/.ki-host-env" ] && . "$HOME/.ki-host-env"'
printf '%s\n\n# ~/.profile stock\nPATH="$HOME/bin:$PATH"\n\n%s\n' "${legacy}" "${hand_env}" >"${host_home}/.profile"
printf '%s\n\n\n%s\n\n# ~/.bashrc stock\ncase $- in\n    *i*) ;;\n      *) return;;\nesac\neval "$(/home/techne/.local/bin/mise activate bash)"\n' \
  "${legacy}" "${hand_env}" >"${host_home}/.bashrc"
printf '%s\n' "${legacy}" >"${host_home}/.config/husky/init.sh"
echo 'export KNIP_DISABLE_RAW_TRANSFER=1' >"${host_home}/.ki-host-env"
echo '{"theme":"dark"}' >"${host_home}/.claude/settings.json"
# What the retired chezmoi cat path rendered, beside a
# file of the operator's own.
for file in CLAUDE.md memory-scope.md; do
  printf '<!-- Rendered for ki-techne-agent-host from the Mac'"'"'s chezmoi source; rerun setup rather than editing. -->\n# %s\n' \
    "${file}" >"${host_home}/.claude/${file}"
done
echo '# my notes' >"${host_home}/.claude/notes.md"
# ki was bootstrapped before Codex had a home, so only Claude Code is configured.
echo '"claude-code",' >"${state}/ki-agents"

export PATH="${stubs}:${PATH}"
# The host's OS state is read under this root: empty unless a fixture fills it.
export KI_AGENT_HOST_SYSROOT=${work}/sysroot
mkdir -p "${KI_AGENT_HOST_SYSROOT}"
setup() { HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} bash "${scripts}/setup.sh" --pull 2>&1; }

first=$(setup) || { echo "${first}" >&2; echo 'agent-host-workspace: first setup run failed' >&2; exit 1; }
check '[[ ${first} == *"cloned knowledgeislands/alpha"* ]]' 'first run must clone alpha'
check '[[ ${first} == *"fast-forwarded knowledgeislands/beta"* ]]' 'first run must fast-forward the clean, behind beta'
check '[[ ${first} == *"skipped  knowledgeislands/gamma: uncommitted changes"* ]]' 'first run must leave the dirty gamma alone'
check '[[ ${first} == *"dependencies in knowledgeislands/alpha"* && ${first} == *"registered knowledgeislands/alpha"* ]]' 'first run must install and register alpha'
check '[[ ${first} != *"no changes"* ]]' 'first run must report changes'

second=$(setup) || { echo "${second}" >&2; echo 'agent-host-workspace: second setup run failed' >&2; exit 1; }
check '[[ ${second} == *"CHANGES=0 "* && ${second} == *"no changes"* ]]' "second run must report no changes, got:
${second}"
check '[[ ${second} == *"skipped  knowledgeislands/gamma: uncommitted changes"* ]]' 'second run must still leave gamma alone'

on_host=$(HOME=${host_home} bash "${scripts}/host/converge.sh" --repositories "${repositories}" 2>&1) || true
check '[[ ${on_host} == *"no changes"* ]]' "a run on the host must change nothing, got:
${on_host}"

start='# >>> ki-agent-host (TECHNE-TOOLS-OPS-011) >>>'
for file in .profile .bashrc .config/husky/init.sh; do
  check '[[ $(head -n 1 "${host_home}/${file}") == "${start}" ]]' "${file} must start with the agent-host block"
  check '[[ $(grep -cF "${start}" "${host_home}/${file}") == 1 ]]' "${file} must hold one agent-host block"
  check '! grep -qE "mise shims|ki-host-env|mise activate" "${host_home}/${file}"' "${file} must lose the hand-made blocks"
done
expected_profile="${start}
[ -f \"\$HOME/.config/ki-agent-host/env.sh\" ] && . \"\$HOME/.config/ki-agent-host/env.sh\"
# <<< ki-agent-host <<<

# ~/.profile stock
PATH=\"\$HOME/bin:\$PATH\""
check '[[ $(cat "${host_home}/.profile") == "${expected_profile}" ]]' "the migrated .profile is not as expected:
$(cat "${host_home}/.profile")"
check 'grep -qF "# ~/.profile stock" "${host_home}/.profile" && grep -qF "*) return;;" "${host_home}/.bashrc"' 'stock start-up content must survive'
check '[[ ! -e ${host_home}/.ki-host-env ]] && ls "${host_home}"/.local/state/ki-agent-host/backups/*/.ki-host-env >/dev/null' 'the hand-made environment file must be backed up and removed'
check 'grep -qx "export KNIP_DISABLE_RAW_TRANSFER=1" "${host_home}/.config/ki-agent-host/env.sh"' 'the environment file must keep KNIP_DISABLE_RAW_TRANSFER'
check '[[ $(jq -c . "${host_home}/.claude/settings.json") == "{\"theme\":\"dark\",\"autoMemoryEnabled\":false}" ]]' 'settings must keep their keys and turn auto-memory off'
check '[[ ! -e ${host_home}/.claude/CLAUDE.md && ! -e ${host_home}/.claude/memory-scope.md ]] && ls "${host_home}"/.local/state/ki-agent-host/backups/*/memory-scope.md >/dev/null' 'files the chezmoi cat path rendered must be backed up and removed'
check 'grep -qx "# my notes" "${host_home}/.claude/notes.md" && [[ ! -e ${state}/chezmoi.log ]]' 'the operator'"'"'s own file must stay, and setup must not run chezmoi'
check '[[ $(cat "${host_home}/.local/state/ki-agent-host/shell") == zsh && $(head -n 1 "${host_home}/.zshenv") == "${start}" ]]' 'zsh, the default shell, must source the environment from ~/.zshenv'
check 'grep -qF "exec '"'"'${stubs}/zsh'"'"' -l" "${host_home}/.bashrc"' 'interactive bash must hand off to zsh'
check '(( $(grep -nF "hand-off (TECHNE-TOOLS-OPS-015)" "${host_home}/.bashrc" | cut -d: -f1) < $(grep -nF "*) return;;" "${host_home}/.bashrc" | cut -d: -f1) ))' 'the hand-off must come before Ubuntu'"'"'s interactive-only return'
check '[[ $(HOME=${host_home} git config --global user.name) == "Test Operator" ]]' 'the Git identity must come from the Mac'
check 'grep -qx local "${workspace}/gamma/README.md"' 'gamma must keep its uncommitted change'
check '[[ $(git -C "${workspace}/beta" rev-parse HEAD) == $(git -C "${work}/origins/beta.git" rev-parse main) ]]' 'beta must match its origin'
check 'grep -q "npm:@openai/codex" "${host_home}/.config/mise/config.toml"' 'the mise pins must include Codex'

# The pins: converge applies the pin file's Linux and
# macOS locators alike, installs it and the provider for Rig, and renders the
# recipe's instructions and the host marker.
pins=${repo_root}/recipes/agent-host/rig.toml
check 'python3 "${repo_root}/tooling/checks/recipe-pins.py" "${pins}"' 'the pin file must declare every tool for both OSes through the observe-only provider'
for tool in bun node; do
  pin=$(python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["tool"][sys.argv[2]]["variant"]["macos"]["install"]["locator"])' "${pins}" "${tool}")
  check 'grep -qx "${tool} = \"${pin}\"" "${host_home}/.config/mise/config.toml"' "the mise configuration must pin ${tool} ${pin} exactly"
done
check 'grep -qx "\"npm:@openai/codex\" = \"0.162.0\"" "${host_home}/.config/mise/config.toml"' 'the mise configuration must pin Codex from the pin file'
check 'cmp -s "${pins}" "${host_home}/.config/rig/rig.toml"' 'the pin file must be Rig'"'"'s configuration'
check '[[ -x ${host_home}/.local/share/rig/providers/agent-host-pins ]] && cmp -s "${repo_root}/recipes/agent-host/rig-pins.sh" "${host_home}/.local/share/rig/providers/agent-host-pins"' 'the provider must be installed for Rig'
for file in .claude/rules/ki-agent-host.md .codex/AGENTS.md; do
  check 'grep -qF "Push where you worked" "${host_home}/${file}" && grep -qF "roadmap writing checkout" "${host_home}/${file}"' "${file} must carry the two-checkout and writing-checkout rules"
done
check 'grep -qx "recipe = \"agent-host\"" "${host_home}/.config/ki/host-marker"' 'converge must write the host marker'

# The provider's verdicts against stub tools.
tools=${work}/tools
mkdir -p "${tools}"
stub "${tools}/bun" 'echo 1.4.2'
stub "${tools}/node" 'echo v24.20.1'
stub "${tools}/claude" 'echo "2.1.300 (Claude Code)"'
stub "${tools}/codex" 'echo "codex-cli (no version)"'
verdict() { PATH="${tools}:/usr/bin:/bin" "${repo_root}/recipes/agent-host/rig-pins.sh" rig-provider-v1 observe agent-host-pins "$@"; }
check '[[ $(verdict bun exact 1.4.2) == present && $(verdict node exact 24.21.0) == drifted ]]' 'the provider must compare exact pins'
check '[[ $(verdict claude minimum 2.1.285) == present && $(verdict claude minimum 2.2.0) == drifted ]]' 'the provider must compare minimum pins numerically'
check '[[ $(verdict codex exact 0.162.0) == unknown && $(verdict rig exact 0.4.0) == missing ]]' 'the provider must report unknown and missing tools'
check '! PATH="${tools}:/usr/bin:/bin" "${repo_root}/recipes/agent-host/rig-pins.sh" rig-provider-v1 apply agent-host-pins bun exact 1.4.2 >/dev/null 2>&1' 'the provider must refuse anything but observing'
check 'grep -qF "\"chatgpt-codex\"" "${host_home}/.config/ki/config.toml"' 'ki must configure the Codex runtime'
check '[[ -f ${state}/repaired ]]' 'repairable estate projections must be repaired'

# A failed repair suggests --pull, since a checkout behind origin is the usual cause.
rm "${state}/repaired"
touch "${state}/repair-fails"
failed_repair=$(HOME=${host_home} bash "${scripts}/host/converge.sh" --repositories "${repositories}" 2>&1) || true
check '[[ ${failed_repair} == *"failed   ki repo --estate repair"*"rerun setup with --pull"* ]]' "a failed repair must suggest --pull, got:
${failed_repair}"
rm "${state}/repair-fails"
touch "${state}/repaired"

git -C "${workspace}/alpha" -c user.name=t -c user.email=t@example.invalid commit --quiet --allow-empty -m local
code=0
report=$(HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} bash "${scripts}/status.sh" 2>&1) || code=$?
check '[[ ${code} == 3 && ${report} == *"summary: REPOSITORIES=3 AT_RISK=2 UNKNOWN=0 OUTCOME=at-risk"* ]]' "status must flag alpha and gamma and exit 3, got ${code}:
${report}"
check '[[ ${report} == *"GitHub token"* && ${report} == *"Tailscale node key"* && ${report} != *"Exemption review"* ]]' 'status must list the expiries and no review line'
check '[[ ${report} == *"Pins"*"codex"*"present"* && ${report} != *"DRIFT"* ]]' "status must report the pins through Rig, got:
${report}"
check '[[ ${report} == *"This workstation against the pins"*"bun"* ]]' 'status text mode must compare this workstation with the pins'

# Drift and an expiry within 14 days are marked, and cached for the banner.
in_days() { date -u -d "@$(($(date -u +%s) + $1 * 86400))" +%Y-%m-%d 2>/dev/null || date -u -r "$(($(date -u +%s) + $1 * 86400))" +%Y-%m-%d; }
soon=$(in_days 5)
echo "{\"Self\":{\"KeyExpiry\":\"${soon}T00:00:00Z\"}}" >"${state}/tailscale.json"
touch "${state}/rig-drift"
code=0
report=$(HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} bash "${scripts}/status.sh" 2>&1) || code=$?
check '[[ ${code} == 3 && ${report} == *"codex"*"drifted  DRIFT"* && ${report} == *"Tailscale node key"*"${soon}"*"EXPIRES SOON"* ]]' "status must mark drift and a near expiry without changing its outcome, got ${code}:
${report}"
cache=${host_home}/.cache/ki-agent-host/expiry
check 'grep -qx "tailscale ${soon}" "${cache}" && grep -qx "drift codex" "${cache}" && grep -qx "github -" "${cache}"' "status must cache the expiries and drift, got:
$(cat "${cache}" 2>/dev/null)"
check '[[ $(HOME=${host_home} bash "${scripts}/host/status.sh" --json --repositories "${repositories}" 2>/dev/null | jq -r "keys | join(\",\")") == "fetched,generated_at,host,outcome,problems,profile,repositories,schema,updates,workspace" ]]' 'status --json must keep its document, adding only the updates and profile members'

# The banner reads the cache and the clock alone: only date is on its PATH.
quiet_path=${work}/quiet-path
mkdir -p "${quiet_path}"
ln -s "$(command -v date)" "${quiet_path}/date"
banner() { HOME=${host_home} PATH=${quiet_path} /bin/bash -c '. "$HOME/.config/ki-agent-host/banner.sh"' 2>&1; }
shown=$(banner)
check '[[ ${shown} == *"Tailscale node key expires ${soon}"* && ${shown} == *"differ from the recipe pins: codex"* && ${shown} != *"GitHub"* && ${shown} != *"last checked"* ]]' "the banner must show the near expiry and the drift, got:
${shown}"
printf 'checked %s\ngithub %s\ntailscale -\ndrift \n' "$(($(date -u +%s) - 8 * 86400))" "$(in_days 60)" >"${cache}"
shown=$(banner)
check '[[ ${shown} == *"last checked 8 days ago"* && $(grep -c . <<<"${shown}") == 1 ]]' "the banner must flag a stale check and nothing else, got:
${shown}"
rm "${cache}"
check '[[ $(banner) == *"expiries not checked yet"* ]]' 'the banner must flag a missing check'
shown=$(HOME=${host_home} PATH=${quiet_path}:/usr/bin:/bin /bin/bash -i -c true 2>/dev/null)
check '[[ ${shown} == *"expiries not checked yet"* ]]' "an interactive shell must show the banner, got:
${shown}"
check '[[ -z $(HOME=${host_home} KI_AGENT_HOST_BANNER=1 PATH=${quiet_path}:/usr/bin:/bin /bin/bash -i -c true 2>/dev/null) ]]' 'a nested interactive shell must not repeat the banner'
rm "${state}/rig-drift" "${state}/tailscale.json"
check '[[ $(sort -u "${state}/ssh.log") == ki-techne-agent-host ]]' 'with no binding variable, SSH must reach only ki-techne-agent-host'

# The techne/host-workspace/v1 document.
code=0
document=$(HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} bash "${scripts}/status.sh" --json --connect-timeout 5 2>/dev/null) || code=$?
check '[[ ${code} == 3 ]] && jq -e ".schema == \"techne/host-workspace/v1\" and .outcome == \"at-risk\" and .fetched == false and .problems == []
  and ([.repositories[] | {path, state, dirty, unpushed}] == [
    {path: \"knowledgeislands/alpha\", state: \"at-risk\", dirty: 0, unpushed: 1},
    {path: \"knowledgeislands/beta\", state: \"clean\", dirty: 0, unpushed: 0},
    {path: \"knowledgeislands/gamma\", state: \"at-risk\", dirty: 1, unpushed: 0}])" <<<"${document}" >/dev/null' "status --json must report alpha and gamma at risk, got ${code}:
${document}"

# host_status [argument...]: the host script's document, with ${code} set.
host_status() {
  code=0
  document=$(HOME=${host_home} bash "${scripts}/host/status.sh" --json --repositories "${repositories}" "$@" 2>/dev/null) || code=$?
}
# A linked worktree's .git file is no repository, but its uncommitted files count for alpha.
git -C "${workspace}/alpha" worktree add --quiet --detach "${workspace}/alpha-review"
echo draft >"${workspace}/alpha-review/draft.md"
host_status
check '[[ ${code} == 3 ]] && jq -e "[.repositories[].path] == [\"knowledgeislands/alpha\", \"knowledgeislands/beta\", \"knowledgeislands/gamma\"]
  and (.repositories[0].dirty == 1)" <<<"${document}" >/dev/null' "a linked worktree must count for alpha and not as a repository, got ${code}:
${document}"

# --fetch updates remote-tracking refs only.
before=$(git -C "${workspace}/beta" rev-parse HEAD)
host_status --fetch
check '[[ ${code} == 3 ]] && jq -e ".fetched == true" <<<"${document}" >/dev/null' "status --fetch must report a fetch, got ${code}:
${document}"
check '[[ $(git -C "${workspace}/beta" rev-parse HEAD) == "${before}" ]] && grep -qx local "${workspace}/gamma/README.md"' 'status --fetch must leave the working trees alone'

host_status --expect knowledgeislands/omega
check '[[ ${code} == 4 ]] && jq -e ".outcome == \"unknown\" and .problems == [\"declared repository knowledgeislands/omega is absent\"]" <<<"${document}" >/dev/null' "an absent declared repository must make the outcome unknown, got ${code}:
${document}"

git init --quiet "${workspace}/delta"
host_status
check '[[ ${code} == 4 ]] && jq -e ".repositories[] | select(.path == \"knowledgeislands/delta\") | .state == \"unknown\" and (.problem | endswith(\"not in the declared repository list\"))" <<<"${document}" >/dev/null' "an undeclared repository must be unknown, got ${code}:
${document}"

# A repository whose Git read fails is unknown; the rest are still reported.
echo 'ref: broken' >"${workspace}/delta/.git/HEAD"
host_status --expect knowledgeislands/delta
check '[[ ${code} == 4 ]] && jq -e "(.repositories | length) == 4 and ([.repositories[] | select(.state == \"unknown\") | .path] == [\"knowledgeislands/delta\"])" <<<"${document}" >/dev/null' "a broken repository must be unknown without hiding the rest, got ${code}:
${document}"
rm -rf "${workspace}/delta"

code=0
# shellcheck disable=SC2088 # the binding carries a literal ~/ for the host.
document=$(HOME=${host_home} KI_AGENT_HOST_WORKSPACE='~/nowhere' bash "${scripts}/host/status.sh" --json --repositories "${repositories}" 2>/dev/null) || code=$?
check '[[ ${code} == 4 ]] && jq -e ".repositories == [] and (.problems | index(\"workspace ${host_home}/nowhere does not exist\"))" <<<"${document}" >/dev/null' "a missing workspace must make the outcome unknown, got ${code}:
${document}"

# OS updates. Each fixture system root stands in for a
# host's update state; none may change the outcome or exit status.
host_status
baseline_code=${code} baseline_outcome=$(jq -r .outcome <<<"${document}")
check '[[ ${baseline_code} == 3 ]] && jq -e ".updates == {os: null, pending: null, security: null, reboot_required: null,
  reboot_required_since: null, reboot_packages: null, livepatch: null}" <<<"${document}" >/dev/null' "an unreadable OS must report every update field unknown, got ${code}:
${document}"
ago() { date -d "@$(($(date +%s) - $1 * 86400))" +%Y%m%d%H%M 2>/dev/null || date -r "$(($(date +%s) - $1 * 86400))" +%Y%m%d%H%M; }
# sysroot <name> <apt-check answer, or fail>: an Ubuntu root with Ubuntu Pro unattached.
sysroot() {
  local root=${work}/sysroots/$1
  mkdir -p "${root}/etc" "${root}/usr/lib/update-notifier" "${root}/usr/bin" "${root}/var/run"
  printf 'NAME="Ubuntu"\nID=ubuntu\nID_LIKE=debian\n' >"${root}/etc/os-release"
  if [[ $2 == fail ]]; then
    stub "${root}/usr/lib/update-notifier/apt-check" 'echo "E: apt cache is locked" >&2; exit 2'
  else
    stub "${root}/usr/lib/update-notifier/apt-check" "printf '%s' '$2' >&2"
  fi
  stub "${root}/usr/bin/pro" '[[ $* == "status --format json" ]] && echo "{\"attached\":false,\"services\":[{\"name\":\"livepatch\",\"status\":null}]}"'
  echo "${root}"
}
# updates_case <name> <expected updates member as jq>
updates_case() {
  code=0 expected=$2
  document=$(HOME=${host_home} KI_AGENT_HOST_SYSROOT=${work}/sysroots/$1 bash "${scripts}/host/status.sh" --json --repositories "${repositories}" 2>/dev/null) || code=$?
  check '[[ ${code} == "${baseline_code}" ]] && jq -e ".outcome == \"${baseline_outcome}\" and .updates == (${expected})" <<<"${document}" >/dev/null' "the $1 fixture must report its updates without changing the outcome, got ${code}:
$(jq -c .updates <<<"${document}" 2>/dev/null || echo "${document}")"
}

sysroot none '0;0' >/dev/null
updates_case none '{os: "ubuntu", pending: 0, security: 0, reboot_required: false, reboot_required_since: null, reboot_packages: null, livepatch: "disabled"}'

sysroot security '34;12' >/dev/null
updates_case security '{os: "ubuntu", pending: 34, security: 12, reboot_required: false, reboot_required_since: null, reboot_packages: null, livepatch: "disabled"}'

root=$(sysroot reboot '30;6')
printf '*** System restart required ***\n' >"${root}/var/run/reboot-required"
printf 'linux-base\nlibc6\nlinux-base\n' >"${root}/var/run/reboot-required.pkgs"
touch -t "$(ago 3)" "${root}/var/run/reboot-required"
since=$(date -u -r "${root}/var/run/reboot-required" +%Y-%m-%dT%H:%M:%SZ)
updates_case reboot "{os: \"ubuntu\", pending: 30, security: 6, reboot_required: true, reboot_required_since: \"${since}\", reboot_packages: [\"libc6\", \"linux-base\"], livepatch: \"disabled\"}"

root=$(sysroot livepatch '2;0')
mkdir -p "${root}/snap/bin"
stub "${root}/snap/bin/canonical-livepatch" '[[ $* == "status --format json" ]] && echo "{\"Status\":[{\"Livepatch\":{\"State\":\"applied\"}}]}"'
updates_case livepatch '{os: "ubuntu", pending: 2, security: 0, reboot_required: false, reboot_required_since: null, reboot_packages: null, livepatch: "applied"}'

root=$(sysroot no-pro '0;0')
rm "${root}/usr/bin/pro"
updates_case no-pro '{os: "ubuntu", pending: 0, security: 0, reboot_required: false, reboot_required_since: null, reboot_packages: null, livepatch: "unsupported"}'

sysroot apt-fails fail >/dev/null
updates_case apt-fails '{os: "ubuntu", pending: null, security: null, reboot_required: false, reboot_required_since: null, reboot_packages: null, livepatch: "disabled"}'

# macOS reads the last scan's catalogue only, and has no reboot-required flag.
root=${work}/sysroots/macos
mkdir -p "${root}/System/Library/CoreServices" "${root}/usr/sbin"
: >"${root}/System/Library/CoreServices/SystemVersion.plist"
stub "${root}/usr/sbin/softwareupdate" '[[ $* == "--list --no-scan" ]] || exit 2
printf "Software Update Tool\n\nSoftware Update found the following new or updated software:\n"
printf "* Label: macOS Background Security Improvement (a)-26.1\n\tTitle: macOS Background Security Improvement (a), Version: 26.1, Size: 1024KiB, Recommended: YES, Action: restart,\n"
printf "* Label: Command Line Tools for Xcode-26.1\n\tTitle: Command Line Tools for Xcode, Version: 26.1, Size: 900000KiB, Recommended: YES,\n"'
updates_case macos '{os: "macos", pending: 2, security: 1, reboot_required: null, reboot_required_since: null, reboot_packages: null, livepatch: "unsupported"}'

# The text report and the banner: a required reboot shows at login straight
# from the flag, and security updates pending past a day from the cache.
cache=${host_home}/.cache/ki-agent-host/expiry
text=$(HOME=${host_home} KI_AGENT_HOST_SYSROOT=${work}/sysroots/reboot bash "${scripts}/host/status.sh" --repositories "${repositories}" 2>&1) || code=$?
check '[[ ${code} == "${baseline_code}" && ${text} == *"Security updates"*"6  SECURITY"* && ${text} == *"Reboot required"*"yes, since ${since} (libc6 linux-base)  REBOOT REQUIRED"* && ${text} == *"OUTCOME=${baseline_outcome}"* ]]' "the text report must show the updates without changing the outcome, got ${code}:
${text}"
check '[[ $(awk "\$1 == \"security\" { print \$2 }" "${cache}") == 6 ]]' "status must cache the pending security updates, got:
$(cat "${cache}")"
shown=$(KI_AGENT_HOST_SYSROOT=${work}/sysroots/reboot banner)
check '[[ ${shown} == *"reboot required for 3 days (linux-base libc6); run status, then stop and start the host through the provider"* && ${shown} != *"security updates pending"* ]]' "the banner must show a required reboot and no fresh security line, got:
${shown}"
first_seen=$(($(date -u +%s) - 2 * 86400))
sed -i.bak "s/^security .*/security 6 ${first_seen}/" "${cache}" && rm -f "${cache}.bak"
HOME=${host_home} KI_AGENT_HOST_SYSROOT=${work}/sysroots/security bash "${scripts}/host/status.sh" --repositories "${repositories}" >/dev/null 2>&1 || true
check 'grep -qx "security 12 ${first_seen}" "${cache}"' "status must keep when security updates were first seen, got:
$(cat "${cache}")"
shown=$(KI_AGENT_HOST_SYSROOT=${work}/sysroots/security banner)
check '[[ ${shown} == *"12 security updates pending for 2 days"* && ${shown} != *"reboot required"* ]]' "the banner must flag security updates pending past a day, got:
${shown}"
HOME=${host_home} KI_AGENT_HOST_SYSROOT=${work}/sysroots/none bash "${scripts}/host/status.sh" --repositories "${repositories}" >/dev/null 2>&1 || true
check 'grep -qx "security 0 -" "${cache}" && [[ -z $(KI_AGENT_HOST_SYSROOT=${work}/sysroots/none banner) ]]' "with no updates the banner must stay quiet, got:
$(KI_AGENT_HOST_SYSROOT=${work}/sysroots/none banner)"
rm "${cache}"

# The binding owner's profile payload (TECHNE-TOOLS-OPS-015). A payload is
# rendered for the OS these checks run on, as a host's would be for Linux.
case $(uname -s) in Darwin) target_os=macos ;; *) target_os=linux ;; esac
# payload <dir> <revision> <path:mode>...: a techne/host-profile/v1 payload
# whose files hold their own path, with ~/.codex/AGENTS.md and a Rig fragment
# declaring the owner profile when listed.
payload() {
  local dir=$1 revision=$2 entry path mode files='[]'
  shift 2
  rm -rf "${dir}"
  mkdir -p "${dir}/home"
  for entry in "$@"; do
    path=${entry%:*} mode=${entry##*:}
    mkdir -p "$(dirname "${dir}/home/${path}")"
    echo "# owner ${path}" >"${dir}/home/${path}"
    files=$(jq -c --arg path "${path}" --arg mode "${mode}" '. + [{path: $path, mode: $mode}]' <<<"${files}")
  done
  if [[ -f ${dir}/home/.config/rig/conf.d/owner.toml ]]; then
    printf '%s\n' '[category.owner]' 'name = "Owner tools"' '' '[profile.owner]' 'name = "Owner"' 'kind = "complete"' '' \
      '[tool.ripgrep]' 'category = "owner"' 'profiles = ["owner"]' 'install.provider = "mise"' 'install.locator = "ripgrep@14"' \
      >"${dir}/home/.config/rig/conf.d/owner.toml"
  fi
  jq -n --arg revision "${revision}" --arg os "${target_os}" --argjson files "${files}" \
    '{schema: "techne/host-profile/v1", revision: $revision, target_os: $os, files: $files, removed: []}
     + (if any($files[]; .path == ".config/rig/conf.d/owner.toml") then {rig: {fragment: ".config/rig/conf.d/owner.toml", profile: "owner"}} else {} end)' \
    >"${dir}/manifest.json"
}
# manifest <dir> <jq filter>: amend a payload's manifest.
manifest() { jq "$2" "$1/manifest.json" >"$1/manifest.json.new" && mv "$1/manifest.json.new" "$1/manifest.json"; }
profiled() { HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} AGENT_HOST_PROFILE=$1 bash "${scripts}/setup.sh" 2>&1; }
# A content check for the other OS runs without --os, as setup's does.
os_flags=(--os "${target_os}")
validate() { python3 "${scripts}/host/profile-check.py" ${os_flags[@]+"${os_flags[@]}"} --hostname "$(hostname)" --shell zsh \
  --workspace '~/workspaces/kit' --recipe-rig "${repo_root}/recipes/agent-host/rig.toml" "$1" 2>&1; }

owner=${work}/payload
payload "${owner}" r1 .claude/CLAUDE.md:0644 .claude/delegation.md:0644 .codex/AGENTS.md:0600 .zshrc:0644 \
  .local/bin/mgit:0755 .config/gh/hosts.yml:0600 .config/rig/conf.d/owner.toml:0644
check 'validate "${owner}" >/dev/null' "a valid payload must pass the validator, got:
$(validate "${owner}")"
applied=$(profiled "${owner}") || { echo "${applied}" >&2; echo 'agent-host-workspace: setup with a payload failed' >&2; exit 1; }
check 'cmp -s "${owner}/home/.claude/CLAUDE.md" "${host_home}/.claude/CLAUDE.md" && cmp -s "${owner}/home/.zshrc" "${host_home}/.zshrc"' 'the payload'"'"'s files must be written'
check '[[ -x ${host_home}/.local/bin/mgit && $(stat -c %a "${host_home}/.config/gh/hosts.yml" 2>/dev/null || stat -f %Lp "${host_home}/.config/gh/hosts.yml") == 600 ]]' 'each file must get its mode'
codex=$(cat "${host_home}/.codex/AGENTS.md")
check '[[ ${codex} == *"Push where you worked"*"# The binding owner'"'"'s instructions"*"# owner .codex/AGENTS.md"* ]]' "Codex must read the recipe's rules, then the owner's, got:
${codex}"
check '[[ $(stat -c %a "${host_home}/.codex/AGENTS.md" 2>/dev/null || stat -f %Lp "${host_home}/.codex/AGENTS.md") == 600 ]]' 'the composed Codex file must take the owner'"'"'s mode'
check 'cmp -s "${owner}/manifest.json" "${host_home}/.local/state/ki-agent-host/profile-manifest.json"' 'the applied manifest must be recorded'
check '[[ $(cat "${state}/rig-apply.log") == "apply --profile owner --scope tools" && ${applied} == *"changed  personal tools of Rig profile owner"* ]]' "rig apply must install the owner's profile, got:
${applied}"
again=$(profiled "${owner}") || true
check '[[ ${again} == *"CHANGES=0 "* ]]' "an unchanged payload must change nothing, got:
${again}"

# The owner's tools reach status as a signal apart from the pins.
host_status
check '[[ ${code} == "${baseline_code}" ]] && jq -e ".outcome == \"${baseline_outcome}\" and .profile == {revision: \"r1\", rig_profile: \"owner\", drift: []}" <<<"${document}" >/dev/null' "status must report the applied payload, got ${code}:
${document}"
touch "${state}/owner-drift"
host_status
check '[[ ${code} == "${baseline_code}" ]] && jq -e ".outcome == \"${baseline_outcome}\" and .profile.drift == [\"ripgrep\"]" <<<"${document}" >/dev/null' "personal-tool drift must not change the outcome, got ${code}:
${document}"
text=$(HOME=${host_home} bash "${scripts}/host/status.sh" --repositories "${repositories}" 2>&1) || true
check '[[ ${text} == *"Profile"*"Revision"*"r1"*"ripgrep"*"drifted  DRIFT"* ]]' "status must list personal-tool drift, got:
${text}"
shown=$(banner)
check '[[ ${shown} == *"personal tools differ from your profile: ripgrep"* && ${shown} != *"recipe pins"* ]]' "the banner must name personal-tool drift apart from the pins, got:
${shown}"
rm "${state}/owner-drift" "${host_home}/.cache/ki-agent-host/expiry"

# A run without a payload keeps the applied files and installs no tools.
plain=$(setup) || true
check '[[ -f ${host_home}/.claude/delegation.md && $(cat "${host_home}/.codex/AGENTS.md") == "${codex}" ]]' 'a run without a payload must keep the applied files'
check '[[ ${plain} == *"revision r1 stays applied"* && $(grep -c . "${state}/rig-apply.log") == 2 ]]' "a run without a payload must not run rig apply, got:
${plain}"

# A dropped file goes only when the last payload installed it; a dropped
# ~/.codex/AGENTS.md leaves Codex the recipe's rules alone.
echo '# hand-made' >"${host_home}/.claude/unrecorded.md"
dropped=${work}/payload-r2
payload "${dropped}" r2 .claude/CLAUDE.md:0644 .zshrc:0644 .local/bin/mgit:0755 .config/gh/hosts.yml:0600 .config/rig/conf.d/owner.toml:0644
manifest "${dropped}" '.removed = [".claude/delegation.md", ".claude/unrecorded.md", ".codex/AGENTS.md"]'
check 'validate "${dropped}" >/dev/null' 'a payload with removals must pass the validator'
removal=$(profiled "${dropped}") || true
check '[[ ! -e ${host_home}/.claude/delegation.md ]] && ls "${host_home}"/.local/state/ki-agent-host/backups/*/delegation.md >/dev/null' "a file the last payload installed must be backed up and removed, got:
${removal}"
check 'grep -qx "# hand-made" "${host_home}/.claude/unrecorded.md"' 'a file no payload installed must stay'
check '[[ $(stat -c %a "${host_home}/.codex/AGENTS.md" 2>/dev/null || stat -f %Lp "${host_home}/.codex/AGENTS.md") == 644 ]]' 'the recipe-only Codex file must be 0644'
check '[[ $(cat "${host_home}/.codex/AGENTS.md") == *"Push where you worked"* && $(cat "${host_home}/.codex/AGENTS.md") != *"binding owner"* ]]' 'Codex must keep only the recipe'"'"'s rules once the owner'"'"'s file is dropped'

# refused <name> <expected problem> <payload>: the validator names the problem.
refused() {
  local found expected=$2
  found=$(validate "$3") && { check false "the validator must refuse $1"; return; }
  check '[[ ${found} == *"${expected}"* ]]' "the validator must refuse $1 with \"$2\", got:
${found}"
}
bad=${work}/payload-bad
payload "${bad}" bad .bashrc:0644
refused 'a recipe start-up file' 'reserved destination ~/.bashrc' "${bad}"
payload "${bad}" bad .zshenv:0644
refused 'the chosen shell'"'"'s start-up file' 'reserved destination ~/.zshenv' "${bad}"
payload "${bad}" bad .config/mise/config.toml:0644
refused 'a recipe directory' 'reserved destination ~/.config/mise/' "${bad}"
payload "${bad}" bad workspaces/kit/notes.md:0644
refused 'the workspace' 'reserved destination ~/workspaces/kit/' "${bad}"
payload "${bad}" bad .zshrc:0644
manifest "${bad}" '.files[0].path = "../.zshrc"'
refused 'a path outside home' 'has an empty, . or .. component' "${bad}"
manifest "${bad}" '.files[0].path = ".zshrc" | .files[0].mode = "0777"'
refused 'a wide mode' 'has mode' "${bad}"
payload "${bad}" bad .zshrc:0644
ln -s /etc/passwd "${bad}/home/.passwd"
refused 'a symbolic link' '~/.passwd is a symbolic link' "${bad}"
payload "${bad}" bad .zshrc:0644
echo extra >"${bad}/home/.extra"
refused 'an unlisted file' '~/.extra is not listed' "${bad}"
payload "${bad}" bad .zshrc:0644
printf 'aws_access_key_id = %s%s\n' AKIA ABCDEFGHIJKLMNOP >>"${bad}/home/.zshrc"
refused 'a secret' 'matches the AWS access key pattern' "${bad}"
payload "${bad}" bad .zshrc:0644
os_flags=()
manifest "${bad}" '.target_os = "linux"'
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"${bad}/home/.zshrc"
refused 'a macOS path on Linux' "contains '/opt/homebrew', invalid on linux" "${bad}"
manifest "${bad}" '.target_os = "macos"'
printf '# owner\nalias copy=pbcopy\n' >"${bad}/home/.zshrc"
check 'validate "${bad}" >/dev/null' 'pbcopy must be valid on macOS'
manifest "${bad}" '.target_os = "linux"'
refused 'an unguarded pbcopy on Linux' 'uses pbcopy without a guard' "${bad}"
printf '# owner\ncommand -v pbcopy >/dev/null && alias copy=pbcopy\n' >"${bad}/home/.zshrc"
check 'validate "${bad}" >/dev/null' 'a guarded pbcopy must be valid on Linux'
os_flags=(--os "${target_os}")
payload "${bad}" bad .zshrc:0644
manifest "${bad}" '.target_os = (if .target_os == "linux" then "macos" else "linux" end)'
refused 'another OS' 'not this' "${bad}"
payload "${bad}" bad .zshrc:0644
manifest "${bad}" '.target_host = "ki-techne-elsewhere"'
refused 'another host' 'the payload is for host ki-techne-elsewhere' "${bad}"
payload "${bad}" bad .config/rig/conf.d/owner.toml:0644
sed -i.bak 's/"mise"/"my-adapter"/' "${bad}/home/.config/rig/conf.d/owner.toml" && rm "${bad}/home/.config/rig/conf.d/owner.toml.bak"
refused 'a custom provider' "uses provider 'my-adapter', which is not built in" "${bad}"
payload "${bad}" bad .config/rig/conf.d/owner.toml:0644
echo 'services = ["ripgrep.service"]' >>"${bad}/home/.config/rig/conf.d/owner.toml"
refused 'a managed resource' 'declares a managed resource (services)' "${bad}"
payload "${bad}" bad .config/rig/conf.d/owner.toml:0644
printf '\n[tool.bun]\ncategory = "owner"\ninstall.provider = "mise"\n' >>"${bad}/home/.config/rig/conf.d/owner.toml"
refused 'a recipe identity' "redeclares the recipe's tool bun" "${bad}"
payload "${bad}" bad .config/rig/conf.d/owner.toml:0644
printf '\n[provider.mine]\nexecutable = "x"\n' >>"${bad}/home/.config/rig/conf.d/owner.toml"
refused 'a provider table' 'declares a [provider] table' "${bad}"

# setup refuses before sending; converge refuses another host's payload
# before writing anything.
payload "${bad}" bad .bashrc:0644
: >"${state}/ssh.log"
sent=$(profiled "${bad}") && check false 'setup must refuse an invalid payload'
check '[[ ${sent} == *"nothing was sent"* && ! -s ${state}/ssh.log ]]' "setup must refuse an invalid payload before SSH, got:
${sent}"
payload "${bad}" r3 .claude/CLAUDE.md:0644
manifest "${bad}" '.target_host = "ki-techne-elsewhere"'
before=$(cat "${host_home}/.local/state/ki-agent-host/profile-manifest.json")
sent=$(profiled "${bad}") && check false 'converge must refuse another host'"'"'s payload'
check '[[ ${sent} == *"profile payload refused; nothing was changed"* && $(cat "${host_home}/.local/state/ki-agent-host/profile-manifest.json") == "${before}" ]]' "converge must refuse another host's payload unchanged, got:
${sent}"
check '[[ ! -s ${state}/curl.log ]]' 'a refused payload must reach nothing'

# Shell paths (TECHNE-TOOLS-OPS-015). Interactive bash hands off to the chosen
# shell unless it runs a command or an escape hatch is set; the start-up
# files give every shell the environment.
handoff() { : >"${state}/handoff.log"; HOME=${host_home} PATH=${quiet_path}:/usr/bin:/bin "$@" </dev/null >/dev/null 2>&1 || true; cat "${state}/handoff.log"; }
check '[[ $(handoff /bin/bash -i) == "zsh -l" ]]' 'an interactive bash login must hand off to zsh'
check '[[ -z $(handoff /bin/bash -i -c true) ]]' 'bash running a command must not hand off'
check '[[ -z $(handoff env SSH_ORIGINAL_COMMAND=true /bin/bash -i) ]]' 'an SSH command must not hand off'
check '[[ -z $(handoff env KI_AGENT_HOST_NO_HANDOFF=1 /bin/bash -i) ]]' 'KI_AGENT_HOST_NO_HANDOFF must keep bash'
check '[[ -z $(handoff env KI_AGENT_HOST_HANDED_OFF=1 /bin/bash -i) ]]' 'a session that has handed off must not hand off again'
touch "${host_home}/.config/ki-agent-host/no-handoff"
check '[[ -z $(handoff /bin/bash -i) ]]' 'the no-handoff file must keep bash'
rm "${host_home}/.config/ki-agent-host/no-handoff"
environment='printf "%s %s\n" "${KNIP_DISABLE_RAW_TRANSFER:-}" "${ki_mise_hook:-none}"; case ":$PATH:" in *"/.local/share/mise/shims:"*) echo shims ;; esac'
hook=$(HOME=${host_home} PATH=/usr/bin:/bin /bin/sh -c '. "$HOME/.config/husky/init.sh"; '"${environment}" 2>/dev/null)
check '[[ ${hook} == "1 none"*"shims" ]]' "a Git hook through husky must get the environment, got: ${hook}"
real_zsh=$(PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin command -v zsh || true)
if [[ -n ${real_zsh} ]]; then
  for mode in -c -lc -ic; do
    found=$(HOME=${host_home} PATH=${quiet_path}:/usr/bin:/bin env -u ZDOTDIR "${real_zsh}" "${mode}" "${environment}" 2>/dev/null </dev/null | grep -v '^ki-agent-host:' || true)
    expected='1 none'
    [[ ${mode} == -ic ]] && expected='1 zsh'
    check '[[ ${found} == "${expected}"*"shims" ]]' "zsh ${mode} must get the environment and, interactive, mise, got: ${found}"
  done
else
  echo 'agent-host-workspace: zsh is not installed here, so the zsh start-up checks are skipped' >&2
fi
found=$(HOME=${host_home} KI_AGENT_HOST_NO_HANDOFF=1 PATH=${quiet_path}:/usr/bin:/bin /bin/bash -i -c "${environment}" 2>/dev/null | grep -v '^ki-agent-host:' || true)
check '[[ ${found} == "1 bash"*"shims" ]]' "interactive bash must get the environment and mise, got: ${found}"

# Choosing bash drops the hand-off and the ~/.zshenv block, keeping the rest.
echo '# my zshenv' >>"${host_home}/.zshenv"
bash_run=$(HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} AGENT_HOST_SHELL=bash bash "${scripts}/setup.sh" 2>&1) || true
check '! grep -qF "hand-off" "${host_home}/.bashrc" && [[ $(cat "${host_home}/.zshenv") == "# my zshenv" && $(cat "${host_home}/.local/state/ki-agent-host/shell") == bash ]]' "choosing bash must drop the hand-off and the zsh block, got:
${bash_run}"
check '[[ -z $(handoff /bin/bash -i) ]]' 'with bash chosen, nothing may hand off'
refused_shell=$(HOME=${mac_home} AGENT_HOST_SHELL=fish bash "${scripts}/setup.sh" 2>&1) && check false 'setup must refuse an unsupported shell'
check '[[ ${refused_shell} == *"fish is not a supported shell"* ]]' 'setup must name the refused shell'

# A chosen shell that is not installed leaves bash with a warning.
nozsh=${work}/nozsh
mkdir -p "${nozsh}"
IFS=: read -ra dirs <<<"${PATH}"
for dir in "${dirs[@]}"; do
  for tool in "${dir}"/*; do
    name=${tool##*/}
    [[ ${name} == zsh || -e ${nozsh}/${name} || ! -x ${tool} ]] || ln -s "${tool}" "${nozsh}/${name}"
  done
done
missing=$(HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} PATH=${nozsh} bash "${scripts}/setup.sh" 2>&1) || true
check '[[ ${missing} == *"warning  zsh is not installed, so interactive sessions stay in bash"* ]] && ! grep -qF "hand-off" "${host_home}/.bashrc"' "a missing shell must warn and make no hand-off, got:
${missing}"
setup >/dev/null || true
check 'grep -qF "hand-off" "${host_home}/.bashrc"' 'zsh, once found again, must get the hand-off back'


# A second binding's provider-neutral values, with no AWS variable set:
# another SSH name and workspace.
: >"${state}/ssh.log"
rm -f "${state}/ki-active" "${state}/ki-dev"
bound() {
  (
    unset "${!AWS_@}" EXPECTED_AWS_ACCOUNT
    # shellcheck disable=SC2088 # the binding carries a literal ~/ for the host.
    HOME=${mac_home} AGENT_HOST_TAILSCALE_NAME=scratch-tail \
      AGENT_HOST_REPOSITORIES=${repositories} KI_AGENT_HOST_WORKSPACE='~/elsewhere' bash "${scripts}/$1" 2>&1
  )
}
bound_setup=$(bound setup.sh) || { echo "${bound_setup}" >&2; echo 'agent-host-workspace: setup with binding values failed' >&2; exit 1; }
check '[[ -d ${host_home}/elsewhere/knowledgeislands/alpha/.git && ${bound_setup} == *"cloned knowledgeislands/alpha"* ]]' 'setup must clone into the binding workspace on the host'
bound_report=$(bound status.sh) || true
check '[[ ${bound_report} == *"Repositories under ${host_home}/elsewhere"* && ${bound_report} == *"OUTCOME=clean"* ]]' "status must report the binding workspace, got:
${bound_report}"
check '[[ $(sort -u "${state}/ssh.log") == scratch-tail ]]' 'with binding values, SSH must reach only the binding Tailscale name'

check '[[ ! -e ${state}/curl.log ]]' 'nothing may reach the network'

((failures == 0)) || exit 1
echo 'agent-host workspace checks passed'

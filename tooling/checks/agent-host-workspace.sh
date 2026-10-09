#!/usr/bin/env bash
# check() evaluates its single-quoted conditions later, so they must not expand here.
# shellcheck disable=SC2016,SC2034
set -euo pipefail

# Offline checks for the agent-host workspace scripts (TECHNE-TOOLS-OPS-011,
# TECHNE-TOOLS-OPS-013, TECHNE-TOOLS-OPS-014, TECHNE-TOOLS-OPS-022). A temporary
# Mac home and host home, local Git origins and stub ssh, chezmoi, curl,
# tailscale, mise, ki, rig, bun, codex and claude stand in for the network and
# the host; an empty system root, or a fixture one, stands in for its OS.

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
stub "${stubs}/chezmoi" 'echo "# instructions from $(basename "$2")"'
stub "${stubs}/curl" "echo \"\$*\" >>'${state}/curl.log'; exit 1"
# tailscale reports a node key only once a check writes one.
stub "${stubs}/tailscale" "cat '${state}/tailscale.json' 2>/dev/null"

# Host-side tools, where converge.sh expects them.
key='$(pwd | tr / _)'
stub "${host_home}/.local/bin/mise" "case \$1 in
  --version) echo '2026.10.4 linux-x64 (stub)' ;;
  ls) [[ -f '${state}'/mise-${key} ]] || echo 'node 24 (missing)' ;;
  install) touch '${state}'/mise-${key} ;;
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
stub "${host_home}/.local/bin/codex" 'echo "codex-cli 0.161.0"'
stub "${host_home}/.local/bin/claude" 'echo "2.2.0 (Claude Code)"'
# rig status reports Codex drifted once a check asks for it.
stub "${host_home}/.local/bin/rig" "case \$1 in
  --version) echo 'rig 0.4.0' ;;
  status) [[ \$* == 'status --profile direct-host --format json' ]] || exit 2
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
check '[[ ${on_host} == *"no changes"* && ${on_host} == *"Claude instructions: not staged"* ]]' "a run on the host must change nothing, got:
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
check '[[ $(head -n 1 "${host_home}/.claude/CLAUDE.md") == "<!-- Rendered for ki-techne-agent-host "* ]] && grep -qx "# instructions from memory-scope.md" "${host_home}/.claude/memory-scope.md"' 'Claude instructions must be rendered with a host header'
check '[[ $(HOME=${host_home} git config --global user.name) == "Test Operator" ]]' 'the Git identity must come from the Mac'
check 'grep -qx local "${workspace}/gamma/README.md"' 'gamma must keep its uncommitted change'
check '[[ $(git -C "${workspace}/beta" rev-parse HEAD) == $(git -C "${work}/origins/beta.git" rev-parse main) ]]' 'beta must match its origin'
check 'grep -q "npm:@openai/codex" "${host_home}/.config/mise/config.toml"' 'the mise pins must include Codex'

# The pins (TECHNE-TOOLS-OPS-014): converge applies the pin file's Linux and
# macOS locators alike, installs it and the provider for Rig, and renders the
# recipe's instructions and the host marker.
pins=${repo_root}/recipes/direct-host/rig.toml
check 'python3 "${repo_root}/tooling/checks/recipe-pins.py" "${pins}"' 'the pin file must declare every tool for both OSes through the observe-only provider'
for tool in bun node; do
  pin=$(python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["tool"][sys.argv[2]]["variant"]["macos"]["install"]["locator"])' "${pins}" "${tool}")
  check 'grep -qx "${tool} = \"${pin}\"" "${host_home}/.config/mise/config.toml"' "the mise configuration must pin ${tool} ${pin} exactly"
done
check 'grep -qx "\"npm:@openai/codex\" = \"0.161.0\"" "${host_home}/.config/mise/config.toml"' 'the mise configuration must pin Codex from the pin file'
check 'cmp -s "${pins}" "${host_home}/.config/rig/rig.toml"' 'the pin file must be Rig'"'"'s configuration'
check '[[ -x ${host_home}/.local/share/rig/providers/direct-host-pins ]] && cmp -s "${repo_root}/recipes/direct-host/rig-pins.sh" "${host_home}/.local/share/rig/providers/direct-host-pins"' 'the provider must be installed for Rig'
for file in .claude/rules/ki-agent-host.md .codex/AGENTS.md; do
  check 'grep -qF "Push where you worked" "${host_home}/${file}" && grep -qF "roadmap writing checkout" "${host_home}/${file}"' "${file} must carry the two-checkout and writing-checkout rules"
done
check 'grep -qx "recipe = \"direct-host\"" "${host_home}/.config/ki/host-marker"' 'converge must write the host marker'

# The provider's verdicts against stub tools.
tools=${work}/tools
mkdir -p "${tools}"
stub "${tools}/bun" 'echo 1.4.2'
stub "${tools}/node" 'echo v24.20.1'
stub "${tools}/claude" 'echo "2.1.300 (Claude Code)"'
stub "${tools}/codex" 'echo "codex-cli (no version)"'
verdict() { PATH="${tools}:/usr/bin:/bin" "${repo_root}/recipes/direct-host/rig-pins.sh" rig-provider-v1 observe direct-host-pins "$@"; }
check '[[ $(verdict bun exact 1.4.2) == present && $(verdict node exact 24.21.0) == drifted ]]' 'the provider must compare exact pins'
check '[[ $(verdict claude minimum 2.1.285) == present && $(verdict claude minimum 2.2.0) == drifted ]]' 'the provider must compare minimum pins numerically'
check '[[ $(verdict codex exact 0.161.0) == unknown && $(verdict rig exact 0.4.0) == missing ]]' 'the provider must report unknown and missing tools'
check '! PATH="${tools}:/usr/bin:/bin" "${repo_root}/recipes/direct-host/rig-pins.sh" rig-provider-v1 apply direct-host-pins bun exact 1.4.2 >/dev/null 2>&1' 'the provider must refuse anything but observing'
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
check '[[ $(HOME=${host_home} bash "${scripts}/host/status.sh" --json --repositories "${repositories}" 2>/dev/null | jq -r "keys | join(\",\")") == "fetched,generated_at,host,outcome,problems,repositories,schema,updates,workspace" ]]' 'status --json must keep its document, adding only the updates member'

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

# The techne/host-workspace/v1 document (TECHNE-TOOLS-OPS-013).
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

# OS updates (TECHNE-TOOLS-OPS-022). Each fixture system root stands in for a
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

# A second binding's provider-neutral values, with no AWS variable set
# (TECHNE-TOOLS-OPS-012): another SSH name, workspace and instruction set.
: >"${state}/ssh.log"
rm -f "${state}/ki-active" "${state}/ki-dev"
bound() {
  (
    unset "${!AWS_@}" EXPECTED_AWS_ACCOUNT
    # shellcheck disable=SC2088 # the binding carries a literal ~/ for the host.
    HOME=${mac_home} AGENT_HOST_NAME=ki-techne-scratch AGENT_HOST_TAILSCALE_NAME=scratch-tail \
      AGENT_HOST_REPOSITORIES=${repositories} KI_AGENT_HOST_WORKSPACE='~/elsewhere' \
      AGENT_HOST_INSTRUCTIONS='CLAUDE.md markdown.md' bash "${scripts}/$1" 2>&1
  )
}
rm "${host_home}"/.claude/*.md
bound_setup=$(bound setup.sh) || { echo "${bound_setup}" >&2; echo 'agent-host-workspace: setup with binding values failed' >&2; exit 1; }
check '[[ -d ${host_home}/elsewhere/knowledgeislands/alpha/.git && ${bound_setup} == *"cloned knowledgeislands/alpha"* ]]' 'setup must clone into the binding workspace on the host'
check '[[ $(head -n 1 "${host_home}/.claude/CLAUDE.md") == "<!-- Rendered for ki-techne-scratch "* ]]' 'instructions must be rendered for the binding host name'
check '[[ $(cd "${host_home}/.claude" && echo *.md) == "CLAUDE.md markdown.md" ]]' 'only the configured instruction files may be rendered'
bound_report=$(bound status.sh) || true
check '[[ ${bound_report} == *"Repositories under ${host_home}/elsewhere"* && ${bound_report} == *"OUTCOME=clean"* ]]' "status must report the binding workspace, got:
${bound_report}"
check '[[ $(sort -u "${state}/ssh.log") == scratch-tail ]]' 'with binding values, SSH must reach only the binding Tailscale name'
refused=$(HOME=${mac_home} AGENT_HOST_INSTRUCTIONS='../secrets.md' bash "${scripts}/setup.sh" 2>&1) && check false 'setup must refuse an instruction path'
check '[[ ${refused} == *"is not a Markdown file name"* ]]' 'setup must name the refused instruction file'

check '[[ ! -e ${state}/curl.log ]]' 'nothing may reach the network'

((failures == 0)) || exit 1
echo 'agent-host workspace checks passed'

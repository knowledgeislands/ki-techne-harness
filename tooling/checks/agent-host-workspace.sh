#!/usr/bin/env bash
# check() evaluates its single-quoted conditions later, so they must not expand here.
# shellcheck disable=SC2016,SC2034
set -euo pipefail

# Offline checks for the agent-host workspace scripts (TECHNE-TOOLS-OPS-011,
# TECHNE-TOOLS-OPS-013). A temporary Mac home and host home, local Git origins
# and stub ssh, chezmoi, curl, tailscale, mise, ki, bun, codex and claude stand
# in for the network and the host.

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
stub "${stubs}/tailscale" 'exit 1'

# Host-side tools, where converge.sh expects them.
key='$(pwd | tr / _)'
stub "${host_home}/.local/bin/mise" "case \$1 in
  --version) echo '2026.10.3 linux-x64 (stub)' ;;
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
  --version) echo 0.7.1 ;;
  bootstrap) [[ \$2 == --refresh || ! -f '${state}/ki-agents' ]] && detect; render; mkdir -p \"\$HOME/.claude/skills\"; ln -sfn /stub/ki-next \"\$HOME/.claude/skills/ki-next\" ;;
  dev) case \$3 in
      set) [[ -f '${state}/ki-active' ]] && { echo 'ki: error: local development is active' >&2; exit 1; }
        printf '[locals.\"%s\"]\npath = \"%s\"\n' \"\$4\" \"\$5\" >'${state}/ki-dev' ;;
      on) touch '${state}/ki-active' ;;
    esac; render ;;
  registry) if [[ \$2 == list ]]; then cat '${state}/registry' 2>/dev/null; else echo \"\$4\" >>'${state}/registry'; fi ;;
  repo) if [[ \$3 == diag ]]; then
      if [[ -f '${state}/repaired' ]]; then echo 'summary: REPAIRABLE=0 UNREPAIRABLE=0'; else echo 'summary: REPAIRABLE=1 UNREPAIRABLE=0'; fi
    else touch '${state}/repaired'; fi ;;
esac"
stub "${host_home}/.local/bin/bun" 'if [[ -d node_modules ]]; then echo "Checked 1 install across 1 package (no changes)"; else mkdir node_modules; echo "1 package installed"; fi'
stub "${host_home}/.local/bin/codex" 'echo "codex-cli 0.160.1"'
stub "${host_home}/.local/bin/claude" 'echo "2.1.0 (Claude Code)"'

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
check 'grep -qF "\"chatgpt-codex\"" "${host_home}/.config/ki/config.toml"' 'ki must configure the Codex runtime'
check '[[ -f ${state}/repaired ]]' 'repairable estate projections must be repaired'

git -C "${workspace}/alpha" -c user.name=t -c user.email=t@example.invalid commit --quiet --allow-empty -m local
code=0
report=$(HOME=${mac_home} AGENT_HOST_REPOSITORIES=${repositories} bash "${scripts}/status.sh" 2>&1) || code=$?
check '[[ ${code} == 3 && ${report} == *"summary: REPOSITORIES=3 AT_RISK=2 UNKNOWN=0 OUTCOME=at-risk"* ]]' "status must flag alpha and gamma and exit 3, got ${code}:
${report}"
check '[[ ${report} == *"Exemption review"*"2026-11-06"*"no lapse"* && ${report} == *"GitHub token"* ]]' 'status must list the expiry dates'
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

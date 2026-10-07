#!/usr/bin/env bash
# Converge techne's workspace on the agent host to the declared state
# (TECHNE-TOOLS-OPS-011). Runs on the host as techne, without sudo; setup.sh
# stages and runs it from the Mac, and it also runs from the host's harness
# clone. It prints each change and ends with "no changes" when there were none.
set -euo pipefail

# Pins, matching the Mac.
ki_version=0.7.1
mise_version=2026.10.3
bun_version=1.4.2
node_version=24
codex_version=0.160.1
harness_id=knowledgeislands/ki-agentic-harness
harness_path=knowledgeislands/ki-agentic-harness

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=${KI_AGENT_HOST_WORKSPACE:-$HOME/workspaces/kit}
repositories=${script_dir}/repositories.txt
claude_source=${script_dir}/claude
pull=false
git_name=''
git_email=''

usage() {
  echo 'usage: converge.sh [--pull] [--git-name <name> --git-email <email>] [--repositories <file>]' >&2
  exit 2
}

while (($#)); do
  case $1 in
    --pull) pull=true ;;
    --git-name) git_name=${2:?}; shift ;;
    --git-email) git_email=${2:?}; shift ;;
    --repositories) repositories=${2:?}; shift ;;
    *) usage ;;
  esac
  shift
done

env_file=${HOME}/.config/ki-agent-host/env.sh
backup_dir=${HOME}/.local/state/ki-agent-host/backups/$(date -u +%Y%m%dT%H%M%SZ)
block_start='# >>> ki-agent-host (TECHNE-TOOLS-OPS-011) >>>'
block_end='# <<< ki-agent-host <<<'

changes=0
skips=0
warnings=0
failures=0
changed() { echo "changed  $*"; changes=$((changes + 1)); }
skipped() { echo "skipped  $*"; skips=$((skips + 1)); }
warn() { echo "warning  $*"; warnings=$((warnings + 1)); }
fail() { echo "failed   $*" >&2; failures=$((failures + 1)); }

# Keep the previous copy of any file this run replaces or removes.
backup() {
  [[ -e $1 ]] || return 0
  mkdir -p "${backup_dir}"
  cp -p "$1" "${backup_dir}/$(basename "$1")"
}

# write_file <path> <content>: replace the file only when its content differs.
write_file() {
  if [[ -f $1 ]] && cmp -s "$1" <(printf '%s\n' "$2"); then
    return 1
  fi
  backup "$1"
  mkdir -p "$(dirname "$1")"
  printf '%s\n' "$2" >"$1.tmp.$$"
  mv "$1.tmp.$$" "$1"
}

# Remove this script's block and the blocks the hand set-up of 2026-10-07 left,
# then squeeze blank lines.
strip_managed() {
  awk -v start="${block_start}" -v end="${block_end}" '
    $0 == start { managed = 1; next }
    $0 == end { managed = 0; next }
    $0 == "# ki-agent-host: mise shims (TECHNE-TOOLS-OPS-011)" { legacy = 1; next }
    $0 == "# end ki-agent-host: mise shims" { legacy = 0; next }
    managed || legacy { next }
    $0 == "[ -f \"$HOME/.ki-host-env\" ] && . \"$HOME/.ki-host-env\"" { next }
    /^eval "\$\(.*\/mise activate bash\)"$/ { next }
    { print }
  ' "$1" | cat -s | awk 'NF { started = 1 } started'
}

# Put one block that sources the environment file at the top of a start-up file,
# above Ubuntu's interactive-only return in .bashrc.
source_block() {
  local file=$1 rest content
  rest=''
  [[ -f ${file} ]] && rest=$(strip_managed "${file}")
  content="${block_start}
[ -f \"\$HOME/.config/ki-agent-host/env.sh\" ] && . \"\$HOME/.config/ki-agent-host/env.sh\"
${block_end}"
  [[ -n ${rest} ]] && content="${content}

${rest}"
  if write_file "${file}" "${content}"; then
    changed "${file} sources the agent-host environment"
  fi
}

# shell environment ------------------------------------------------------------

# The quoted variables expand in the shells that source the file, not here.
# shellcheck disable=SC2016
env_content='# Agent-host shell environment, managed by ki-techne-harness
# operations/aws/agent-host (TECHNE-TOOLS-OPS-011); rerun setup rather than
# editing. ~/.profile, ~/.bashrc and husky'"'"'s init.sh source it, so login,
# non-interactive and Git hook shells all find the pinned tools.
case ":$PATH:" in *":$HOME/.local/share/mise/shims:"*) ;; *) PATH="$HOME/.local/share/mise/shims:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH

# oxc-parser'"'"'s raw transfer reserves 6 GiB of virtual memory, which the
# kernel refuses on a 4 GB host without swap, so knip fails without this.
export KNIP_DISABLE_RAW_TRANSFER=1

# Interactive bash also gets mise'"'"'s hook, which applies repository [env].
if [ -n "${BASH_VERSION:-}" ] && [ -z "${ki_agent_host_mise_active:-}" ] && [ -x "$HOME/.local/bin/mise" ]; then
  case $- in *i*) ki_agent_host_mise_active=1; eval "$("$HOME/.local/bin/mise" activate bash)" ;; esac
fi'

if write_file "${env_file}" "${env_content}"; then
  changed "${env_file}"
fi
source_block "${HOME}/.profile"
source_block "${HOME}/.bashrc"
source_block "${HOME}/.config/husky/init.sh"
if [[ -e ${HOME}/.ki-host-env ]]; then
  backup "${HOME}/.ki-host-env"
  rm -f "${HOME}/.ki-host-env"
  changed "${HOME}/.ki-host-env removed, folded into the agent-host environment"
fi

PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"
export PATH KNIP_DISABLE_RAW_TRANSFER=1

# git --------------------------------------------------------------------------

git_setting() {
  if [[ $(git config --global --get "$1" || true) != "$2" ]]; then
    git config --global "$1" "$2"
    changed "git ${1}"
  fi
}

if [[ -n ${git_name} && -n ${git_email} ]]; then
  git_setting user.name "${git_name}"
  git_setting user.email "${git_email}"
elif [[ -z $(git config --global --get user.email || true) ]]; then
  warn 'git identity unset; run setup.sh from the Mac, which passes it'
fi
git_setting pull.rebase true
git_setting branch.autosetuprebase always
git_setting init.defaultBranch main
git_setting push.default current
git_setting core.autocrlf input

# mise, Bun, Node and Codex -----------------------------------------------------

mise=${HOME}/.local/bin/mise
if [[ $("${mise}" --version 2>/dev/null | awk '{ print $1 }') != "${mise_version}" ]]; then
  curl -fsSL https://mise.run | MISE_VERSION="v${mise_version}" MISE_INSTALL_PATH="${mise}" sh >/dev/null
  changed "mise ${mise_version}"
fi

mise_config="# Managed by ki-techne-harness operations/aws/agent-host (TECHNE-TOOLS-OPS-011).
[tools]
bun = \"${bun_version}\"
node = \"${node_version}\"
\"npm:@openai/codex\" = \"${codex_version}\""
if write_file "${HOME}/.config/mise/config.toml" "${mise_config}"; then
  changed "${HOME}/.config/mise/config.toml pins"
fi

# install_tools <directory> <label>: install what that directory's configuration lacks.
install_tools() {
  local missing
  missing=$(cd "$1" && "${mise}" ls --missing 2>/dev/null || true)
  [[ -z ${missing} ]] && return 0
  if (cd "$1" && "${mise}" install --yes >/dev/null 2>&1) || (cd "$1" && "${mise}" install --yes >/dev/null); then
    changed "mise tools for $2"
  else
    fail "mise install for $2"
  fi
}
install_tools "${HOME}" 'the global pins'

# ki CLI ---------------------------------------------------------------------------

ki=${HOME}/.local/bin/ki
if [[ $("${ki}" --version 2>/dev/null || true) != "${ki_version}" ]]; then
  installer=$(mktemp)
  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --output "${installer}" \
    "https://raw.githubusercontent.com/knowledgeislands/tools-ki/v${ki_version}/install.sh"
  bash "${installer}" "v${ki_version}" >/dev/null
  rm -f "${installer}"
  changed "ki ${ki_version}"
fi

# repositories ---------------------------------------------------------------------

declared=()
while read -r path url _; do
  [[ -z ${path} || ${path} == \#* ]] && continue
  declared+=("${path}")
  dir=${workspace}/${path}
  if [[ ! -e ${dir} ]]; then
    mkdir -p "$(dirname "${dir}")"
    if git clone --quiet "${url}" "${dir}"; then
      changed "cloned ${path}"
    else
      fail "clone ${path}"
      continue
    fi
  elif [[ ! -d ${dir}/.git ]]; then
    fail "${path} exists but is not a Git checkout"
    continue
  fi
  actual_url=$(git -C "${dir}" remote get-url origin 2>/dev/null || true)
  [[ ${actual_url} == "${url}" ]] || warn "${path} origin is ${actual_url:-unset}, declared ${url}"

  if [[ -n $(git -C "${dir}" status --porcelain) ]]; then
    skipped "${path}: uncommitted changes, left as it is"
    continue
  fi

  if ${pull}; then
    git -C "${dir}" fetch --quiet origin || fail "fetch ${path}"
    if git -C "${dir}" rev-parse --quiet --verify '@{u}' >/dev/null; then
      if [[ $(git -C "${dir}" rev-parse HEAD) != $(git -C "${dir}" rev-parse '@{u}') ]]; then
        if git -C "${dir}" merge-base --is-ancestor HEAD '@{u}'; then
          git -C "${dir}" merge --ff-only --quiet '@{u}'
          changed "fast-forwarded ${path}"
        else
          skipped "${path}: has commits its upstream lacks, not fast-forwarded"
        fi
      fi
    else
      skipped "${path}: branch has no upstream, not fast-forwarded"
    fi
  fi

  if [[ -f ${dir}/mise.toml ]]; then
    if ! (cd "${dir}" && "${mise}" trust --show 2>/dev/null) | grep -q ': trusted$'; then
      "${mise}" trust --quiet "${dir}/mise.toml"
      changed "trusted ${path}/mise.toml"
    fi
    install_tools "${dir}" "${path}"
  fi

  if [[ -f ${dir}/package.json && ( -f ${dir}/bun.lock || -f ${dir}/bun.lockb ) ]]; then
    if output=$(cd "${dir}" && bun install --frozen-lockfile 2>&1); then
      [[ ${output} == *'no changes'* ]] || changed "dependencies in ${path}"
    else
      printf '%s\n' "${output}" | tail -n 5 >&2
      fail "bun install in ${path}"
    fi
  fi
done <"${repositories}"

# KI bootstrap, local harness, registry and repository skills ---------------------

# ki bootstrap configures every agent whose home exists; ~/.agents is Codex's.
if [[ ! -d ${HOME}/.agents ]]; then
  mkdir -p "${HOME}/.agents"
  changed "${HOME}/.agents for the Codex runtime"
fi

ki_state() {
  cat "${HOME}/.config/ki/config.toml" 2>/dev/null || true
  local link
  for link in "${HOME}"/.claude/skills/* "${HOME}"/.agents/skills/*; do
    [[ -e ${link} || -L ${link} ]] && printf '%s -> %s\n' "${link}" "$(readlink "${link}" || true)"
  done
  return 0
}

ki_run() {
  local output
  if ! output=$("${ki}" "$@" 2>&1); then
    printf '%s\n' "${output}" | tail -n 10 >&2
    fail "ki $*"
    return 1
  fi
}

# ki refuses to re-set a local checkout while it is active, so set it only when
# the configuration does not already record this path.
local_path() {
  awk -v section="[locals.\"${harness_id}\"]" '
    $0 == section { inside = 1; next }
    /^\[/ { inside = 0 }
    inside && $1 == "path" { sub(/^[^=]*= *"/, ""); sub(/"$/, ""); print }
  ' "${HOME}/.config/ki/config.toml" 2>/dev/null || true
}

# Plain bootstrap reuses the configured agents; --refresh detects new ones, such
# as Codex once ~/.agents exists, and keeps harnesses, skills and local checkouts.
bootstrap_args=()
for agent in claude-code:.claude chatgpt-codex:.agents; do
  [[ -d ${HOME}/${agent#*:} ]] || continue
  grep -qF "\"${agent%%:*}\"" "${HOME}/.config/ki/config.toml" 2>/dev/null || bootstrap_args=(--refresh)
done

before=$(ki_state)
if ki_run bootstrap ${bootstrap_args[@]+"${bootstrap_args[@]}"}; then
  if [[ $(local_path) == "${workspace}/${harness_path}" ]] ||
    ki_run dev local set "${harness_id}" "${workspace}/${harness_path}"; then
    ki_run dev local on "${harness_id}" || true
  fi
fi
[[ $(ki_state) == "${before}" ]] || changed 'ki agents, core skills and local harness'

registered=$("${ki}" registry list 2>/dev/null || true)
for path in "${declared[@]}"; do
  dir=${workspace}/${path}
  [[ -f ${dir}/.ki.toml ]] || continue
  grep -qxF "${dir}" <<<"${registered}" && continue
  ki_run registry add --repo "${dir}" && changed "registered ${path}"
done

# diag exits 0 while projections are repairable, so read its summary instead.
estate_healthy() {
  local summary
  summary=$("${ki}" repo --estate diag 2>&1 | grep -o 'REPAIRABLE=[0-9]* UNREPAIRABLE=[0-9]*' | tail -n 1 || true)
  [[ ${summary} == 'REPAIRABLE=0 UNREPAIRABLE=0' ]]
}
if ! estate_healthy; then
  ki_run repo --estate repair && changed 'repository skill projections'
  estate_healthy || warn 'ki repo --estate diag still reports problems'
fi

# Claude Code ------------------------------------------------------------------------

if [[ -d ${claude_source} ]]; then
  for source in "${claude_source}"/*.md; do
    target=${HOME}/.claude/$(basename "${source}")
    if write_file "${target}" "$(cat "${source}")"; then
      changed "${target}"
    fi
  done
else
  skipped 'Claude instructions: not staged here; run setup.sh from the Mac'
fi

# KI keeps auto-memory off unless a repository opts in (ki-housekeeping-claude).
settings=${HOME}/.claude/settings.json
if [[ $(jq '.autoMemoryEnabled' "${settings}" 2>/dev/null || true) != false ]]; then
  current='{}'
  [[ -s ${settings} ]] && current=$(cat "${settings}")
  updated=$(jq '.autoMemoryEnabled = false' <<<"${current}")
  write_file "${settings}" "${updated}" && changed "${settings} autoMemoryEnabled false"
fi

command -v claude >/dev/null || warn 'Claude Code is not installed; the stack boot script installs it'
command -v codex >/dev/null || fail 'codex is not on PATH'

echo "summary: CHANGES=${changes} SKIPPED=${skips} WARNINGS=${warnings} FAILURES=${failures}"
((changes)) || echo 'no changes'
((failures == 0))

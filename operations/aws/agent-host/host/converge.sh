#!/usr/bin/env bash
# Converge techne's workspace on the agent host to the declared state
# (TECHNE-TOOLS-OPS-011, TECHNE-TOOLS-OPS-014, TECHNE-TOOLS-OPS-022,
# TECHNE-TOOLS-OPS-015). Runs on the host as techne, without sudo; setup.sh
# stages and runs it from the operator's workstation, with the binding owner's
# profile payload when one is supplied, and it also runs from the host's
# harness clone, where it keeps the last applied payload's files. It prints
# each change and ends with "no changes" when there were none.
set -euo pipefail

harness_id=knowledgeislands/ki-agentic-harness
harness_path=knowledgeislands/ki-agentic-harness

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# The recipe's files: staged beside this script by setup.sh, or in the harness
# checkout this script runs from.
recipe_dir=${script_dir}
[[ -f ${recipe_dir}/rig.toml ]] || recipe_dir=$(cd "${script_dir}/../../../.." && pwd)/recipes/agent-host

# Pins (TECHNE-TOOLS-OPS-014): the recipe's Rig profile declares them; each
# tool's locator for this OS is its version.
pins=${recipe_dir}/rig.toml
case $(uname -s) in
  Linux) os=linux ;;
  Darwin) os=macos ;;
  *) echo "converge.sh: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac
pin() {
  local value
  value=$(awk -v table="[tool.$1]" -v key="variant.${os}.install.locator" '
    $0 == table { inside = 1; next }
    /^\[/ { inside = 0 }
    inside && $1 == key { gsub(/"/, "", $3); print $3 }
  ' "${pins}")
  [[ -n ${value} ]] || { echo "converge.sh: ${pins} has no ${os} pin for $1" >&2; exit 1; }
  printf '%s\n' "${value}"
}
rig_version=$(pin rig)
ki_version=$(pin ki)
mise_version=$(pin mise)
bun_version=$(pin bun)
node_version=$(pin node)
codex_version=$(pin codex)
workspace=${KI_AGENT_HOST_WORKSPACE:-$HOME/workspaces/kit}
# shellcheck disable=SC2088 # a literal ~/ from the binding means this home.
[[ ${workspace} == '~/'* ]] && workspace=${HOME}/${workspace#'~/'}
repositories=${script_dir}/repositories.txt
# The owner's techne/host-profile/v1 payload, staged here by setup.sh.
profile_dir=${script_dir}/profile
state_dir=${HOME}/.local/state/ki-agent-host
applied_manifest=${state_dir}/profile-manifest.json
# The interactive shell; a run without --shell keeps the last run's choice.
shell_choice=$(cat "${state_dir}/shell" 2>/dev/null || echo zsh)
pull=false
git_name=''
git_email=''

usage() {
  echo 'usage: converge.sh [--pull] [--git-name <name> --git-email <email>] [--repositories <file>] [--shell bash|zsh]' >&2
  exit 2
}

while (($#)); do
  case $1 in
    --pull) pull=true ;;
    --git-name) git_name=${2:?}; shift ;;
    --git-email) git_email=${2:?}; shift ;;
    --repositories) repositories=${2:?}; shift ;;
    --shell) shell_choice=${2:?}; shift ;;
    *) usage ;;
  esac
  shift
done
case ${shell_choice} in bash | zsh) ;; *) usage ;; esac

# The payload is checked again here before anything is written; a refused
# payload, including one rendered for another host, stops the run unchanged.
profile=false
if [[ -d ${profile_dir} ]]; then
  checked_workspace=${workspace}
  # shellcheck disable=SC2088 # the validator reserves the workspace by its ~/ form.
  [[ ${checked_workspace} == "${HOME}/"* ]] && checked_workspace="~/${checked_workspace#"${HOME}/"}"
  if ! python3 "${script_dir}/profile-check.py" --os "${os}" --hostname "$(hostname)" --shell "${shell_choice}" \
    --workspace "${checked_workspace}" --recipe-rig "${pins}" "${profile_dir}"; then
    echo 'failed   profile payload refused; nothing was changed' >&2
    exit 1
  fi
  profile=true
fi

env_file=${HOME}/.config/ki-agent-host/env.sh
backup_dir=${HOME}/.local/state/ki-agent-host/backups/$(date -u +%Y%m%dT%H%M%SZ)
block_start='# >>> ki-agent-host (TECHNE-TOOLS-OPS-011) >>>'
block_end='# <<< ki-agent-host <<<'
handoff_start='# >>> ki-agent-host hand-off (TECHNE-TOOLS-OPS-015) >>>'
handoff_end='# <<< ki-agent-host hand-off <<<'

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
  awk -v start="${block_start}" -v end="${block_end}" -v hstart="${handoff_start}" -v hend="${handoff_end}" '
    $0 == start || $0 == hstart { managed = 1; next }
    $0 == end || $0 == hend { managed = 0; next }
    $0 == "# ki-agent-host: mise shims (TECHNE-TOOLS-OPS-011)" { legacy = 1; next }
    $0 == "# end ki-agent-host: mise shims" { legacy = 0; next }
    managed || legacy { next }
    $0 == "[ -f \"$HOME/.ki-host-env\" ] && . \"$HOME/.ki-host-env\"" { next }
    /^eval "\$\(.*\/mise activate bash\)"$/ { next }
    { print }
  ' "$1" | cat -s | awk 'NF { started = 1 } started'
}

# Put one block that sources the environment file at the top of a start-up file,
# above Ubuntu's interactive-only return in .bashrc, followed by any extra
# managed block given.
source_block() {
  local file=$1 extra=${2:-} rest content
  rest=''
  [[ -f ${file} ]] && rest=$(strip_managed "${file}")
  content="${block_start}
[ -f \"\$HOME/.config/ki-agent-host/env.sh\" ] && . \"\$HOME/.config/ki-agent-host/env.sh\"
${block_end}"
  [[ -n ${extra} ]] && content="${content}
${extra}"
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
# operations/aws/agent-host (TECHNE-TOOLS-OPS-011, TECHNE-TOOLS-OPS-015); rerun
# setup rather than editing. ~/.profile, ~/.bashrc, husky'"'"'s init.sh and, for
# zsh, ~/.zshenv source it, so login, non-interactive and Git hook shells all
# find the pinned tools. It stays sourceable from any POSIX shell.
case ":$PATH:" in *":$HOME/.local/share/mise/shims:"*) ;; *) PATH="$HOME/.local/share/mise/shims:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH

# oxc-parser'"'"'s raw transfer reserves 6 GiB of virtual memory, which the
# kernel refuses on a 4 GB host without swap, so knip fails without this.
export KNIP_DISABLE_RAW_TRANSFER=1

# Interactive bash and zsh also get mise'"'"'s hook, which applies repository [env].
if [ -z "${ki_agent_host_mise_active:-}" ] && [ -x "$HOME/.local/bin/mise" ]; then
  case $- in *i*)
    if [ -n "${BASH_VERSION:-}" ]; then
      ki_agent_host_mise_active=1; eval "$("$HOME/.local/bin/mise" activate bash)"
    elif [ -n "${ZSH_VERSION:-}" ]; then
      ki_agent_host_mise_active=1; eval "$("$HOME/.local/bin/mise" activate zsh)"
    fi ;;
  esac
fi

# An interactive session prints the expiry banner once, from the status cache.
case $- in *i*)
  if [ -z "${KI_AGENT_HOST_BANNER:-}" ] && [ -r "$HOME/.config/ki-agent-host/banner.sh" ]; then
    KI_AGENT_HOST_BANNER=1; export KI_AGENT_HOST_BANNER; . "$HOME/.config/ki-agent-host/banner.sh"
  fi ;;
esac'

# The banner reads only host/status.sh'"'"'s cache, the reboot-required flag and
# the clock: no network or credential call (ODR-KI-ARCADIA-001 expiries,
# TECHNE-TOOLS-OPS-022 updates).
# shellcheck disable=SC2016
banner_content='# Agent-host login banner, managed by ki-techne-harness
# operations/aws/agent-host (TECHNE-TOOLS-OPS-014, TECHNE-TOOLS-OPS-022); rerun
# setup rather than editing. Reads only the cache host/status.sh writes and the
# local reboot-required flag; KI_AGENT_HOST_SYSROOT serves the offline checks.
ki_agent_host_banner() {
  now=$(date -u +%s)
  flag=${KI_AGENT_HOST_SYSROOT:-}/var/run/reboot-required
  if [ -e "$flag" ]; then
    packages=""
    if [ -r "$flag.pkgs" ]; then
      while read -r package; do
        case " $packages " in *" $package "*) ;; *) packages="${packages:+$packages }$package" ;; esac
      done <"$flag.pkgs"
    fi
    since=$(date -u -r "$flag" +%s 2>/dev/null) || since=$now
    echo "ki-agent-host: reboot required for $(( (now - since) / 86400 )) days${packages:+ ($packages)}; run status, then stop and start the host through the provider"
  fi
  cache=$HOME/.cache/ki-agent-host/expiry
  if [ ! -r "$cache" ]; then
    echo "ki-agent-host: expiries not checked yet; run status from the operator'"'"'s workstation"
    return 0
  fi
  while read -r key value since; do
    case $key in
      checked)
        age=$(( (now - value) / 86400 ))
        [ "$age" -ge 7 ] && echo "ki-agent-host: expiries last checked $age days ago; run status from the operator'"'"'s workstation" ;;
      github|tailscale)
        case $value in [0-9]*) ;; *) continue ;; esac
        target=$(date -u -d "$value" +%s 2>/dev/null || date -u -j -f %Y-%m-%d "$value" +%s 2>/dev/null) || continue
        days=$(( (target - now) / 86400 ))
        label="GitHub token"; [ "$key" = tailscale ] && label="Tailscale node key"
        [ "$days" -le 14 ] && echo "ki-agent-host: $label expires $value ($days days)" ;;
      drift)
        [ -n "$value" ] && echo "ki-agent-host: tools differ from the recipe pins: $value; rerun setup" ;;
      personal)
        [ -n "$value" ] && echo "ki-agent-host: personal tools differ from your profile: $value; rerun setup with your payload" ;;
      security)
        case $value$since in *[!0-9]*|"") continue ;; esac
        [ "$value" -gt 0 ] && [ $(( now - since )) -ge 86400 ] &&
          echo "ki-agent-host: $value security updates pending for $(( (now - since) / 86400 )) days; unattended upgrades may be failing" ;;
    esac
  done <"$cache"
  return 0
}
ki_agent_host_banner
unset -f ki_agent_host_banner'

if write_file "${env_file}" "${env_content}"; then
  changed "${env_file}"
fi
banner_file=${HOME}/.config/ki-agent-host/banner.sh
if write_file "${banner_file}" "${banner_content}"; then
  changed "${banner_file}"
fi
# The chosen shell (TECHNE-TOOLS-OPS-015): an interactive bash session hands
# off to it as a login shell. A command (bash -c, or an SSH command) never
# hands off, and KI_AGENT_HOST_NO_HANDOFF or the no-handoff file keeps bash, so
# a broken personal start-up file cannot shut the operator out.
handoff=''
if [[ ${shell_choice} != bash ]]; then
  if shell_path=$(command -v "${shell_choice}"); then
    handoff="${handoff_start}
case \$- in *i*)
  if [ -z \"\${BASH_EXECUTION_STRING:-}\" ] && [ -z \"\${SSH_ORIGINAL_COMMAND:-}\" ] && [ -z \"\${KI_AGENT_HOST_NO_HANDOFF:-}\" ] && [ -z \"\${KI_AGENT_HOST_HANDED_OFF:-}\" ] &&
    [ ! -e \"\$HOME/.config/ki-agent-host/no-handoff\" ] && [ -x '${shell_path}' ]; then
    KI_AGENT_HOST_HANDED_OFF=1; export KI_AGENT_HOST_HANDED_OFF; exec '${shell_path}' -l
  fi ;;
esac
${handoff_end}"
  else
    warn "${shell_choice} is not installed, so interactive sessions stay in bash; the provider installs it (TECHNE-TOOLS-OPS-017)"
  fi
fi
source_block "${HOME}/.profile"
source_block "${HOME}/.bashrc" "${handoff}"
source_block "${HOME}/.config/husky/init.sh"
if [[ ${shell_choice} == zsh ]]; then
  source_block "${HOME}/.zshenv"
elif [[ -f ${HOME}/.zshenv ]] && grep -qxF "${block_start}" "${HOME}/.zshenv"; then
  # Back to bash: zsh no longer needs the block, and the rest is the owner's.
  if write_file "${HOME}/.zshenv" "$(strip_managed "${HOME}/.zshenv")"; then
    changed "${HOME}/.zshenv no longer sources the agent-host environment"
  fi
fi
mkdir -p "${state_dir}"
printf '%s\n' "${shell_choice}" >"${state_dir}/shell"
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

mise_config="# Managed by ki-techne-harness operations/aws/agent-host from the recipe's pins (TECHNE-TOOLS-OPS-014).
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

# Rig and the pins profile ------------------------------------------------------------

# Rig only observes the pins until TECHNE-TOOLS-OPS-018 (ADR-KI-ARCADIA-003 stage 1).
rig=${HOME}/.local/bin/rig
if [[ $("${rig}" --version 2>/dev/null || true) != "rig ${rig_version}" ]]; then
  installer=$(mktemp)
  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --output "${installer}" \
    "https://raw.githubusercontent.com/knowledgeislands/tools-rig/v${rig_version}/install.sh"
  RIG_INSTALL_DIR=${HOME}/.local/bin bash "${installer}" "v${rig_version}" >/dev/null
  rm -f "${installer}"
  changed "rig ${rig_version}"
fi
if write_file "${HOME}/.config/rig/rig.toml" "$(cat "${pins}")"; then
  changed "${HOME}/.config/rig/rig.toml pins"
fi
provider=${HOME}/.local/share/rig/providers/agent-host-pins
if write_file "${provider}" "$(cat "${recipe_dir}/rig-pins.sh")"; then
  changed "${provider}"
fi
[[ -x ${provider} ]] || chmod 755 "${provider}"
# The provider's name before the recipe was renamed agent-host.
if [[ -e ${HOME}/.local/share/rig/providers/direct-host-pins ]]; then
  rm -f "${HOME}/.local/share/rig/providers/direct-host-pins"
  changed "${HOME}/.local/share/rig/providers/direct-host-pins removed"
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
  if ki_run repo --estate repair; then
    changed 'repository skill projections'
  else
    echo '         a checkout may be behind origin; rerun setup with --pull' >&2
  fi
  estate_healthy || warn 'ki repo --estate diag still reports problems'
fi

# Host instructions and marker -------------------------------------------------------

# The recipe's own rules reach both runtimes, with or without the owner's files.
# Codex reads one global file, so ~/.codex/AGENTS.md is composed: the recipe's
# rules first, then the owner's file from the payload under its own heading.
instructions=$(cat "${recipe_dir}/host-instructions.md")
header='<!-- Rendered by ki-techne-harness operations/aws/agent-host from recipes/agent-host/host-instructions.md; rerun setup rather than editing. -->'
if write_file "${HOME}/.claude/rules/ki-agent-host.md" "${header}

${instructions}"; then
  changed "${HOME}/.claude/rules/ki-agent-host.md"
fi
codex_owner=${state_dir}/profile-codex-AGENTS.md
if ${profile}; then
  if jq -e '.files[] | select(.path == ".codex/AGENTS.md")' "${profile_dir}/manifest.json" >/dev/null; then
    mkdir -p "${state_dir}"
    cp "${profile_dir}/home/.codex/AGENTS.md" "${codex_owner}.tmp.$$"
    chmod "$(jq -r '.files[] | select(.path == ".codex/AGENTS.md") | .mode' "${profile_dir}/manifest.json")" "${codex_owner}.tmp.$$"
    mv "${codex_owner}.tmp.$$" "${codex_owner}"
  else
    rm -f "${codex_owner}"
  fi
fi
codex_content="${header}

${instructions}"
if [[ -f ${codex_owner} ]]; then
  codex_content="${codex_content}

# The binding owner's instructions

<!-- From the binding owner's profile payload; edit its source on the operator's workstation and rerun setup. -->

$(cat "${codex_owner}")"
fi
if write_file "${HOME}/.codex/AGENTS.md" "${codex_content}"; then
  changed "${HOME}/.codex/AGENTS.md"
fi
# The composed file takes the owner's mode, such as 0600 for a private file.
codex_mode=644
[[ -f ${codex_owner} ]] && codex_mode=$(stat -c %a "${codex_owner}" 2>/dev/null || stat -f %Lp "${codex_owner}")
if [[ $(stat -c %a "${HOME}/.codex/AGENTS.md" 2>/dev/null || stat -f %Lp "${HOME}/.codex/AGENTS.md") != "${codex_mode}" ]]; then
  chmod "${codex_mode}" "${HOME}/.codex/AGENTS.md"
  changed "${HOME}/.codex/AGENTS.md mode ${codex_mode}"
fi

# ODR-KI-ARCADIA-001: the operator's workstation checkout is the roadmap
# writing checkout; KI-TOOL-CLI-115 has ki refuse roadmap writes where this is.
marker="# ki agent-host marker, managed by ki-techne-harness operations/aws/agent-host.
# This machine is an agent host of the agent-host recipe, not a roadmap writing
# checkout: roadmap writes belong to the operator's workstation checkout.
recipe = \"agent-host\""
if write_file "${HOME}/.config/ki/host-marker" "${marker}"; then
  changed "${HOME}/.config/ki/host-marker"
fi

# The binding owner's profile payload (TECHNE-TOOLS-OPS-015) ----------------------

# The payload's files, each written as this user with its mode. The composed
# ~/.codex/AGENTS.md is written above.
if ${profile}; then
  while IFS=$'\t' read -r path mode; do
    [[ ${path} == .codex/AGENTS.md ]] && continue
    target=${HOME}/${path}
    if write_file "${target}" "$(cat "${profile_dir}/home/${path}")"; then
      changed "${target}"
    fi
    if [[ $(stat -c %a "${target}" 2>/dev/null || stat -f %Lp "${target}") != "${mode#0}" ]]; then
      chmod "${mode}" "${target}"
      changed "${target} mode ${mode}"
    fi
  done < <(jq -r '.files[] | [.path, .mode] | @tsv' "${profile_dir}/manifest.json")

  # Remove a path the source dropped only when the last applied payload
  # installed it; anything else at that path is not this script's.
  while IFS= read -r path; do
    [[ -z ${path} || ${path} == .codex/AGENTS.md ]] && continue
    target=${HOME}/${path}
    if [[ -f ${target} ]] && jq -e --arg path "${path}" '.files[] | select(.path == $path)' "${applied_manifest}" >/dev/null 2>&1; then
      backup "${target}"
      rm -f "${target}"
      changed "${target} removed, dropped from the profile"
    fi
  done < <(jq -r '.removed[]' "${profile_dir}/manifest.json")
fi

# The chezmoi cat path of TECHNE-TOOLS-OPS-011 rendered personal files into
# ~/.claude with this header; one the payload does not deliver is removed, so a
# run without a payload leaves the recipe layer alone.
for target in "${HOME}"/.claude/*.md; do
  [[ -f ${target} ]] || continue
  head -n 1 "${target}" | grep -q "^<!-- Rendered for .* from the Mac's chezmoi source" || continue
  backup "${target}"
  rm -f "${target}"
  changed "${target} removed, rendered by the retired chezmoi cat path"
done

if ${profile}; then
  revision=$(jq -r '.revision' "${profile_dir}/manifest.json")
  if ! cmp -s "${profile_dir}/manifest.json" "${applied_manifest}"; then
    mkdir -p "${state_dir}"
    cp "${profile_dir}/manifest.json" "${applied_manifest}.tmp.$$"
    mv "${applied_manifest}.tmp.$$" "${applied_manifest}"
    changed "profile payload revision ${revision}"
  fi

  # The owner's personal tools, through Rig's built-in providers only. Rig
  # counts a tool it re-verifies as completed, so the tools' state before the
  # apply tells a change from none.
  rig_profile=$(jq -r '.rig.profile // empty' "${profile_dir}/manifest.json")
  if [[ -n ${rig_profile} ]]; then
    before=$(RIG_PROGRESS=never RIG_OUTCOME=never "${rig}" status --profile "${rig_profile}" --format json 2>/dev/null </dev/null || true)
    if output=$(RIG_PROGRESS=never "${rig}" apply --profile "${rig_profile}" --scope tools 2>&1 </dev/null); then
      if ! jq -e '(.tools | length > 0) and all(.tools[]; .state == "present")' >/dev/null 2>&1 <<<"${before}"; then
        changed "personal tools of Rig profile ${rig_profile}"
      fi
    else
      printf '%s\n' "${output}" | tail -n 10 >&2
      fail "rig apply --profile ${rig_profile}"
    fi
  fi
elif [[ -f ${applied_manifest} ]]; then
  skipped "profile payload: none staged; revision $(jq -r '.revision' "${applied_manifest}") stays applied"
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

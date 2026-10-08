#!/usr/bin/env bash
# Read-only report of work on the agent host that exists nowhere else, and of
# what expires and has drifted from the pins (TECHNE-TOOLS-OPS-011,
# TECHNE-TOOLS-OPS-013, TECHNE-TOOLS-OPS-014). Changes nothing but the expiry
# cache the login banner reads; with --fetch it also updates remote-tracking refs.
#
# usage: status.sh [--json] [--fetch] [--repositories <file>] [--expect <path>]...
#
# Work is safe only once it is in Git on a remote (ODR-KI-ARCADIA-001). The
# outcome is clean (exit 0), at-risk (3) or unknown (4); 1 means the script
# itself failed. The inventory fails closed: a missing workspace, an absent
# declared repository, an undeclared one or a failed Git read is unknown.
# --json prints one techne/host-workspace/v1 document instead of the table.
set -euo pipefail
# An unexpected failure is a script failure, never a clean or at-risk outcome.
trap 'exit 1' ERR

schema=techne/host-workspace/v1
workspace=${KI_AGENT_HOST_WORKSPACE:-$HOME/workspaces/kit}
# shellcheck disable=SC2088 # a literal ~/ from the binding means this home.
[[ ${workspace} == '~/'* ]] && workspace=${HOME}/${workspace#'~/'}
# Text mode records what it finds here for the login banner.
expiry_cache=${HOME}/.cache/ki-agent-host/expiry
PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"
export GIT_TERMINAL_PROMPT=0

json=false
fetch=false
repositories=''
expected=''
# Run from a file, the declared list beside the script is the default.
[[ -f ${BASH_SOURCE[0]:-} && -f $(dirname "${BASH_SOURCE[0]}")/repositories.txt ]] &&
  repositories=$(dirname "${BASH_SOURCE[0]}")/repositories.txt

usage() {
  echo 'usage: status.sh [--json] [--fetch] [--repositories <file>] [--expect <path>]...' >&2
  exit 1
}

while (($#)); do
  case $1 in
    --json) json=true ;;
    --fetch) fetch=true ;;
    --repositories) repositories=${2:-}; [[ -n ${repositories} ]] || usage; shift ;;
    --expect) [[ -n ${2:-} ]] || usage; expected+="$2"$'\n'; shift ;;
    *) usage ;;
  esac
  shift
done

command -v jq >/dev/null || { echo 'status.sh: jq is required' >&2; exit 1; }

problems=()
problem() { problems+=("$1"); }

if [[ -n ${repositories} ]]; then
  if [[ -r ${repositories} ]]; then
    while read -r path _; do
      [[ -z ${path} || ${path} == \#* ]] && continue
      expected+="${path}"$'\n'
    done <"${repositories}"
  else
    problem "declared repository list ${repositories} cannot be read"
  fi
fi
[[ -n ${expected} ]] || problem 'no declared repository list'
expected=$(printf '%s' "${expected}" | sort -u)

is_expected() { [[ -n ${expected} ]] && grep -qxF -- "$1" <<<"${expected}"; }

# Only working-tree .git directories are repositories; linked worktrees and
# submodules have .git files. Discovery errors are kept, not suppressed.
found=''
if [[ ! -d ${workspace} ]]; then
  problem "workspace ${workspace} does not exist"
else
  errors=$(mktemp)
  trap 'rm -f "${errors}"' EXIT
  if markers=$(find "${workspace}" -mindepth 2 -maxdepth 4 -type d -name .git -prune 2>"${errors}"); then
    while IFS= read -r marker; do
      [[ -n ${marker} ]] && marker=${marker%/.git} && found+="${marker#"${workspace}"/}"$'\n'
    done <<<"${markers}"
    found=$(printf '%s' "${found}" | sort -u)
  fi
  [[ -s ${errors} ]] && problem "discovery error: $(head -n 1 "${errors}")"
  [[ -z ${found} ]] && problem "no repository found under ${workspace}"
fi

while IFS= read -r path; do
  [[ -z ${path} ]] && continue
  grep -qxF -- "${path}" <<<"${found}" && continue
  problem "declared repository ${path} is absent"
done <<<"${expected}"

# inspect <dir>: sets branch, dirty, unpushed, stashes, ahead and behind; on a
# failed Git read sets reason and returns 1.
inspect() {
  local dir=$1 output worktree counts
  reason=''
  branch=$(git -C "${dir}" symbolic-ref --quiet --short HEAD 2>/dev/null) || branch='(detached)'
  if [[ ${fetch} == true ]] && ! git -C "${dir}" fetch --quiet --all --prune 2>/dev/null; then
    reason='fetch failed'
    return 1
  fi
  output=$(git -C "${dir}" status --porcelain 2>/dev/null) || { reason='git status failed'; return 1; }
  dirty=$(grep -c . <<<"${output}" || true)
  # A linked worktree's uncommitted files belong to this repository too.
  while IFS= read -r worktree; do
    [[ -z ${worktree} || ${worktree} == "${dir}" || ! -d ${worktree} ]] && continue
    output=$(git -C "${worktree}" status --porcelain 2>/dev/null) || { reason="git status failed in worktree ${worktree}"; return 1; }
    dirty=$((dirty + $(grep -c . <<<"${output}" || true)))
  done < <(git -C "${dir}" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | tail -n +2)
  # Commits on local branches or HEAD that no remote-tracking branch contains.
  unpushed=$(git -C "${dir}" rev-list --count HEAD --branches --not --remotes 2>/dev/null) || { reason='cannot list unpushed commits'; return 1; }
  output=$(git -C "${dir}" stash list 2>/dev/null) || { reason='cannot list stashes'; return 1; }
  stashes=$(grep -c . <<<"${output}" || true)
  ahead='' behind=''
  if counts=$(git -C "${dir}" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null); then
    read -r ahead behind <<<"${counts}"
  fi
  return 0
}

entries=$(mktemp)
trap 'rm -f "${errors:-}" "${entries}"' EXIT
rows=()
count=0
at_risk=0
unknown=0
while IFS= read -r path; do
  [[ -z ${path} ]] && continue
  count=$((count + 1))
  dir=${workspace}/${path}
  branch='' dirty=0 unpushed=0 stashes=0 ahead='' behind='' state=clean reason=''
  if ! inspect "${dir}"; then
    state=unknown
  elif ((dirty || unpushed || stashes)); then
    state=at-risk
  fi
  if ! is_expected "${path}"; then
    state=unknown
    reason=${reason:+${reason}; }'not in the declared repository list'
  fi
  case ${state} in
    at-risk) at_risk=$((at_risk + 1)) ;;
    unknown) unknown=$((unknown + 1)) ;;
  esac
  jq -cn --arg path "${path}" --arg state "${state}" --arg branch "${branch}" \
    --argjson dirty "${dirty:-0}" --argjson unpushed "${unpushed:-0}" --argjson stashes "${stashes:-0}" \
    --arg ahead "${ahead}" --arg behind "${behind}" --arg problem "${reason}" \
    '{path: $path, state: $state, branch: $branch, dirty: $dirty, unpushed: $unpushed, stashes: $stashes,
      upstream: (if $ahead == "" then null else {ahead: ($ahead | tonumber), behind: ($behind | tonumber)} end),
      problem: (if $problem == "" then null else $problem end)}' >>"${entries}"
  if [[ -n ${ahead} ]]; then upstream="ahead ${ahead}, behind ${behind}"; else upstream='none'; fi
  flag=''
  [[ ${state} == at-risk ]] && flag='  AT RISK'
  [[ ${state} == unknown ]] && flag="  UNKNOWN (${reason})"
  rows+=("$(printf '%-44s %-14s %6s %9s %6s  %s%s' "${path}" "${branch}" "${dirty}" "${unpushed}" "${stashes}" "${upstream}" "${flag}")")
done <<<"${found}"

if ((${#problems[@]} || unknown)); then
  outcome=unknown status=4
elif ((at_risk)); then
  outcome=at-risk status=3
else
  outcome=clean status=0
fi

if [[ ${json} == true ]]; then
  # host.id is the provider-defined identity of the machine. On AWS it is the
  # instance ID, which cloud-init records readably for every user.
  host_id=$(cat /var/lib/cloud/data/instance-id 2>/dev/null || true)
  printf '%s\n' ${problems[@]+"${problems[@]}"} |
    jq -n --slurpfile repositories "${entries}" --rawfile problems /dev/stdin \
      --arg schema "${schema}" --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg hostname "$(hostname)" --arg host_id "${host_id}" --arg workspace "${workspace}" \
      --argjson fetched "${fetch}" --arg outcome "${outcome}" \
      '{schema: $schema, generated_at: $generated_at,
        host: {hostname: $hostname, id: (if $host_id == "" then null else $host_id end)},
        workspace: $workspace, fetched: $fetched, outcome: $outcome,
        repositories: $repositories, problems: ($problems | split("\n") | map(select(. != "")))}'
  exit "${status}"
fi

echo "Repositories under ${workspace}"
printf '%-44s %-14s %6s %9s %6s  %s\n' REPOSITORY BRANCH DIRTY UNPUSHED STASHES "UPSTREAM (last fetch$([[ ${fetch} == true ]] && echo ', fetched now'))"
for row in ${rows[@]+"${rows[@]}"}; do echo "${row}"; done
if ((${#problems[@]})); then
  echo
  echo 'Inventory problems'
  for item in "${problems[@]}"; do echo "  ${item}"; done
fi

days_until() {
  local target now
  target=$(date -u -d "$1" +%s 2>/dev/null || date -u -j -f %Y-%m-%d "$1" +%s 2>/dev/null) || { echo '?'; return; }
  now=$(date -u +%s)
  echo $(((target - now) / 86400))
}

# soon <date>: its days left, marked when 14 or fewer (ODR-KI-ARCADIA-001).
soon() {
  local days
  days=$(days_until "$1")
  if [[ ${days} != '?' ]] && ((days <= 14)); then
    echo "${days} days  EXPIRES SOON"
  else
    echo "${days} days"
  fi
}

# Drift from the recipe's pins, through Rig's direct-host profile (unknown when
# Rig is absent or cannot read it).
echo
echo 'Pins'
drift=''
if ! command -v rig >/dev/null; then
  printf '  %s\n' 'unknown (Rig is not installed; rerun setup)'
elif ! pins=$(RIG_PROGRESS=never RIG_OUTCOME=never rig status --profile direct-host --format json 2>/dev/null </dev/null ||
  [[ $? == 1 ]]) || ! jq -e '.tools | type == "array"' >/dev/null 2>&1 <<<"${pins}"; then
  printf '  %s\n' 'unknown (rig status failed)'
else
  while IFS=$'\t' read -r tool state; do
    flag=''
    if [[ ${state} != present ]]; then
      flag='  DRIFT'
      drift+="${drift:+,}${tool}"
    fi
    printf '  %-24s %s%s\n' "${tool}" "${state}" "${flag}"
  done < <(jq -r '.tools[] | [.id, .state] | @tsv' <<<"${pins}")
fi

echo
echo 'Expiry'

# GitHub reports a fine-grained token's expiry in a response header. The token
# goes to curl through its standard-input configuration, never an argument.
github='unknown (no GitHub credential)' github_date=''
token=$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null | sed -n 's/^password=//p' || true)
if [[ -n ${token} ]]; then
  github='unknown (GitHub did not report an expiry)'
  expiry=$(printf 'header = "Authorization: Bearer %s"\n' "${token}" |
    curl --silent --show-error --max-time 15 --output /dev/null --dump-header - --config - https://api.github.com/rate_limit 2>/dev/null |
    tr -d '\r' | awk -F': ' 'tolower($1) == "github-authentication-token-expiration" { print $2 }' || true)
  [[ -n ${expiry} ]] && github_date=${expiry%% *} && github="${expiry} ($(soon "${github_date}"))"
fi
unset token
printf '  %-24s %s\n' 'GitHub token' "${github}"

tailscale_expiry='unknown (tailscale not available)' tailscale_date=''
if command -v tailscale >/dev/null && status_json=$(tailscale status --json 2>/dev/null); then
  key_expiry=$(jq -r '.Self.KeyExpiry // empty' <<<"${status_json}")
  if [[ -n ${key_expiry} ]]; then
    tailscale_date=${key_expiry%%T*}
    tailscale_expiry="${key_expiry} ($(soon "${tailscale_date}"))"
  else
    tailscale_expiry='does not expire (key expiry disabled)'
  fi
fi
printf '  %-24s %s\n' 'Tailscale node key' "${tailscale_expiry}"

# The banner's only input: the dates, drift and when they were checked.
mkdir -p "$(dirname "${expiry_cache}")"
printf 'checked %s\ngithub %s\ntailscale %s\ndrift %s\n' "$(date -u +%s)" "${github_date:--}" "${tailscale_date:--}" "${drift}" \
  >"${expiry_cache}.tmp.$$"
mv "${expiry_cache}.tmp.$$" "${expiry_cache}"

echo
echo "summary: REPOSITORIES=${count} AT_RISK=${at_risk} UNKNOWN=${unknown} OUTCOME=${outcome}"
exit "${status}"

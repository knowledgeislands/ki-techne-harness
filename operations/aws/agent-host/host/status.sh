#!/usr/bin/env bash
# Read-only report of work on the agent host that exists nowhere else, and of
# what expires (TECHNE-TOOLS-OPS-011). Changes nothing and fetches nothing.
set -euo pipefail

workspace=${KI_AGENT_HOST_WORKSPACE:-$HOME/workspaces/kit}
# shellcheck disable=SC2088 # a literal ~/ from the binding means this home.
[[ ${workspace} == '~/'* ]] && workspace=${HOME}/${workspace#'~/'}
# The standing exemption (GDR-KI-ARCADIA-004, KI-ARCADIA-GOV-023) has no lapse;
# Kris reviews it on this date under KI-ARCADIA-GOV-021.
exemption_review=2026-11-06
PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"

days_until() {
  local target now
  target=$(date -u -d "$1" +%s 2>/dev/null || date -u -j -f %Y-%m-%d "$1" +%s 2>/dev/null) || { echo '?'; return; }
  now=$(date -u +%s)
  echo $(((target - now) / 86400))
}

echo "Repositories under ${workspace}"
printf '%-44s %-14s %6s %9s %6s  %s\n' REPOSITORY BRANCH DIRTY UNPUSHED STASHES 'UPSTREAM (last fetch)'
count=0
at_risk=0
while IFS= read -r marker; do
  dir=${marker%/.git}
  name=${dir#"${workspace}"/}
  branch=$(git -C "${dir}" symbolic-ref --quiet --short HEAD || echo '(detached)')
  dirty=$(git -C "${dir}" status --porcelain | wc -l | tr -d ' ')
  # Commits on local branches or HEAD that no remote-tracking branch contains.
  unpushed=$(git -C "${dir}" rev-list --count HEAD --branches --not --remotes)
  stashes=$(git -C "${dir}" stash list | wc -l | tr -d ' ')
  if counts=$(git -C "${dir}" rev-list --left-right --count 'HEAD...@{u}' 2>/dev/null); then
    read -r ahead behind <<<"${counts}"
    upstream="ahead ${ahead}, behind ${behind}"
  else
    upstream='none'
  fi
  flag=''
  if ((dirty || unpushed || stashes)); then
    flag='  AT RISK'
    at_risk=$((at_risk + 1))
  fi
  printf '%-44s %-14s %6s %9s %6s  %s%s\n' "${name}" "${branch}" "${dirty}" "${unpushed}" "${stashes}" "${upstream}" "${flag}"
  count=$((count + 1))
done < <(find "${workspace}" -mindepth 2 -maxdepth 4 -name .git -prune 2>/dev/null | sort)

echo
echo 'Expiry'

# GitHub reports a fine-grained token's expiry in a response header. The token
# goes to curl through its standard-input configuration, never an argument.
github='unknown (no GitHub credential)'
token=$(printf 'protocol=https\nhost=github.com\n\n' | GIT_TERMINAL_PROMPT=0 git credential fill 2>/dev/null | sed -n 's/^password=//p' || true)
if [[ -n ${token} ]]; then
  github='unknown (GitHub did not report an expiry)'
  expiry=$(printf 'header = "Authorization: Bearer %s"\n' "${token}" |
    curl --silent --show-error --max-time 15 --output /dev/null --dump-header - --config - https://api.github.com/rate_limit 2>/dev/null |
    tr -d '\r' | awk -F': ' 'tolower($1) == "github-authentication-token-expiration" { print $2 }' || true)
  [[ -n ${expiry} ]] && github="${expiry} ($(days_until "${expiry%% *}") days)"
fi
unset token
printf '  %-24s %s\n' 'GitHub token' "${github}"

tailscale_expiry='unknown (tailscale not available)'
if command -v tailscale >/dev/null && status=$(tailscale status --json 2>/dev/null); then
  key_expiry=$(jq -r '.Self.KeyExpiry // empty' <<<"${status}")
  if [[ -n ${key_expiry} ]]; then
    tailscale_expiry="${key_expiry} ($(days_until "${key_expiry%%T*}") days)"
  else
    tailscale_expiry='does not expire (key expiry disabled)'
  fi
fi
printf '  %-24s %s\n' 'Tailscale node key' "${tailscale_expiry}"
printf '  %-24s %s\n' 'Exemption review' "${exemption_review} ($(days_until "${exemption_review}") days; standing, no lapse; GDR-KI-ARCADIA-004)"

echo
echo "summary: REPOSITORIES=${count} AT_RISK=${at_risk}"

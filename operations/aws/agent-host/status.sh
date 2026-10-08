#!/usr/bin/env bash
set -euo pipefail

# Report, read-only, the agent host's unlanded work per repository and what
# expires (TECHNE-TOOLS-OPS-011, TECHNE-TOOLS-OPS-013). SSH only; runs
# host/status.sh on the host against the binding's declared repositories. Text
# mode then compares this workstation's tools with the recipe's pins, as a
# signal only that never changes the exit status (TECHNE-TOOLS-OPS-014).
#
# usage: status.sh [--json] [--fetch] [--connect-timeout <seconds>]
#
# Exit status: 0 clean, 3 at-risk, 4 unknown, 1 failure, and SSH's own 255
# when the host cannot be reached.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Binding values (recipes/direct-host/recipe.toml); each default is the agent-host binding's.
host=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
repositories=${AGENT_HOST_REPOSITORIES:-${here}/host/repositories.txt}
# Empty means the host default; a leading ~/ is expanded on the host.
workspace=${KI_AGENT_HOST_WORKSPACE:-}

ssh_options=()
host_args=()
json=false
while (($#)); do
  case $1 in
    --json) json=true; host_args+=("$1") ;;
    --fetch) host_args+=("$1") ;;
    --connect-timeout)
      [[ ${2:-} =~ ^[1-9][0-9]*$ ]] || { echo 'status.sh: --connect-timeout needs whole seconds' >&2; exit 1; }
      ssh_options+=(-o "ConnectTimeout=$2" -o ServerAliveInterval=5 -o ServerAliveCountMax=2)
      shift ;;
    *) echo 'usage: status.sh [--json] [--fetch] [--connect-timeout <seconds>]' >&2; exit 1 ;;
  esac
  shift
done

# The declared set travels as arguments, so the host judges the inventory
# against the binding's list rather than the last setup's copy.
[[ -r ${repositories} ]] || { echo "status.sh: cannot read ${repositories}" >&2; exit 1; }
while read -r path _; do
  [[ -z ${path} || ${path} == \#* ]] && continue
  [[ ${path} =~ ^[A-Za-z0-9._/-]+$ ]] || { echo "status.sh: ${path} is not a repository path" >&2; exit 1; }
  host_args+=(--expect "${path}")
done <"${repositories}"

remote="bash -s --$(printf ' %q' "${host_args[@]}")"
[[ -n ${workspace} ]] && remote="KI_AGENT_HOST_WORKSPACE=$(printf '%q' "${workspace}") ${remote}"

if [[ ${json} == true ]]; then
  # shellcheck disable=SC2029 # remote is built for the host shell on purpose.
  exec ssh ${ssh_options[@]+"${ssh_options[@]}"} "${host}" "${remote}" <"${here}/host/status.sh"
fi
status=0
# shellcheck disable=SC2029 # remote is built for the host shell on purpose.
ssh ${ssh_options[@]+"${ssh_options[@]}"} "${host}" "${remote}" <"${here}/host/status.sh" || status=$?

# The workstation against the same pins, through the recipe's own provider.
recipe=${here}/../../../recipes/direct-host
case $(uname -s) in Darwin) os=macos ;; *) os=linux ;; esac
echo
echo 'This workstation against the pins (signal only)'
awk -v os="${os}" '
  /^\[tool\./ { tool = substr($1, 7, length($1) - 7) }
  $1 == "variant." os ".install.kind" { gsub(/"/, "", $3); kind[tool] = $3 }
  $1 == "variant." os ".install.locator" { gsub(/"/, "", $3); print tool, kind[tool], $3 }
' "${recipe}/rig.toml" | while read -r tool kind pin; do
  state=$("${recipe}/rig-pins.sh" rig-provider-v1 observe direct-host-pins "${tool}" "${kind}" "${pin}" 2>/dev/null </dev/null || echo unknown)
  printf '  %-24s %s (%s %s)\n' "${tool}" "${state}" "${kind}" "${pin}"
done
exit "${status}"

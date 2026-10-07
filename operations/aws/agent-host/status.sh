#!/usr/bin/env bash
set -euo pipefail

# Report, read-only, the agent host's unlanded work per repository and what
# expires (TECHNE-TOOLS-OPS-011). SSH only; runs host/status.sh on the host.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Binding values (recipes/direct-host/recipe.toml); each default is the agent-host binding's.
host=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
# Empty means the host default; a leading ~/ is expanded on the host.
workspace=${KI_AGENT_HOST_WORKSPACE:-}

remote='bash -s'
[[ -n ${workspace} ]] && remote="KI_AGENT_HOST_WORKSPACE=$(printf '%q' "${workspace}") ${remote}"
# shellcheck disable=SC2029 # remote is built for the host shell on purpose.
ssh "${host}" "${remote}" <"${here}/host/status.sh"

#!/usr/bin/env bash
set -euo pipefail

# Report, read-only, the agent host's unlanded work per repository and what
# expires (TECHNE-TOOLS-OPS-011). SSH only; runs host/status.sh on the host.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
host=${AGENT_HOST_SSH:-ki-techne-agent-host}

ssh "${host}" 'bash -s' <"${here}/host/status.sh"

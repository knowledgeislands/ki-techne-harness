#!/usr/bin/env bash
set -euo pipefail

# The agent-host template, scripts and recipe name no work record. Records are
# pruned, and these files outlast them on a host and in the provider's tags, so
# they cite only decision records (ADR-, ODR- and GDR-), which stay.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "${repo_root}"

found=$(grep -rnoE '\b([A-Z]+-)?[A-Z]+-[A-Z]+-[0-9]{3}\b' \
  infra/aws/agent-host-stack.yaml operations/aws/agent-host recipes/agent-host |
  grep -vE ':[AOG]DR-[A-Z]+-[A-Z]+-[0-9]{3}$' || true)
if [[ -n ${found} ]]; then
  printf 'agent-host-record-ids: a work record is named; cite a decision record or none:\n%s\n' "${found}" >&2
  exit 1
fi
echo 'agent-host record identifier check passed'

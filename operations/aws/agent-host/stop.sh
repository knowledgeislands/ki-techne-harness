#!/usr/bin/env bash
set -euo pipefail

# Kill switch: stops the tagged agent host, ending every session on it.
# Runs with the least-privilege agent-host profile; tailnet revocation is a
# separate step in the Tailscale admin console.
#
# usage: stop.sh [--now]
#
# Before stopping it reads the host's status with a short connect timeout and
# warns about any work at risk or unknown (ODR-KI-ARCADIA-001); it never
# refuses. --now skips the read.
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne-agent-host}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
# Binding values (recipes/agent-host/recipe.toml); each default is the agent-host binding's.
host_id=${AGENT_HOST_ID:-agent-host}
host_name=${AGENT_HOST_NAME:-ki-techne-agent-host}
# Read by status.sh for the warning.
export AGENT_HOST_TAILSCALE_NAME=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
export AGENT_HOST_REPOSITORIES=${AGENT_HOST_REPOSITORIES:-${here}/host/repositories.txt}
export KI_AGENT_HOST_WORKSPACE=${KI_AGENT_HOST_WORKSPACE:-}
connect_timeout=5

read_status=true
case ${1:-} in
  '') ;;
  --now) read_status=false ;;
  *) echo 'usage: stop.sh [--now]' >&2; exit 2 ;;
esac

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || { echo "refusing account ${actual_account}" >&2; exit 1; }

instance_ids=$(aws ec2 describe-instances \
  --profile "${profile}" \
  --region "${region}" \
  --filters \
    "Name=tag:ki-agent-host-id,Values=${host_id}" \
    Name=tag:ki-lifecycle,Values=prototype \
    "Name=tag:Name,Values=${host_name}" \
    Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [[ -z ${instance_ids} ]]; then
  echo 'no running agent host found'
  exit 0
fi

# readable <report> <exit status>: the report parses, carries the schema and
# its outcome matches the exit status.
readable() {
  [[ $2 =~ ^[034]$ ]] && jq -e --argjson code "$2" '.schema == "techne/host-workspace/v1"
    and ({"clean": 0, "at-risk": 3, "unknown": 4}[.outcome] == $code)
    and (.repositories | type) == "array" and (.problems | type) == "array"' <<<"$1" >/dev/null 2>&1
}

if [[ ${read_status} == true ]]; then
  code=0
  report=$(bash "${here}/status.sh" --json --connect-timeout "${connect_timeout}" 2>/dev/null) || code=$?
  if readable "${report}" "${code}"; then
    warnings=$(jq -r '(.repositories[] | select(.state != "clean") | "  \(.state) \(.path)\(if .problem then ": \(.problem)" else "" end)"),
      (.problems[] | "  unknown: \(.)")' <<<"${report}")
    if [[ -n ${warnings} ]]; then
      echo 'warning: stopping anyway; work on the host that no remote holds may be lost:' >&2
      echo "${warnings}" >&2
    fi
  else
    echo "warning: stopping anyway; the host's status could not be read (exit ${code}), so any unlanded work on it is unknown" >&2
  fi
fi

read -r -a ids <<<"${instance_ids}"
aws ec2 stop-instances --profile "${profile}" --region "${region}" --instance-ids "${ids[@]}" >/dev/null
aws ec2 wait instance-stopped --profile "${profile}" --region "${region}" --instance-ids "${ids[@]}"
echo "stopped ${ids[*]}"

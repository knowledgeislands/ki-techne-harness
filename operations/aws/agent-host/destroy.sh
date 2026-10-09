#!/usr/bin/env bash
set -euo pipefail

# The recipe's destroy path, in two operations (ODR-KI-ARCADIA-001,
# TECHNE-TOOLS-OPS-013):
#
#   destroy.sh rebuild  [--discard <repository>... | --discard-unreadable-host]
#   destroy.sh withdraw [--discard <repository>... | --discard-unreadable-host]
#
# rebuild deletes the stack only, keeping the github-token, model-api-key and
# any ubuntu-pro-token parameters for the next build; withdraw deletes the stack and every
# parameter, then lists the footprint left to remove by hand. Both refuse
# unless the host's status is clean: --discard must name exactly the
# repositories at risk, and --discard-unreadable-host, for a host whose status
# is unknown or cannot be read, needs a typed confirmation. Both check that the
# status came from the instance about to be deleted, and both may be rerun
# after a partial clean-up. Only the binding owner runs them against a host.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
# Binding values (recipes/agent-host/recipe.toml); each default is the agent-host binding's.
host_id=${AGENT_HOST_ID:-agent-host}
stack_name=${AGENT_HOST_STACK_NAME:-ki-techne-agent-host}
parameter_prefix=${AGENT_HOST_PARAMETER_PREFIX:-/ki/techne/agent-host}
parameter_prefix=${parameter_prefix%/}
# Read by status.sh for the guard.
export AGENT_HOST_TAILSCALE_NAME=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
export AGENT_HOST_REPOSITORIES=${AGENT_HOST_REPOSITORIES:-${here}/host/repositories.txt}
export KI_AGENT_HOST_WORKSPACE=${KI_AGENT_HOST_WORKSPACE:-}
connect_timeout=10

usage() {
  echo 'usage: destroy.sh rebuild|withdraw [--discard <repository>... | --discard-unreadable-host]' >&2
  exit 2
}

operation=${1:-}
[[ ${operation} == rebuild || ${operation} == withdraw ]] || usage
shift
discard=()
discard_unreadable=false
while (($#)); do
  case $1 in
    --discard)
      shift
      while (($#)) && [[ $1 != --* ]]; do discard+=("$1"); shift; done
      ((${#discard[@]})) || usage
      continue ;;
    --discard-unreadable-host) discard_unreadable=true ;;
    *) usage ;;
  esac
  shift
done
((${#discard[@]} == 0)) || [[ ${discard_unreadable} == false ]] || usage

if [[ ${CONFIRM_DESTROY_AGENT_HOST:-} != "${stack_name}" ]]; then
  echo "set CONFIRM_DESTROY_AGENT_HOST=${stack_name} to ${operation} the agent host" >&2
  exit 1
fi

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || { echo "refusing account ${actual_account}" >&2; exit 1; }

# A stack that is already gone leaves nothing to guard; clean-up carries on.
stack_present=true
# JMESPath expression, not shell interpolation.
# shellcheck disable=SC2016
if ! stack=$(aws cloudformation describe-stacks --profile "${profile}" --region "${region}" --stack-name "${stack_name}" \
  --query 'Stacks[0].[Tags[?Key==`ki-agent-host-id`].Value | [0], Outputs[?OutputKey==`AgentHostInstanceId`].OutputValue | [0]]' \
  --output text 2>&1); then
  [[ ${stack} == *'does not exist'* ]] || { echo "cannot read stack ${stack_name}: ${stack}" >&2; exit 1; }
  stack_present=false
  echo "stack ${stack_name} is already gone"
fi

# readable <report> <exit status>: the report parses, carries the schema and
# its outcome matches the exit status.
readable() {
  [[ $2 =~ ^[034]$ ]] && jq -e --argjson code "$2" '.schema == "techne/host-workspace/v1"
    and ({"clean": 0, "at-risk": 3, "unknown": 4}[.outcome] == $code)
    and (.repositories | type) == "array" and (.problems | type) == "array"' <<<"$1" >/dev/null 2>&1
}

recovery_routes() {
  cat >&2 <<EOF
Before discarding, land the work if the host can be reached:
  1. Push: on the host, push each repository's unlanded branches.
  2. Bundle: on the host, run 'git bundle create ~/<repository>.bundle --all' and
     'git bundle verify ~/<repository>.bundle' in each repository, copy the bundles
     to the operator's machine with scp over Tailscale SSH, and verify them again there.
EOF
}

if [[ ${stack_present} == true ]]; then
  read -r stack_host_id instance_id <<<"${stack}"
  [[ ${stack_host_id} == "${host_id}" ]] || { echo "refusing unrecognised stack ${stack_name}" >&2; exit 1; }

  code=0
  report=$(bash "${here}/status.sh" --json --connect-timeout "${connect_timeout}" 2>/dev/null) || code=$?
  if readable "${report}" "${code}"; then
    outcome=$(jq -r .outcome <<<"${report}")
  else
    outcome=unreadable
  fi

  case ${outcome} in
    clean)
      ((${#discard[@]} == 0)) && [[ ${discard_unreadable} == false ]] ||
        { echo 'refusing: nothing on the host is at risk, so no override applies' >&2; exit 1; } ;;
    at-risk)
      at_risk=$(jq -r '.repositories[] | select(.state == "at-risk") | .path' <<<"${report}" | sort -u)
      named=$(printf '%s\n' ${discard[@]+"${discard[@]}"} | sed '/^$/d' | sort -u)
      if [[ ${discard_unreadable} == true || ${named} != "${at_risk}" ]]; then
        echo "refusing to ${operation}: work that no remote holds is on the host:" >&2
        jq -r '.repositories[] | select(.state == "at-risk")
          | "  \(.path): \(.dirty) uncommitted, \(.unpushed) unpushed, \(.stashes) stashed"' <<<"${report}" >&2
        recovery_routes
        echo "To discard it, name exactly these repositories: --discard $(tr '\n' ' ' <<<"${at_risk}")" >&2
        exit 1
      fi
      echo "discarding the at-risk work in: $(tr '\n' ' ' <<<"${at_risk}")" ;;
    unknown | unreadable)
      if [[ ${discard_unreadable} == false ]]; then
        if [[ ${outcome} == unknown ]]; then
          echo "refusing to ${operation}: the host's work cannot be accounted for:" >&2
          jq -r '(.repositories[] | select(.state == "unknown") | "  \(.path): \(.problem)"), (.problems[] | "  \(.)")' <<<"${report}" >&2
        else
          echo "refusing to ${operation}: the host's status could not be read (exit ${code})" >&2
        fi
        recovery_routes
        echo 'To discard whatever is on the host, add --discard-unreadable-host.' >&2
        exit 1
      fi
      recovery_routes
      printf 'Type "discard %s" to discard any unlanded work on the host: ' "${stack_name}" >&2
      answer=''
      read -r answer || true
      [[ ${answer} == "discard ${stack_name}" ]] || { echo 'refusing: confirmation did not match' >&2; exit 1; } ;;
  esac

  # The status must come from the instance the stack is about to delete.
  if [[ ${outcome} == unreadable ]]; then
    echo "the status could not be read, so the same-host check is skipped under --discard-unreadable-host"
  else
    reported=$(jq -r '.host.id // empty' <<<"${report}")
    if [[ -z ${instance_id} || ${instance_id} == None || ${reported} != "${instance_id}" ]]; then
      echo "refusing: the status came from instance ${reported:-(none)}, but stack ${stack_name} holds ${instance_id}" >&2
      exit 1
    fi
  fi

  aws cloudformation delete-stack --profile "${profile}" --region "${region}" --stack-name "${stack_name}"
  aws cloudformation wait stack-delete-complete --profile "${profile}" --region "${region}" --stack-name "${stack_name}"
  echo "deleted stack ${stack_name}"
fi

if [[ ${operation} == rebuild ]]; then
  cat <<EOF
Kept ${parameter_prefix}/github-token and ${parameter_prefix}/model-api-key for the next build.
To rebuild:
  1. In the Tailscale admin console, remove the old ${AGENT_HOST_TAILSCALE_NAME} device, so the new host takes its name.
  2. Generate a fresh Tailscale auth key and store it as ${parameter_prefix}/tailscale-auth-key, overwriting any spent one.
  3. Run provision.sh, then setup.sh.
EOF
  exit 0
fi

# Missing names are reported as InvalidParameters rather than failing.
aws ssm delete-parameters \
  --profile "${profile}" \
  --region "${region}" \
  --names "${parameter_prefix}/tailscale-auth-key" "${parameter_prefix}/github-token" "${parameter_prefix}/model-api-key" "${parameter_prefix}/ubuntu-pro-token" \
  --output json
cat <<EOF
Withdrawn. Remove by hand what remains:
  - the tailnet device ${AGENT_HOST_TAILSCALE_NAME}, its tag, tag owner, grant and ssh rule, and any unused auth key;
  - the GitHub token and any model API key issued for the host, revoked where they were issued;
  - any Ubuntu Pro attachment, detached from the host's machine in the Ubuntu Pro dashboard;
  - the operator role and its inline policy, and the operator profile;
  - the SSH and editor entries for the host.
EOF

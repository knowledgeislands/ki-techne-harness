#!/usr/bin/env bash
set -euo pipefail

profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
stack_name=${AGENT_HOST_STACK_NAME:-ki-techne-agent-host}
parameter_prefix=/ki/techne/agent-host

if [[ ${CONFIRM_DESTROY_AGENT_HOST:-} != "${stack_name}" ]]; then
  echo "set CONFIRM_DESTROY_AGENT_HOST=${stack_name} to tear down the agent host and its parameters" >&2
  exit 1
fi

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || { echo "refusing account ${actual_account}" >&2; exit 1; }

# JMESPath expression, not shell interpolation.
# shellcheck disable=SC2016
host_id=$(aws cloudformation describe-stacks --profile "${profile}" --region "${region}" --stack-name "${stack_name}" --query 'Stacks[0].Tags[?Key==`ki-agent-host-id`].Value | [0]' --output text)
[[ ${host_id} == agent-host ]] || { echo "refusing unrecognised stack ${stack_name}" >&2; exit 1; }

aws cloudformation delete-stack --profile "${profile}" --region "${region}" --stack-name "${stack_name}"
aws cloudformation wait stack-delete-complete --profile "${profile}" --region "${region}" --stack-name "${stack_name}"

# Missing names are reported as InvalidParameters rather than failing.
aws ssm delete-parameters \
  --profile "${profile}" \
  --region "${region}" \
  --names "${parameter_prefix}/tailscale-auth-key" "${parameter_prefix}/github-token" "${parameter_prefix}/model-api-key" \
  --output json

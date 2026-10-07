#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
stack_name=${AGENT_HOST_STACK_NAME:-ki-techne-agent-host}
parameter_prefix=/ki/techne/agent-host
instance_type=${AGENT_HOST_INSTANCE_TYPE:-t3.medium}
volume_size=${AGENT_HOST_VOLUME_SIZE:-40}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
if [[ ${actual_account} != "${expected_account}" ]]; then
  echo "refusing account ${actual_account}; expected ${expected_account}" >&2
  exit 1
fi

if aws cloudformation describe-stacks --profile "${profile}" --region "${region}" --stack-name "${stack_name}" >/dev/null 2>&1; then
  echo "agent-host stack already exists: ${stack_name}" >&2
  exit 1
fi

# Metadata only: the auth key value is read on the host at boot, never here.
key_type=$(aws ssm describe-parameters \
  --profile "${profile}" \
  --region "${region}" \
  --parameter-filters "Key=Name,Option=Equals,Values=${parameter_prefix}/tailscale-auth-key" \
  --query 'Parameters[0].Type' \
  --output text)
if [[ ${key_type} != SecureString ]]; then
  echo "missing SecureString parameter ${parameter_prefix}/tailscale-auth-key; create it first" >&2
  exit 1
fi

aws cloudformation validate-template \
  --profile "${profile}" \
  --region "${region}" \
  --template-body "file://${repo_root}/infra/aws/agent-host-stack.yaml" >/dev/null

aws cloudformation deploy \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --template-file "${repo_root}/infra/aws/agent-host-stack.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides AgentHostId=agent-host InstanceType="${instance_type}" VolumeSize="${volume_size}" \
  --tags ki-agent-host-id=agent-host ki-lifecycle=prototype ki-work-item=KI-ARCADIA-GOV-020

aws cloudformation describe-stacks \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --query 'Stacks[0].Outputs' \
  --output json

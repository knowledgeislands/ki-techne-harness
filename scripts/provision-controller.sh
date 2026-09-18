#!/usr/bin/env bash
set -euo pipefail

proof_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
stack_name=${CONTROLLER_STACK_NAME:-ki-techne-ops-007-controller}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
if [[ ${actual_account} != "${expected_account}" ]]; then
  echo "refusing account ${actual_account}; expected ${expected_account}" >&2
  exit 1
fi

if aws cloudformation describe-stacks --profile "${profile}" --region "${region}" --stack-name "${stack_name}" >/dev/null 2>&1; then
  echo "controller stack already exists: ${stack_name}" >&2
  exit 1
fi

aws cloudformation validate-template \
  --profile "${profile}" \
  --region "${region}" \
  --template-body "file://${proof_root}/infra/aws/controller-stack.yaml" >/dev/null

aws cloudformation deploy \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --template-file "${proof_root}/infra/aws/controller-stack.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides ControllerId=primary InstanceType=t3.medium \
  --tags ki-work-item=TECHNE-OPS-007 ki-lifecycle=retained-controller

aws cloudformation describe-stacks \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --query 'Stacks[0].Outputs' \
  --output json

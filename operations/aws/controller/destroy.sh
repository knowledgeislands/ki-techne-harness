#!/usr/bin/env bash
set -euo pipefail

profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
stack_name=${CONTROLLER_STACK_NAME:-ki-techne-ops-007-controller}

if [[ ${CONFIRM_DESTROY_CONTROLLER:-} != "${stack_name}" ]]; then
  echo "controller retention is approved; set CONFIRM_DESTROY_CONTROLLER=${stack_name} for an explicit later teardown" >&2
  exit 1
fi

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || { echo "refusing account ${actual_account}" >&2; exit 1; }

aws cloudformation delete-stack --profile "${profile}" --region "${region}" --stack-name "${stack_name}"
aws cloudformation wait stack-delete-complete --profile "${profile}" --region "${region}" --stack-name "${stack_name}"

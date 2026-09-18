#!/usr/bin/env bash
set -euo pipefail

profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
target_id=${TARGET_ID:-target-001}
target_stack=${TARGET_STACK_NAME:-ki-techne-ops-007-${target_id}}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || { echo "refusing account ${actual_account}" >&2; exit 1; }

# JMESPath expression, not shell interpolation.
# shellcheck disable=SC2016
work_item=$(aws cloudformation describe-stacks --profile "${profile}" --region "${region}" --stack-name "${target_stack}" --query 'Stacks[0].Tags[?Key==`ki-work-item`].Value | [0]' --output text)
[[ ${work_item} == TECHNE-OPS-007 ]] || { echo "refusing unrecognised stack ${target_stack}" >&2; exit 1; }

aws cloudformation delete-stack --profile "${profile}" --region "${region}" --stack-name "${target_stack}"
aws cloudformation wait stack-delete-complete --profile "${profile}" --region "${region}" --stack-name "${target_stack}"

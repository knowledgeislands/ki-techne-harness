#!/usr/bin/env bash
set -euo pipefail

profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
stack_name=${CONTROLLER_STACK_NAME:-ki-techne-ops-007-controller}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || {
  echo "refusing AWS account ${actual_account}; expected ${expected_account}" >&2
  exit 1
}

# The JMESPath expression is intentionally literal.
# shellcheck disable=SC2016
instance_id=$(aws cloudformation describe-stacks \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ControllerInstanceId`].OutputValue | [0]' \
  --output text)
[[ ${instance_id} == i-* ]] || { echo 'controller instance output missing' >&2; exit 1; }

parameters=$(mktemp)
trap 'rm -f "${parameters}"' EXIT
jq -n \
  --arg command 'sudo /opt/ki-techne-tools/scripts/enable-secrets-encryption-on-controller.sh' \
  '{commands: [$command]}' >"${parameters}"

command_id=$(aws ssm send-command \
  --profile "${profile}" \
  --region "${region}" \
  --instance-ids "${instance_id}" \
  --document-name AWS-RunShellScript \
  --comment 'Enable K3s Secret encryption for the retained Techne controller' \
  --parameters "file://${parameters}" \
  --query Command.CommandId \
  --output text)

aws ssm wait command-executed \
  --profile "${profile}" \
  --region "${region}" \
  --command-id "${command_id}" \
  --instance-id "${instance_id}"

aws ssm get-command-invocation \
  --profile "${profile}" \
  --region "${region}" \
  --command-id "${command_id}" \
  --instance-id "${instance_id}" \
  --query '{Status:Status,ResponseCode:ResponseCode,Output:StandardOutputContent,Error:StandardErrorContent}' \
  --output json

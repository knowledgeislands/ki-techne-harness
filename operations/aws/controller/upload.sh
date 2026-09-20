#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
stack_name=${CONTROLLER_STACK_NAME:-ki-techne-ops-007-controller}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || {
  echo "refusing account ${actual_account}; expected ${expected_account}" >&2
  exit 1
}

# JMESPath expression, not shell interpolation.
# shellcheck disable=SC2016
instance_id=$(aws cloudformation describe-stacks \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --query 'Stacks[0].Outputs[?OutputKey==`ControllerInstanceId`].OutputValue | [0]' \
  --output text)
[[ ${instance_id} == i-* ]] || { echo 'controller instance output missing' >&2; exit 1; }

archive=$(mktemp)
parameters=$(mktemp)
trap 'rm -f "${archive}" "${parameters}"' EXIT

tar -C "${repo_root}" -czf "${archive}" \
  apps/controller/src \
  apps/controller/fixtures/targets.local.json \
  deploy/kubernetes/controller \
  deploy/runtime/controller
payload=$(base64 <"${archive}" | tr -d '\n')

jq -n --arg payload "${payload}" '{commands: [
  "set -eu",
  "umask 077",
  ("printf %s " + ($payload | @sh) + " | base64 -d >/tmp/techne-harness.tar.gz"),
  "rm -rf /opt/ki-techne-harness",
  "install -d -m 0755 /opt/ki-techne-harness",
  "tar -xzf /tmp/techne-harness.tar.gz -C /opt/ki-techne-harness",
  "chmod +x /opt/ki-techne-harness/deploy/runtime/controller/*.sh",
  "rm -f /tmp/techne-harness.tar.gz"
]}' >"${parameters}"

command_id=$(aws ssm send-command \
  --profile "${profile}" \
  --region "${region}" \
  --instance-ids "${instance_id}" \
  --document-name AWS-RunShellScript \
  --comment 'Upload Techne controller harness package' \
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
  --query '{Status:Status,ResponseCode:ResponseCode}' \
  --output json

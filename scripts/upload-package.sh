#!/usr/bin/env bash
set -euo pipefail

proof_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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

tar -C "${proof_root}" -czf "${archive}" \
  apps/controller/src \
  apps/controller/fixtures/targets.local.json \
  deploy/kubernetes/controller \
  scripts/deploy-on-controller.sh \
  scripts/bootstrap-on-controller.sh \
  scripts/enable-secrets-encryption-on-controller.sh \
  scripts/register-target-on-controller.sh \
  scripts/deregister-target-on-controller.sh
payload=$(base64 <"${archive}" | tr -d '\n')

jq -n --arg payload "${payload}" '{commands: [
  "set -eu",
  "umask 077",
  ("printf %s " + ($payload | @sh) + " | base64 -d >/tmp/techne-proof.tar.gz"),
  "rm -rf /opt/ki-techne-tools",
  "install -d -m 0755 /opt/ki-techne-tools",
  "tar -xzf /tmp/techne-proof.tar.gz -C /opt/ki-techne-tools",
  "chmod +x /opt/ki-techne-tools/scripts/*.sh",
  "rm -f /tmp/techne-proof.tar.gz"
]}' >"${parameters}"

command_id=$(aws ssm send-command \
  --profile "${profile}" \
  --region "${region}" \
  --instance-ids "${instance_id}" \
  --document-name AWS-RunShellScript \
  --comment 'Upload TECHNE-OPS-007 dependency-free proof package' \
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

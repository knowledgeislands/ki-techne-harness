#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
controller_stack=${CONTROLLER_STACK_NAME:-ki-techne-ops-007-controller}
target_id=${TARGET_ID:-target-001}
target_stack=${TARGET_STACK_NAME:-ki-techne-ops-007-${target_id}}
expiry_at=${EXPIRY_AT:-$(date -u -v+2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+2 hours' +%Y-%m-%dT%H:%M:%SZ)}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
if [[ ${actual_account} != "${expected_account}" ]]; then
  echo "refusing account ${actual_account}; expected ${expected_account}" >&2
  exit 1
fi

outputs=$(aws cloudformation describe-stacks --profile "${profile}" --region "${region}" --stack-name "${controller_stack}" --query 'Stacks[0].Outputs' --output json)
vpc_id=$(jq -r '.[] | select(.OutputKey == "VpcId") | .OutputValue' <<<"${outputs}")
subnet_id=$(jq -r '.[] | select(.OutputKey == "PublicSubnetId") | .OutputValue' <<<"${outputs}")
controller_sg=$(jq -r '.[] | select(.OutputKey == "ControllerSecurityGroupId") | .OutputValue' <<<"${outputs}")

for value in "${vpc_id}" "${subnet_id}" "${controller_sg}"; do
  [[ -n ${value} && ${value} != null ]] || { echo 'controller stack output missing' >&2; exit 1; }
done

aws cloudformation deploy \
  --profile "${profile}" \
  --region "${region}" \
  --stack-name "${target_stack}" \
  --template-file "${repo_root}/infra/aws/target-stack.yaml" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    TargetId="${target_id}" \
    ExpiryAt="${expiry_at}" \
    VpcId="${vpc_id}" \
    PublicSubnetId="${subnet_id}" \
    ControllerSecurityGroupId="${controller_sg}" \
  --tags ki-work-item=TECHNE-OPS-007 ki-lifecycle=disposable-target ki-expiry-at="${expiry_at}"

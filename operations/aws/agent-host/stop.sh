#!/usr/bin/env bash
set -euo pipefail

# Kill switch: stops the tagged agent host, ending every session on it.
# Runs with the least-privilege agent-host profile; tailnet revocation is a
# separate step in the Tailscale admin console.
profile=${AWS_PROFILE:-knowledge-islands-techne-agent-host}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}

actual_account=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
[[ ${actual_account} == "${expected_account}" ]] || { echo "refusing account ${actual_account}" >&2; exit 1; }

instance_ids=$(aws ec2 describe-instances \
  --profile "${profile}" \
  --region "${region}" \
  --filters \
    Name=tag:ki-agent-host-id,Values=agent-host \
    Name=tag:ki-lifecycle,Values=prototype \
    Name=tag:Name,Values=ki-techne-agent-host \
    Name=instance-state-name,Values=pending,running \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

if [[ -z ${instance_ids} ]]; then
  echo 'no running agent host found'
  exit 0
fi

read -r -a ids <<<"${instance_ids}"
aws ec2 stop-instances --profile "${profile}" --region "${region}" --instance-ids "${ids[@]}" >/dev/null
aws ec2 wait instance-stopped --profile "${profile}" --region "${region}" --instance-ids "${ids[@]}"
echo "stopped ${ids[*]}"

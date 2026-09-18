#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
profile=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}

for template in controller-stack.yaml target-stack.yaml; do
  aws cloudformation validate-template \
    --profile "${profile}" \
    --region "${region}" \
    --template-body "file://${repo_root}/infra/aws/${template}" >/dev/null
  echo "validated infra/aws/${template}"
done

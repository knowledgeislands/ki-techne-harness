#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "${here}/../../.." && pwd)
# Preserve Granted-exported credentials; AWS_PROFILE supplies the fallback.
export AWS_PROFILE=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
# Binding values (recipes/agent-host/recipe.toml); each default is the agent-host binding's.
host_id=${AGENT_HOST_ID:-agent-host}
host_name=${AGENT_HOST_NAME:-ki-techne-agent-host}
tailscale_name=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
tailscale_tag=${AGENT_HOST_TAILSCALE_TAG:-tag:ki-techne-agent-host}
stack_name=${AGENT_HOST_STACK_NAME:-ki-techne-agent-host}
parameter_prefix=${AGENT_HOST_PARAMETER_PREFIX:-/ki/techne/agent-host}
parameter_prefix=${parameter_prefix%/}
instance_type=${AGENT_HOST_INSTANCE_TYPE:-t3.medium}
volume_size=${AGENT_HOST_VOLUME_SIZE:-40}
shell=${AGENT_HOST_SHELL:-zsh}
# Optional binding values for OS patching: empty means no automatic
# reboot and no Livepatch.
reboot_window=${AGENT_HOST_REBOOT_WINDOW:-}
livepatch=${AGENT_HOST_LIVEPATCH:-false}

if [[ -n ${reboot_window} && ! ${reboot_window} =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
  echo "AGENT_HOST_REBOOT_WINDOW must be a daily 24-hour HH:MM with no weekday, not ${reboot_window}" >&2
  exit 1
fi
if [[ ${shell} != bash && ${shell} != zsh ]]; then
  echo "AGENT_HOST_SHELL must be bash or zsh, not ${shell}" >&2
  exit 1
fi
if [[ ${livepatch} != true && ${livepatch} != false ]]; then
  echo "AGENT_HOST_LIVEPATCH must be true or false, not ${livepatch}" >&2
  exit 1
fi
patching=()
[[ -n ${reboot_window} ]] && patching+=(RebootWindow="${reboot_window}")
[[ ${livepatch} == true ]] && patching+=(Livepatch=true)

actual_account=$(aws sts get-caller-identity --query Account --output text)
if [[ ${actual_account} != "${expected_account}" ]]; then
  echo "refusing account ${actual_account}; expected ${expected_account}" >&2
  exit 1
fi

if aws cloudformation describe-stacks --region "${region}" --stack-name "${stack_name}" >/dev/null 2>&1; then
  echo "agent-host stack already exists: ${stack_name}" >&2
  exit 1
fi

# Metadata only: secret values are read on the host at boot, never here.
has_secret() {
  local key_type
  key_type=$(aws ssm describe-parameters \
    --region "${region}" \
    --parameter-filters "Key=Name,Option=Equals,Values=${parameter_prefix}/$1" \
    --query 'Parameters[0].Type' \
    --output text)
  [[ ${key_type} == SecureString ]]
}
require_secret() {
  has_secret "$1" || { echo "missing SecureString parameter ${parameter_prefix}/$1; create it first" >&2; exit 1; }
}
# A stored auth key is used as it is. Without one, a configured Tailscale OAuth
# client mints it just before the deploy; with neither, the hand route applies.
mint_key=false
if ! has_secret tailscale-auth-key; then
  if [[ -n ${AGENT_HOST_TAILSCALE_OAUTH_ITEM:-}${AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET:-} ]]; then
    mint_key=true
  else
    echo "missing SecureString parameter ${parameter_prefix}/tailscale-auth-key; store a key by hand, or set AGENT_HOST_TAILSCALE_OAUTH_ITEM to mint one" >&2
    exit 1
  fi
fi
# Livepatch attaches Ubuntu Pro with the binding owner's token.
[[ ${livepatch} == true ]] && require_secret ubuntu-pro-token

aws cloudformation validate-template \
  --region "${region}" \
  --template-body "file://${repo_root}/infra/aws/agent-host-stack.yaml" >/dev/null

if [[ ${mint_key} == true ]]; then
  AWS_REGION=${region} EXPECTED_AWS_ACCOUNT=${expected_account} AGENT_HOST_ID=${host_id} \
    AGENT_HOST_TAILSCALE_TAG=${tailscale_tag} AGENT_HOST_PARAMETER_PREFIX=${parameter_prefix} \
    bash "${here}/mint-tailscale-key.sh"
fi

aws cloudformation deploy \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --template-file "${repo_root}/infra/aws/agent-host-stack.yaml" \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    AgentHostId="${host_id}" \
    HostName="${host_name}" \
    TailscaleHostname="${tailscale_name}" \
    TailscaleTag="${tailscale_tag}" \
    ParameterPrefix="${parameter_prefix}" \
    InstanceType="${instance_type}" \
    VolumeSize="${volume_size}" \
    Shell="${shell}" \
    ${patching[@]+"${patching[@]}"} \
  --tags ki-agent-host-id="${host_id}" ki-lifecycle=prototype ki-authority=GDR-KI-PRINCIPAL-004

aws cloudformation describe-stacks \
  --region "${region}" \
  --stack-name "${stack_name}" \
  --query 'Stacks[0].Outputs' \
  --output json

#!/usr/bin/env bash
set -euo pipefail

# Mints the host's Tailscale auth key from the binding owner's Tailscale OAuth
# client and stores it as the tailscale-auth-key SecureString the boot script
# reads. provision.sh runs it when that parameter is absent and a client is
# configured; `--check` only proves Tailscale accepts the client and mints nothing.
#
#   mint-tailscale-key.sh [--check]
#
# The client comes from AGENT_HOST_TAILSCALE_OAUTH_ITEM, a 1Password item
# reference read on this workstation with `op read` (field username holds the
# client ID, credential the client secret), or else from
# AGENT_HOST_TAILSCALE_OAUTH_CLIENT_ID and AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET,
# as `op run` sets them. The secret, the access token and the key pass only
# through shell variables, builtins and pipes: never a command argument,
# standard output or a file. No here-string or here-document appears below,
# because Bash may back either with a temporary file.

# Preserve Granted-exported credentials; AWS_PROFILE supplies the fallback.
export AWS_PROFILE=${AWS_PROFILE:-knowledge-islands-techne}
region=${AWS_REGION:-eu-west-1}
expected_account=${EXPECTED_AWS_ACCOUNT:-655383751458}
host_id=${AGENT_HOST_ID:-agent-host}
tailscale_tag=${AGENT_HOST_TAILSCALE_TAG:-tag:ki-techne-agent-host}
parameter_prefix=${AGENT_HOST_PARAMETER_PREFIX:-/ki/techne/agent-host}
parameter_prefix=${parameter_prefix%/}
oauth_item=${AGENT_HOST_TAILSCALE_OAUTH_ITEM:-}
api=https://api.tailscale.com/api/v2
# One hour covers a build: the boot script reads the key minutes after deploy.
expiry_seconds=3600

check_only=false
case ${1:-} in
  '') ;;
  --check) check_only=true ;;
  *) echo 'usage: mint-tailscale-key.sh [--check]' >&2; exit 2 ;;
esac

if [[ -n ${AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET:-} ]]; then
  client_id=${AGENT_HOST_TAILSCALE_OAUTH_CLIENT_ID:-}
  client_secret=${AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET}
elif [[ -n ${oauth_item} ]]; then
  [[ ${oauth_item} == op://* ]] || { echo 'AGENT_HOST_TAILSCALE_OAUTH_ITEM must be an op:// item reference' >&2; exit 1; }
  client_id=$(op read "${oauth_item}/username")
  client_secret=$(op read "${oauth_item}/credential")
else
  echo 'no Tailscale OAuth client: set AGENT_HOST_TAILSCALE_OAUTH_ITEM, or store the key by hand' >&2
  exit 1
fi
# The forms keep each value safe inside a quoted curl configuration line.
# Neither message names the value it rejects.
[[ ${client_id} =~ ^[A-Za-z0-9]+$ ]] || { echo 'the Tailscale OAuth client ID is missing or malformed' >&2; exit 1; }
[[ ${client_secret} =~ ^tskey-client-[A-Za-z0-9-]+$ ]] || { echo 'the Tailscale OAuth client secret is malformed' >&2; exit 1; }

if [[ ${check_only} == false ]]; then
  actual_account=$(aws sts get-caller-identity --query Account --output text)
  if [[ ${actual_account} != "${expected_account}" ]]; then
    echo "refusing account ${actual_account}; expected ${expected_account}" >&2
    exit 1
  fi
fi

# curl reads each request from its configuration on standard input, so no
# credential reaches its arguments; --fail keeps an error body off the terminal.
token_response=$(printf 'url = "%s/oauth/token"\ndata-urlencode = "client_id=%s"\ndata-urlencode = "client_secret=%s"\n' \
  "${api}" "${client_id}" "${client_secret}" | curl --silent --show-error --fail --config -)
unset client_secret
access_token=$(printf '%s' "${token_response}" | jq -r '.access_token // empty')
scope=$(printf '%s' "${token_response}" | jq -r '.scope // empty')
unset token_response
[[ ${access_token} =~ ^[A-Za-z0-9._-]+$ ]] || { echo 'Tailscale returned no usable access token' >&2; exit 1; }

if [[ ${check_only} == true ]]; then
  echo "Tailscale accepted the OAuth client (scope: ${scope:-not stated}); no key was minted"
  exit 0
fi

# Single-use, not ephemeral, pre-approved and the binding's tag only: the hand route's key.
body=$(jq -cn --arg tag "${tailscale_tag}" --argjson expiry "${expiry_seconds}" --arg description "ki-techne ${host_id} build" \
  '{capabilities: {devices: {create: {reusable: false, ephemeral: false, preauthorized: true, tags: [$tag]}}},
    expirySeconds: $expiry, description: $description} | tojson')
key_response=$(printf 'url = "%s/tailnet/-/keys"\nheader = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\ndata-raw = %s\n' \
  "${api}" "${access_token}" "${body}" | curl --silent --show-error --fail --config -)
unset access_token
key=$(printf '%s' "${key_response}" | jq -r '.key // empty')
key_id=$(printf '%s' "${key_response}" | jq -r '.id // empty')
unset key_response
[[ ${key} =~ ^tskey-auth-[A-Za-z0-9-]+$ ]] || { echo 'Tailscale returned no usable auth key' >&2; exit 1; }

# Without --overwrite, an existing parameter is never replaced.
printf '%s' "${key}" | aws ssm put-parameter \
  --region "${region}" \
  --name "${parameter_prefix}/tailscale-auth-key" \
  --type SecureString \
  --value file:///dev/stdin >/dev/null
unset key
echo "minted Tailscale auth key ${key_id:-(no id)} for ${tailscale_tag}, single-use and expiring in $((expiry_seconds / 60)) minutes, and stored it as ${parameter_prefix}/tailscale-auth-key"

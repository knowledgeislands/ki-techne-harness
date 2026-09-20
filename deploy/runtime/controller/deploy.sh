#!/usr/bin/env bash
set -euo pipefail

: "${TELEGRAM_BOT_TOKEN:?set TELEGRAM_BOT_TOKEN in the process environment}"
: "${TELEGRAM_OPERATOR_USER_ID:?set TELEGRAM_OPERATOR_USER_ID}"
: "${TELEGRAM_OPERATOR_CHAT_ID:?set TELEGRAM_OPERATOR_CHAT_ID}"
: "${TELEGRAM_INITIAL_OFFSET:?set TELEGRAM_INITIAL_OFFSET to the selected update ID plus one}"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
kubectl_command=${KUBECTL_COMMAND:-k3s kubectl}

read -r -a kubectl_parts <<<"${kubectl_command}"

encryption_status=$(k3s secrets-encrypt status)
grep -Fq 'Encryption Status: Enabled' <<<"${encryption_status}" || {
  echo 'K3s Secret encryption is not enabled; refusing credential admission' >&2
  exit 1
}
grep -Fq 'Current Rotation Stage: reencrypt_finished' <<<"${encryption_status}" || {
  echo 'K3s Secret re-encryption has not finished; refusing credential admission' >&2
  exit 1
}

"${kubectl_parts[@]}" apply -f "${repo_root}/deploy/kubernetes/controller/namespaces.yaml"
"${kubectl_parts[@]}" apply -f "${repo_root}/deploy/kubernetes/controller/service-accounts.yaml"
"${kubectl_parts[@]}" apply -f "${repo_root}/deploy/kubernetes/controller/rbac.yaml"
"${kubectl_parts[@]}" apply -f "${repo_root}/deploy/kubernetes/controller/config.yaml"
"${kubectl_parts[@]}" apply -f "${repo_root}/deploy/kubernetes/controller/network-policy.yaml"

"${kubectl_parts[@]}" -n techne-controller create configmap techne-controller-source \
  --from-file=controller.py="${repo_root}/apps/controller/src/controller.py" \
  --dry-run=client -o yaml | "${kubectl_parts[@]}" apply -f -

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}" \
TELEGRAM_OPERATOR_USER_ID="${TELEGRAM_OPERATOR_USER_ID}" \
TELEGRAM_OPERATOR_CHAT_ID="${TELEGRAM_OPERATOR_CHAT_ID}" \
TELEGRAM_INITIAL_OFFSET="${TELEGRAM_INITIAL_OFFSET}" \
python3 - <<'PY' | "${kubectl_parts[@]}" apply -f -
import base64
import json
import os

data = {
    "telegram-token": os.environ["TELEGRAM_BOT_TOKEN"],
    "operator-user-id": os.environ["TELEGRAM_OPERATOR_USER_ID"],
    "operator-chat-id": os.environ["TELEGRAM_OPERATOR_CHAT_ID"],
    "initial-offset": os.environ["TELEGRAM_INITIAL_OFFSET"],
}
print(json.dumps({
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "techne-controller-secrets", "namespace": "techne-controller"},
    "type": "Opaque",
    "data": {key: base64.b64encode(value.encode()).decode() for key, value in data.items()},
}))
PY

"${kubectl_parts[@]}" apply -f "${repo_root}/deploy/kubernetes/controller/deployment.yaml"
"${kubectl_parts[@]}" -n techne-controller rollout status deployment/techne-controller --timeout=180s

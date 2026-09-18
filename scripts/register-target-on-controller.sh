#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_ID:?set TARGET_ID, for example target-001}"
: "${TARGET_API_SERVER:?set TARGET_API_SERVER to the private https://IP:6443 endpoint}"
: "${TARGET_CA_FILE:?set TARGET_CA_FILE to the transferred K3s server CA file}"

[[ ${TARGET_ID} =~ ^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$ ]] || {
  echo 'TARGET_ID is not a DNS label' >&2
  exit 1
}
[[ ${TARGET_ID} != local ]] || { echo 'refusing to replace local target' >&2; exit 1; }
[[ ${TARGET_API_SERVER} =~ ^https://10\.89\.0\.[0-9]+:6443$ ]] || {
  echo 'TARGET_API_SERVER must use the proof VPC private address and port 6443' >&2
  exit 1
}
[[ -r ${TARGET_CA_FILE} ]] || { echo 'TARGET_CA_FILE is not readable' >&2; exit 1; }

proof_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kubectl_command=${KUBECTL_COMMAND:-k3s kubectl}
read -r -a kubectl_parts <<<"${kubectl_command}"

if [[ -z ${TARGET_BEARER_TOKEN:-} ]]; then
  read -r -s -p 'Time-bounded target bearer token: ' TARGET_BEARER_TOKEN
  echo >&2
fi
[[ -n ${TARGET_BEARER_TOKEN} ]] || { echo 'empty target bearer token' >&2; exit 1; }

targets_file=$(mktemp)
trap 'rm -f "${targets_file}"' EXIT
jq -n \
  --slurpfile local "${proof_root}/apps/controller/fixtures/targets.local.json" \
  --arg id "${TARGET_ID}" \
  --arg server "${TARGET_API_SERVER}" \
  '{targets: ($local[0].targets + [{
    id: $id,
    api_server: $server,
    namespace: "techne-execution",
    ca_file: ("/var/run/secrets/targets/" + $id + "-ca.crt"),
    token_file: ("/var/run/secrets/targets/" + $id + "-token")
  }])}' >"${targets_file}"

TARGET_BEARER_TOKEN="${TARGET_BEARER_TOKEN}" \
TARGET_CA_FILE="${TARGET_CA_FILE}" \
TARGET_ID="${TARGET_ID}" \
python3 - <<'PY' | "${kubectl_parts[@]}" apply -f -
import base64
import json
import os
from pathlib import Path

target_id = os.environ["TARGET_ID"]
values = {
    f"{target_id}-token": os.environ["TARGET_BEARER_TOKEN"].encode(),
    f"{target_id}-ca.crt": Path(os.environ["TARGET_CA_FILE"]).read_bytes(),
}
print(json.dumps({
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {"name": "techne-target-credentials", "namespace": "techne-controller"},
    "data": {key: base64.b64encode(value).decode() for key, value in values.items()},
}))
PY

unset TARGET_BEARER_TOKEN
"${kubectl_parts[@]}" -n techne-controller create configmap techne-controller-config \
  --from-file=targets.json="${targets_file}" \
  --dry-run=client -o yaml | "${kubectl_parts[@]}" apply -f -
"${kubectl_parts[@]}" -n techne-controller rollout restart deployment/techne-controller
"${kubectl_parts[@]}" -n techne-controller rollout status deployment/techne-controller --timeout=180s

#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
kubectl_command=${KUBECTL_COMMAND:-k3s kubectl}
read -r -a kubectl_parts <<<"${kubectl_command}"

"${kubectl_parts[@]}" -n techne-controller create configmap techne-controller-config \
  --from-file=targets.json="${repo_root}/apps/controller/fixtures/targets.local.json" \
  --dry-run=client -o yaml | "${kubectl_parts[@]}" apply -f -
"${kubectl_parts[@]}" -n techne-controller rollout restart deployment/techne-controller
"${kubectl_parts[@]}" -n techne-controller rollout status deployment/techne-controller --timeout=180s
"${kubectl_parts[@]}" -n techne-controller delete secret techne-target-credentials --ignore-not-found

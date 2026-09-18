#!/usr/bin/env bash
set -euo pipefail

proof_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kubectl_command=${KUBECTL_COMMAND:-k3s kubectl}
credential_lifetime=${TARGET_CREDENTIAL_LIFETIME:-4h}
credential_dir=${TARGET_CREDENTIAL_DIR:-/var/lib/ki-target}

read -r -a kubectl_parts <<<"${kubectl_command}"
"${kubectl_parts[@]}" apply -f "${proof_root}/deploy/kubernetes/target/access.yaml"

install -d -m 0700 "${credential_dir}"
"${kubectl_parts[@]}" -n techne-execution create token techne-controller-remote \
  --duration="${credential_lifetime}" >"${credential_dir}/controller-token"
install -m 0600 /var/lib/rancher/k3s/server/tls/server-ca.crt "${credential_dir}/server-ca.crt"
chmod 0600 "${credential_dir}/controller-token"

echo "Prepared a ${credential_lifetime} namespace-scoped credential in ${credential_dir}." >&2
echo 'Transfer it only through the approved interactive secret boundary; never retain it as evidence.' >&2

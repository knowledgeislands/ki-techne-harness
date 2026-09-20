#!/usr/bin/env bash
set -euo pipefail

if ((EUID != 0)); then
  echo 'run this script as root on the controller host' >&2
  exit 1
fi

wait_for_k3s() {
  local _
  for _ in {1..90}; do
    if k3s kubectl get --raw=/readyz >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo 'K3s did not become ready after restart' >&2
  return 1
}

status=$(k3s secrets-encrypt status 2>&1 || true)
if grep -Fq 'Encryption Status: Enabled' <<<"${status}" && \
  grep -Fq 'Current Rotation Stage: reencrypt_finished' <<<"${status}"; then
  echo 'K3s Secret encryption already enabled and re-encryption finished'
  exit 0
fi

restart_required=false
if grep -Fq 'Disabled, no configuration file found' <<<"${status}"; then
  k3s secrets-encrypt enable
  restart_required=true
elif ! grep -Eq 'Encryption Status: (Disabled|Enabled)' <<<"${status}"; then
  echo 'unexpected K3s Secret encryption state; refusing to continue' >&2
  printf '%s\n' "${status}" >&2
  exit 1
fi

config_file=/etc/rancher/k3s/config.yaml
install -d -m 0755 /etc/rancher/k3s
if [[ -f ${config_file} ]] && grep -Eq '^[[:space:]]*secrets-encryption:' "${config_file}"; then
  if ! grep -Eq '^[[:space:]]*secrets-encryption:[[:space:]]*true[[:space:]]*$' "${config_file}"; then
    sed -i -E 's/^[[:space:]]*secrets-encryption:.*/secrets-encryption: true/' "${config_file}"
    restart_required=true
  fi
else
  printf '\nsecrets-encryption: true\n' >>"${config_file}"
  restart_required=true
fi
chmod 0600 "${config_file}"

if [[ ${restart_required} == true ]]; then
  systemctl restart k3s
fi
wait_for_k3s

status=$(k3s secrets-encrypt status)
if ! grep -Eq 'Current Rotation Stage: (start|reencrypt_finished)' <<<"${status}"; then
  echo 'K3s did not reach the expected pre-rotation state' >&2
  printf '%s\n' "${status}" >&2
  exit 1
fi

if ! grep -Fq 'Current Rotation Stage: reencrypt_finished' <<<"${status}"; then
  rotated=false
  for _ in {1..12}; do
    if k3s secrets-encrypt rotate-keys; then
      rotated=true
      break
    fi
    status=$(k3s secrets-encrypt status)
    if ! grep -Fq 'Current Rotation Stage: start' <<<"${status}"; then
      echo 'K3s rotation failed after leaving the safe start stage' >&2
      printf '%s\n' "${status}" >&2
      exit 1
    fi
    sleep 5
  done
  [[ ${rotated} == true ]] || {
    echo 'K3s encryption controller did not become ready for key rotation' >&2
    exit 1
  }
  systemctl restart k3s
  wait_for_k3s
fi

for _ in {1..90}; do
  status=$(k3s secrets-encrypt status)
  if grep -Fq 'Encryption Status: Enabled' <<<"${status}" && \
    grep -Fq 'Current Rotation Stage: reencrypt_finished' <<<"${status}"; then
    printf '%s\n' "${status}"
    exit 0
  fi
  sleep 2
done

echo 'K3s Secret encryption did not reach reencrypt_finished' >&2
printf '%s\n' "${status}" >&2
exit 1

#!/usr/bin/env bash
set -euo pipefail

# Converge techne's workspace on the agent host from the operator's workstation
# (TECHNE-TOOLS-OPS-011, TECHNE-TOOLS-OPS-015). Stages the host scripts, the
# recipe's files and, when AGENT_HOST_PROFILE names one, the binding owner's
# validated profile payload over one SSH connection and runs host/converge.sh
# there. SSH only: no AWS or Tailscale API call. Pass --pull to fast-forward
# clean checkouts.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Binding values (recipes/direct-host/recipe.toml); each default is the agent-host binding's.
host=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
repositories=${AGENT_HOST_REPOSITORIES:-${here}/host/repositories.txt}
# Empty means the host default; a leading ~/ is expanded on the host.
workspace=${KI_AGENT_HOST_WORKSPACE:-}
# The owner's techne/host-profile/v1 payload directory; unset means none, and
# the host gets the recipe layer alone.
profile=${AGENT_HOST_PROFILE:-}
shell_choice=${AGENT_HOST_SHELL:-zsh}
case ${shell_choice} in
  bash | zsh) ;;
  *) echo "AGENT_HOST_SHELL: ${shell_choice} is not a supported shell (bash or zsh)" >&2; exit 2 ;;
esac
converge_args=()
for argument in "$@"; do
  case ${argument} in
    --pull) converge_args+=(--pull) ;;
    *) echo 'usage: setup.sh [--pull]' >&2; exit 2 ;;
  esac
done

# The payload is validated here, before anything is sent, and again on the host.
if [[ -n ${profile} ]]; then
  [[ -d ${profile} ]] || { echo "AGENT_HOST_PROFILE: ${profile} is not a directory" >&2; exit 2; }
  # shellcheck disable=SC2088 # the recipe default keeps its literal ~/ for the host.
  python3 "${here}/host/profile-check.py" --shell "${shell_choice}" --workspace "${workspace:-~/workspaces/kit}" \
    --recipe-rig "${here}/../../../recipes/direct-host/rig.toml" "${profile}" ||
    { echo "AGENT_HOST_PROFILE: ${profile} is not a valid profile payload; nothing was sent" >&2; exit 1; }
fi
converge_args+=(--shell "${shell_choice}")
converge_args+=(--git-name "$(git config --global user.name)" --git-email "$(git config --global user.email)")

stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT
cp "${here}/host/converge.sh" "${here}/host/status.sh" "${here}/host/profile-check.py" "${stage}/"
# The recipe's pins, their Rig provider and its own host instructions (TECHNE-TOOLS-OPS-014).
cp "${here}/../../../recipes/direct-host/rig.toml" "${here}/../../../recipes/direct-host/rig-pins.sh" \
  "${here}/../../../recipes/direct-host/host-instructions.md" "${stage}/"
cp "${repositories}" "${stage}/repositories.txt"
if [[ -n ${profile} ]]; then
  mkdir "${stage}/profile"
  cp -R "${profile}/manifest.json" "${stage}/profile/"
  [[ -d ${profile}/home ]] && cp -R "${profile}/home" "${stage}/profile/"
fi

tar_flags=()
tar --version 2>/dev/null | grep -q bsdtar && tar_flags=(--no-mac-metadata --no-xattrs)

# The payload replaces the last one; the remote shell quotes the converge arguments.
remote="set -e; payload=\$HOME/.cache/ki-agent-host/payload; rm -rf \"\$payload\"; mkdir -p \"\$payload\"; chmod 700 \"\$payload\";"
remote+=" tar -xf - -C \"\$payload\";"
[[ -n ${workspace} ]] && remote+=" export KI_AGENT_HOST_WORKSPACE=$(printf '%q' "${workspace}");"
remote+=" exec bash \"\$payload/converge.sh\"$(printf ' %q' "${converge_args[@]}")"
# shellcheck disable=SC2029 # remote is built for the host shell on purpose.
COPYFILE_DISABLE=1 tar ${tar_flags[@]+"${tar_flags[@]}"} -C "${stage}" -cf - . | ssh "${host}" "${remote}"

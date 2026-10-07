#!/usr/bin/env bash
set -euo pipefail

# Converge techne's workspace on the agent host from the Mac (TECHNE-TOOLS-OPS-011).
# Renders Kris's Claude instructions from chezmoi, stages them with the host
# scripts over one SSH connection and runs host/converge.sh there. SSH only:
# no AWS or Tailscale API call. Pass --pull to fast-forward clean checkouts.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Binding values (recipes/direct-host/recipe.toml); each default is the agent-host binding's.
host_name=${AGENT_HOST_NAME:-ki-techne-agent-host}
host=${AGENT_HOST_TAILSCALE_NAME:-ki-techne-agent-host}
repositories=${AGENT_HOST_REPOSITORIES:-${here}/host/repositories.txt}
# Empty means the host default; a leading ~/ is expanded on the host.
workspace=${KI_AGENT_HOST_WORKSPACE:-}
# Person-specific, not a binding field: the ~/.claude files rendered for the host.
read -r -a instructions <<<"${AGENT_HOST_INSTRUCTIONS:-CLAUDE.md communication.md delegation.md memory-scope.md markdown.md}"
for name in "${instructions[@]}"; do
  [[ ${name} =~ ^[A-Za-z0-9._-]+\.md$ ]] || { echo "AGENT_HOST_INSTRUCTIONS: ${name} is not a Markdown file name in ~/.claude" >&2; exit 2; }
done
converge_args=()
for argument in "$@"; do
  case ${argument} in
    --pull) converge_args+=(--pull) ;;
    *) echo 'usage: setup.sh [--pull]' >&2; exit 2 ;;
  esac
done

command -v chezmoi >/dev/null || { echo 'chezmoi is required to render the Claude instructions' >&2; exit 1; }
converge_args+=(--git-name "$(git config --global user.name)" --git-email "$(git config --global user.email)")

stage=$(mktemp -d)
trap 'rm -rf "${stage}"' EXIT
cp "${here}/host/converge.sh" "${here}/host/status.sh" "${stage}/"
cp "${repositories}" "${stage}/repositories.txt"
mkdir "${stage}/claude"
for name in "${instructions[@]}"; do
  {
    printf '<!-- Rendered for %s from the Mac'"'"'s chezmoi source by ki-techne-harness operations/aws/agent-host/setup.sh; edit the source on the Mac, not this copy. -->\n\n' "${host_name}"
    chezmoi cat "${HOME}/.claude/${name}"
  } >"${stage}/claude/${name}"
done

tar_flags=()
tar --version 2>/dev/null | grep -q bsdtar && tar_flags=(--no-mac-metadata --no-xattrs)

# The payload replaces the last one; the remote shell quotes the converge arguments.
remote="set -e; payload=\$HOME/.cache/ki-agent-host/payload; rm -rf \"\$payload\"; mkdir -p \"\$payload\"; chmod 700 \"\$payload\";"
remote+=" tar -xf - -C \"\$payload\";"
[[ -n ${workspace} ]] && remote+=" export KI_AGENT_HOST_WORKSPACE=$(printf '%q' "${workspace}");"
remote+=" exec bash \"\$payload/converge.sh\"$(printf ' %q' "${converge_args[@]}")"
# shellcheck disable=SC2029 # remote is built for the host shell on purpose.
COPYFILE_DISABLE=1 tar ${tar_flags[@]+"${tar_flags[@]}"} -C "${stage}" -cf - . | ssh "${host}" "${remote}"

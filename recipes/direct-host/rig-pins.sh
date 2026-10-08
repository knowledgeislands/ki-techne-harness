#!/usr/bin/env bash
# Rig's observe-only direct-host-pins provider (TECHNE-TOOLS-OPS-014): compares
# a tool's running version with its pin in rig.toml beside this file. converge.sh
# installs it as Rig's provider executable; it never installs anything.
#
# usage: rig-pins.sh rig-provider-v1 observe <provider> <tool> exact|minimum <version>
# Prints one Rig state: present, drifted, missing or unknown.
set -euo pipefail

[[ $# -ge 6 && $1 == rig-provider-v1 ]] || { echo 'rig-pins.sh: expected a rig-provider-v1 call' >&2; exit 2; }
[[ $2 == observe ]] || { echo "rig-pins.sh: $2 is not supported; this provider only observes" >&2; exit 2; }
tool=$4 kind=$5 pin=$6

command -v "${tool}" >/dev/null || { echo missing; exit 0; }
version=$("${tool}" --version 2>/dev/null | grep -Eo '[0-9]+(\.[0-9]+)+' | head -n 1 || true)
[[ -n ${version} ]] || { echo unknown; exit 0; }

case ${kind} in
  exact) [[ ${version} == "${pin}" ]] && echo present || echo drifted ;;
  minimum)
    lowest=$(printf '%s\n%s\n' "${pin}" "${version}" | sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n | head -n 1)
    [[ ${lowest} == "${pin}" ]] && echo present || echo drifted
    ;;
  *) echo "rig-pins.sh: unknown kind ${kind}" >&2; exit 2 ;;
esac

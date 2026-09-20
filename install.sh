#!/usr/bin/env bash

set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
install_dir=${TECHNE_INSTALL_DIR:-"$HOME/.local/bin"}
target="$install_dir/techne"
stage=''

die() {
  printf 'techne: error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install.sh --link

Install a local-development launcher in ${TECHNE_INSTALL_DIR:-$HOME/.local/bin}.
The launcher runs this checkout's apps/cli/src/main.ts through Bun and performs
no download. Homebrew is the supported immutable-release installation channel.
EOF
}

cleanup() {
  if [[ -n "$stage" && -e "$stage" ]]; then
    rm -f -- "$stage"
  fi
}
trap cleanup EXIT HUP INT TERM

case "${1:-}" in
  --link) ;;
  -h | --help)
    usage
    exit 0
    ;;
  '')
    die 'expected --link'
    ;;
  *)
    die "unknown argument: $1"
    ;;
esac

[[ "$#" -eq 1 ]] || die 'installer accepts exactly one argument'
if command -v mise >/dev/null 2>&1; then
  bun_executable=$(cd "$script_dir" && mise which bun) || die 'mise could not resolve the checkout Bun version'
else
  bun_executable=$(command -v bun) || die 'Bun is required for a local link installation'
fi
[[ "$("$bun_executable" --version)" == '1.4.1' ]] || die 'the local checkout requires Bun 1.4.1'

source_entry="$script_dir/apps/cli/src/main.ts"
[[ -f "$source_entry" ]] || die "local source entry not found: $source_entry"

mkdir -p -- "$install_dir"
stage=$(mktemp "$install_dir/.techne.XXXXXX") || die 'could not create staged launcher'
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail'
  printf 'exec %q %q "$@"\n' "$bun_executable" "$source_entry"
} >"$stage"
chmod 755 "$stage"
mv -f -- "$stage" "$target"
stage=''

printf 'techne: linked %s to local Bun source %s\n' "$target" "$source_entry"

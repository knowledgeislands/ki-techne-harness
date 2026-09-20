#!/usr/bin/env bash

set -euo pipefail

version=${1:?usage: release/package.sh <version> <bun-target> <asset-target>}
bun_target=${2:?usage: release/package.sh <version> <bun-target> <asset-target>}
asset_target=${3:?usage: release/package.sh <version> <bun-target> <asset-target>}

[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'techne release: version must be exact v-prefixed semantic version\n' >&2
  exit 2
}

case "$bun_target:$asset_target" in
  bun-darwin-arm64:darwin-arm64 | bun-darwin-x64:darwin-x64 | bun-linux-x64:linux-x64) ;;
  *)
    printf 'techne release: unsupported target pair: %s:%s\n' "$bun_target" "$asset_target" >&2
    exit 2
    ;;
esac

package_version=$(bun -e "console.log((await Bun.file('apps/cli/package.json').json()).version)")
[[ "$version" == "v$package_version" ]] || {
  printf 'techne release: requested %s does not match apps/cli/package.json v%s\n' "$version" "$package_version" >&2
  exit 2
}

stage=$(mktemp -d "${TMPDIR:-/tmp}/techne-release.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT HUP INT TERM
archive="dist/release/techne-${version}-${asset_target}.tar.gz"

mkdir -p dist/release
bun build --compile --minify --target="$bun_target" --outfile "$stage/techne" apps/cli/src/main.ts >&2
chmod 755 "$stage/techne"
tar -czf "$archive" -C "$stage" techne

[[ "$(tar -tzf "$archive")" == 'techne' ]] || {
  printf 'techne release: archive has unexpected contents\n' >&2
  exit 1
}

printf '%s\n' "$archive"

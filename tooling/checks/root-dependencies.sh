#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

nested_modules=$(find "${repo_root}" \
  -path "${repo_root}/.git" -prune -o \
  -path "${repo_root}/node_modules" -prune -o \
  -type d -name node_modules -print -quit)
if [[ -n ${nested_modules} ]]; then
  echo "package-local dependency directory found: ${nested_modules}" >&2
  exit 1
fi

nested_lock=$(find "${repo_root}" \
  -path "${repo_root}/.git" -prune -o \
  -path "${repo_root}/node_modules" -prune -o \
  -type f \( -name bun.lock -o -name bun.lockb -o -name package-lock.json -o -name pnpm-lock.yaml -o -name yarn.lock \) \
  ! -path "${repo_root}/bun.lock" -print -quit)
if [[ -n ${nested_lock} ]]; then
  echo "package-local or foreign lockfile found: ${nested_lock}" >&2
  exit 1
fi

echo 'root-only dependency layout passed'

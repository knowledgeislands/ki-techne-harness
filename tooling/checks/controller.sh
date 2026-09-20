#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

PYTHONDONTWRITEBYTECODE=1 python3 -c 'import pathlib; compile(pathlib.Path("'"${repo_root}"'/apps/controller/src/controller.py").read_text(encoding="utf-8"), "controller.py", "exec")'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "${repo_root}/apps/controller/tests" -p 'test_*.py' -v

jq --exit-status . "${repo_root}/apps/controller/fixtures/targets.local.json" "${repo_root}/apps/controller/fixtures/targets.remote.json" "${repo_root}/apps/controller/fixtures/telegram-update.json" "${repo_root}/deploy/kubernetes/execution/job.example.json" >/dev/null

ruby "${repo_root}/tooling/checks/validate-manifests.rb" \
  "${repo_root}/deploy/kubernetes/controller"/*.yaml \
  "${repo_root}/deploy/kubernetes/target"/*.yaml

ruby -e 'require "yaml"; ARGV.each { |path| YAML.parse_stream(File.read(path)) }' \
  "${repo_root}/infra/aws"/*.yaml

shellcheck \
  "${repo_root}"/tooling/checks/*.sh \
  "${repo_root}"/operations/aws/*.sh \
  "${repo_root}"/operations/aws/controller/*.sh \
  "${repo_root}"/operations/aws/target/*.sh \
  "${repo_root}"/operations/telegram/*.sh \
  "${repo_root}"/deploy/runtime/controller/*.sh \
  "${repo_root}"/deploy/runtime/target/*.sh

if find "${repo_root}" -type d \( -name .venv -o -name venv -o -name __pycache__ \) -print -quit | grep -q .; then
  echo 'package or cache directory found' >&2
  exit 1
fi

"${repo_root}/tooling/checks/root-dependencies.sh"

echo 'offline checks passed'

#!/usr/bin/env bash
set -euo pipefail

proof_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

PYTHONDONTWRITEBYTECODE=1 python3 -c 'import pathlib; compile(pathlib.Path("'"${proof_root}"'/apps/controller/src/controller.py").read_text(encoding="utf-8"), "controller.py", "exec")'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "${proof_root}/apps/controller/tests" -p 'test_*.py' -v

jq --exit-status . "${proof_root}/apps/controller/fixtures/targets.local.json" "${proof_root}/apps/controller/fixtures/targets.remote.json" "${proof_root}/apps/controller/fixtures/telegram-update.json" "${proof_root}/deploy/kubernetes/execution/job.example.json" >/dev/null

ruby "${proof_root}/scripts/validate-manifests.rb" \
  "${proof_root}/deploy/kubernetes/controller"/*.yaml \
  "${proof_root}/deploy/kubernetes/target"/*.yaml

ruby -e 'require "yaml"; ARGV.each { |path| YAML.parse_stream(File.read(path)) }' \
  "${proof_root}/infra/aws"/*.yaml

shellcheck "${proof_root}"/scripts/*.sh

if find "${proof_root}" -type d \( -name .venv -o -name venv -o -name __pycache__ \) -print -quit | grep -q .; then
  echo 'package or cache directory found' >&2
  exit 1
fi

"${proof_root}/scripts/check-root-dependencies.sh"

echo 'offline checks passed'

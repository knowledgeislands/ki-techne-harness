#!/usr/bin/env bash
set -euo pipefail

# Offline checks for the recipe manifests (TECHNE-TOOLS-OPS-012): each passes
# against the first binding, and the check refuses copies of the direct-host
# manifest that declare a field twice, omit one or name an AWS concept outside
# [providers.aws], and a binding whose values the script defaults do not match,
# and copies whose status contract or teardown operations are malformed.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check=${repo_root}/tooling/checks/recipe-manifest.py
manifest=${repo_root}/recipes/direct-host/recipe.toml
binding=${repo_root}/tooling/checks/fixtures/agent-host.binding.toml
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

python3 "${check}" --binding "${binding}" "${repo_root}"/recipes/*/recipe.toml

failures=0
# refuse <case> <expected message> <file> [binding]
refuse() {
  local output
  if output=$(python3 "${check}" ${4:+--binding "$4"} "$3" 2>&1); then
    echo "recipe-manifest: $1 must be refused" >&2
    failures=$((failures + 1))
  elif [[ ${output} != *"$2"* ]]; then
    echo "recipe-manifest: $1 must report '$2', got:" >&2
    echo "${output}" >&2
    failures=$((failures + 1))
  fi
}

# mutate <case> <python expression over the manifest text s>
mutate() {
  python3 -c 'import sys; s = open(sys.argv[1]).read(); exec(sys.argv[2]); open(sys.argv[3], "w").write(s)' \
    "${manifest}" "$2" "${work}/$1.toml"
}

mutate twice 's += "\n[providers.aws.parameters.host_name]\ndefault = \"x\"\n"'
refuse 'a field declared twice' 'host_name is declared more than once' "${work}/twice.toml"

mutate omitted 'import re; s = re.sub(r"\[providers\.aws\.parameters\.volume_size\][^\[]*", "", s)'
refuse 'an omitted field' 'binding field volume_size is not declared' "${work}/omitted.toml"

mutate misplaced 'import re; s = re.sub(r"\[providers\.aws\.parameters\.region\]", "[parameters.region]", s)'
refuse 'a provider field outside its provider' 'region is a provider field' "${work}/misplaced.toml"

mutate concept 's = s.replace("Operating-system host name", "EC2 host name")'
refuse 'an AWS concept in a provider-neutral summary' 'names an AWS concept' "${work}/concept.toml"

mutate neutral-env 's = s.replace("env = \"AGENT_HOST_NAME\"", "env = \"AWS_HOST_NAME\"")'
refuse 'an AWS variable for a provider-neutral field' 'names an AWS concept' "${work}/neutral-env.toml"

mutate neutral-reader 's = s.replace("scripts = [\"provision\", \"stop\", \"destroy\"]", "scripts = [\"setup\", \"provision\", \"stop\", \"destroy\"]", 1)'
refuse 'a provider-neutral script reading a provider field' 'is not a aws script' "${work}/neutral-reader.toml"

mutate list 's = "providers = [\"aws\"]\n" + s'
refuse 'a providers list beside the provider tables' 'not valid TOML' "${work}/list.toml"

# The status contract and teardown operations (TECHNE-TOOLS-OPS-013).
mutate status-schema 's = s.replace("techne/host-workspace/v1", "techne/host-workspace/v0")'
refuse 'another status schema' 'status.schema must be techne/host-workspace/v1' "${work}/status-schema.toml"

mutate status-exit 's = s.replace("unknown = 4", "unknown = 3")'
refuse 'two outcomes sharing an exit status' 'its own exit status' "${work}/status-exit.toml"

mutate operation-script 's = s.replace("script = \"destroy\"", "script = \"teardown\"", 1)'
refuse 'an operation of an undeclared script' 'operations.rebuild names unknown script teardown' "${work}/operation-script.toml"

mutate operation-missing 'import re; s = re.sub(r"\[operations\.withdraw\][^\[]*", "", s)'
refuse 'a missing teardown operation' '[operations] must declare exactly rebuild, withdraw' "${work}/operation-missing.toml"

mutate stop-reader 's = s.replace("env = \"AGENT_HOST_TAILSCALE_NAME\"\nscripts = [\"setup\", \"status\", \"provision\", \"stop\", \"destroy\"]", "env = \"AGENT_HOST_TAILSCALE_NAME\"\nscripts = [\"setup\", \"status\", \"provision\", \"stop\", \"destroy\", \"template\"]")'
refuse 'a parameter naming a script that does not read it' 'does not read AGENT_HOST_TAILSCALE_NAME' "${work}/stop-reader.toml"

sed 's/eu-west-1/eu-central-1/' "${binding}" >"${work}/other-region.toml"
refuse 'a binding the script defaults do not match' 'the default of AWS_REGION must be the binding value' "${manifest}" "${work}/other-region.toml"

((failures == 0)) || exit 1
echo 'recipe manifest checks passed'

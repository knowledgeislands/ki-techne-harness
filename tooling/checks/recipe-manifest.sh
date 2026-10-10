#!/usr/bin/env bash
set -euo pipefail

# Offline checks for the recipe manifests: each passes
# against the first binding, and the check refuses copies of the agent-host
# manifest that declare a field twice, omit one or name an AWS concept outside
# [providers.aws], and a binding whose values the script defaults do not match,
# copies whose status contract or teardown operations are malformed, and copies
# or bindings whose patching declaration or reboot window is malformed.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
check=${repo_root}/tooling/checks/recipe-manifest.py
manifest=${repo_root}/recipes/agent-host/recipe.toml
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

# The status contract and teardown operations.
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

# The patching intent and each provider's mechanism.
mutate patching-missing 'import re; s = re.sub(r"\n\[providers\.aws\.patching\][^\[]*", "\n", s)'
refuse 'a provider without a patching mechanism' '[providers.aws.patching] is required' "${work}/patching-missing.toml"

mutate patching-scope 's = s.replace("unattended = \"security\"", "unattended = \"all\"")'
refuse 'unattended updates beyond security' 'patching.unattended must be one of security' "${work}/patching-scope.toml"

mutate window-default 's = s.replace("[parameters.reboot_window]\nsummary", "[parameters.reboot_window]\ndefault = \"Sun 04:00\"\nsummary").replace("optional = true\nenv = \"AGENT_HOST_REBOOT_WINDOW\"", "env = \"AGENT_HOST_REBOOT_WINDOW\"")'
refuse 'a reboot window carrying a weekday' 'reboot_window must be a daily 24-hour HH:MM with no weekday' "${work}/window-default.toml"

mutate window-both 's = s.replace("[parameters.reboot_window]\nsummary", "[parameters.reboot_window]\ndefault = \"04:00\"\nsummary")'
refuse 'an optional parameter with a default' 'exactly one of required = true, a default or optional = true' "${work}/window-both.toml"

{ echo 'reboot_window = "Sun 04:00"'; cat "${binding}"; } >"${work}/weekday-window.toml"
refuse 'a binding window carrying a weekday' 'reboot_window must be a daily 24-hour HH:MM with no weekday' "${manifest}" "${work}/weekday-window.toml"

{ echo 'livepatch = "yes"'; cat "${binding}"; } >"${work}/livepatch-string.toml"
refuse 'a binding Livepatch that is not a boolean' 'livepatch must be true or false' "${manifest}" "${work}/livepatch-string.toml"

sed 's/eu-west-1/eu-central-1/' "${binding}" >"${work}/other-region.toml"
refuse 'a binding the script defaults do not match' 'the default of AWS_REGION must be the binding value' "${manifest}" "${work}/other-region.toml"

((failures == 0)) || exit 1
echo 'recipe manifest checks passed'

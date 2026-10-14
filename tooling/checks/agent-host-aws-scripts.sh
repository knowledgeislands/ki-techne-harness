#!/usr/bin/env bash
# check() evaluates its single-quoted conditions later, so they must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

# Offline checks for the agent-host AWS scripts. A stub aws records each call,
# and a stub ssh answers the status read with a canned report. With no binding
# variable set, provision.sh, stop.sh and destroy.sh must act on the agent-host
# binding's values exactly; with a second binding's values they must act on those values
# only. stop.sh must warn and still stop; destroy.sh's rebuild and withdraw must
# refuse unless the status is clean or the matching override is given.

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
scripts=${repo_root}/operations/aws/agent-host
work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT

failures=0
check() {
  if eval "$1"; then return 0; fi
  echo "agent-host-aws-scripts: $2" >&2
  failures=$((failures + 1))
}

mkdir "${work}/bin"
cat >"${work}/bin/aws" <<'STUB'
#!/usr/bin/env bash
echo "AWS_PROFILE=${AWS_PROFILE:-} $*" >>"${STUB_LOG}"
case "$1 $2" in
  'sts get-caller-identity') echo "${STUB_ACCOUNT}" ;;
  'cloudformation describe-stacks')
    case $* in
      *AgentHostInstanceId*)
        [[ -z ${STUB_STACK_ABSENT:-} ]] || { echo "An error occurred (ValidationError): Stack with id $6 does not exist" >&2; exit 254; }
        printf '%s\t%s\n' "${STUB_STACK_HOST_ID}" "${STUB_STACK_INSTANCE:-i-0123456789abcdef0}" ;;
      *Stacks\[0\].Outputs*) echo '[]' ;;
      *) exit 255 ;;
    esac ;;
  'ssm describe-parameters')
    if [[ -n ${STUB_KEY_ABSENT:-} && $* == *tailscale-auth-key* ]]; then echo None; else echo SecureString; fi ;;
  'ssm put-parameter') [[ $(cat) == "${STUB_KEY}" ]] && echo 'aws received the minted key on standard input' >>"${STUB_LOG}" ;;
  'ec2 describe-instances') echo i-0123456789abcdef0 ;;
esac
STUB
chmod +x "${work}/bin/aws"

# The Tailscale OAuth stand-ins. Each credential is random per run and reaches
# the stubs only through the environment, so it can be found on disk under
# ${work} only if the script under test puts it there. curl answers the
# configuration it reads on standard input and logs what it saw, never a value.
cat >"${work}/bin/op" <<'STUB'
#!/usr/bin/env bash
echo "op $*" >>"${STUB_LOG}"
case $* in
  "read ${STUB_OP_ITEM}/username") printf '%s\n' "${STUB_CLIENT_ID}" ;;
  "read ${STUB_OP_ITEM}/credential") printf '%s\n' "${STUB_SECRET}" ;;
  *) echo '[ERROR] not signed in' >&2; exit 1 ;;
esac
STUB
cat >"${work}/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >>"${STUB_LOG}"
config=$(cat)
case ${config} in
  *'/oauth/token"'*)
    [[ ${config} == *"client_id=${STUB_CLIENT_ID}\""* && ${config} == *"client_secret=${STUB_SECRET}\""* ]] &&
      echo 'curl token request carries the client' >>"${STUB_LOG}"
    [[ -z ${STUB_TOKEN_REFUSED:-} ]] || { echo 'curl: (22) The requested URL returned error: 401' >&2; exit 22; }
    printf '{"access_token": "%s", "token_type": "Bearer", "expires_in": 3600, "scope": "auth_keys"}' "${STUB_TOKEN}" ;;
  *'/tailnet/-/keys"'*)
    [[ ${config} == *"Authorization: Bearer ${STUB_TOKEN}\""* ]] && echo 'curl key request carries the token' >>"${STUB_LOG}"
    printf '%s\n' "${config}" | sed -n 's/^data-raw = //p' | jq -r . | jq -c . | sed 's/^/curl key body /' >>"${STUB_LOG}"
    printf '{"id": "kStubKeyId", "key": "%s"}' "${STUB_KEY}" ;;
  *) exit 2 ;;
esac
STUB
chmod +x "${work}/bin/op" "${work}/bin/curl"
random() { od -An -N12 -tx1 /dev/urandom | tr -d ' \n'; }
client_id=kStub$(random)
secret=tskey-client-kStub-$(random)
token=tskey-api-kStub-$(random)
key=tskey-auth-kStub-$(random)
op_item='op://Techne/agent-host Tailscale OAuth'
# leaks: every file under ${work} holding a credential, which covers the
# logged arguments of every stub, the script's output and any temporary file.
leaks() { grep -rlF -e "${secret}" -e "${token}" -e "${key}" "${work}" || true; }
mkdir "${work}/tmp"

# ssh answers the status read: STUB_STATUS names a report under reports/, or
# is unreachable (SSH's own 255).
cat >"${work}/bin/ssh" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
echo "ssh $*" >>"${STUB_LOG}"
case ${STUB_STATUS:-clean} in
  unreachable) echo 'ssh: connect to host: Operation timed out' >&2; exit 255 ;;
  malformed) echo 'Repositories under /home/techne/workspaces'; exit 0 ;;
  *) cat "${STUB_REPORTS}/${STUB_STATUS:-clean}.json"; exit "$(cat "${STUB_REPORTS}/${STUB_STATUS:-clean}.exit")" ;;
esac
STUB
chmod +x "${work}/bin/ssh"

# report <name> <exit> <outcome> <repositories JSON> [problems JSON] [instance]
mkdir "${work}/reports"
report() {
  jq -n --arg outcome "$3" --argjson repositories "$4" --argjson problems "${5:-[]}" --arg instance "${6:-i-0123456789abcdef0}" \
    '{schema: "techne/host-workspace/v1", generated_at: "2026-10-08T00:00:00Z",
      host: {hostname: "ki-techne-agent-host", id: $instance}, workspace: "/home/techne/workspaces",
      fetched: false, outcome: $outcome, repositories: $repositories, problems: $problems}' >"${work}/reports/$1.json"
  echo "$2" >"${work}/reports/$1.exit"
}
repo() { printf '{"path": "%s", "state": "%s", "branch": "main", "dirty": %s, "unpushed": %s, "stashes": 0, "upstream": null, "problem": %s}' "$@"; }
report clean 0 clean "[$(repo knowledge-islands/alpha clean 0 0 null)]"
report at-risk 3 at-risk "[$(repo knowledge-islands/alpha at-risk 2 1 null), $(repo knowledge-islands/beta at-risk 0 3 null), $(repo knowledge-islands/gamma clean 0 0 null)]"
report unknown 4 unknown "[$(repo knowledge-islands/alpha unknown 0 0 '"git status failed"')]" '["declared repository knowledge-islands/beta is absent"]'
report other-host 0 clean "[$(repo knowledge-islands/alpha clean 0 0 null)]" '[]' i-0fedcba9876543210
report mismatched 3 clean "[$(repo knowledge-islands/alpha clean 0 0 null)]"

bash_dir=$(dirname "$(command -v bash)")
jq_dir=$(dirname "$(command -v jq)")
# run <script> [argument...] [-- VARIABLE=value...]: runs with no ambient AWS or
# binding variable, reading ${input} as its standard input.
run() {
  local script=$1 arguments=() variables=()
  shift
  while (($#)) && [[ $1 != -- ]]; do arguments+=("$1"); shift; done
  (($#)) && shift
  variables=("$@")
  : >"${work}/aws.log"
  env -i HOME="${work}" TMPDIR="${work}/tmp" PATH="${work}/bin:${bash_dir}:${jq_dir}:/usr/bin:/bin" STUB_LOG="${work}/aws.log" \
    STUB_REPORTS="${work}/reports" STUB_STATUS="${status:-clean}" STUB_STACK_ABSENT="${stack_absent:-}" \
    STUB_KEY_ABSENT="${key_absent:-}" STUB_TOKEN_REFUSED="${token_refused:-}" STUB_OP_ITEM="${op_item}" \
    STUB_CLIENT_ID="${client_id}" STUB_SECRET="${secret}" STUB_TOKEN="${token}" STUB_KEY="${key}" \
    STUB_ACCOUNT="${account:-655383751458}" STUB_STACK_HOST_ID="${stack_host_id:-agent-host}" ${variables[@]+"${variables[@]}"} \
    bash "${scripts}/${script}" ${arguments[@]+"${arguments[@]}"} <<<"${input:-}" >"${work}/out.log" 2>&1
}
log() { cat "${work}/aws.log"; }
out() { cat "${work}/out.log"; }
confirm=CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host

# The first binding, by default.
run provision.sh || { out >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == "AWS_PROFILE=knowledge-islands-techne cloudformation deploy --region eu-west-1 --stack-name ki-techne-agent-host "* ]]' "provision.sh must deploy ki-techne-agent-host in eu-west-1 with the admin profile, got: ${deploy}"
check '[[ ${deploy} == *" --parameter-overrides AgentHostId=agent-host HostName=ki-techne-agent-host TailscaleHostname=ki-techne-agent-host TailscaleTag=tag:ki-techne-agent-host ParameterPrefix=/ki/techne/agent-host InstanceType=t3.medium VolumeSize=40 Shell=zsh --tags ki-agent-host-id=agent-host ki-lifecycle=prototype ki-authority=GDR-KI-PRINCIPAL-004" ]]' "provision.sh must pass the agent-host values, got: ${deploy}"
check 'log | grep -qF "Values=/ki/techne/agent-host/tailscale-auth-key"' 'provision.sh must look for the agent-host auth key'
check '! log | grep -qF ubuntu-pro-token' 'provision.sh must not look for an Ubuntu Pro token without Livepatch'

# Patching: a reboot window and Livepatch pass through
# as overrides, Livepatch needs the Ubuntu Pro token, and a bad window is refused.
run provision.sh -- AGENT_HOST_REBOOT_WINDOW=04:00 AGENT_HOST_LIVEPATCH=true || { out >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == *" VolumeSize=40 Shell=zsh RebootWindow=04:00 Livepatch=true --tags "* ]]' "provision.sh must pass the patching values, got: ${deploy}"
check 'log | grep -qF "Values=/ki/techne/agent-host/ubuntu-pro-token"' 'provision.sh must look for the Ubuntu Pro token with Livepatch'
for bad in AGENT_HOST_REBOOT_WINDOW=4:00 "AGENT_HOST_REBOOT_WINDOW=Sun 04:00" AGENT_HOST_LIVEPATCH=yes AGENT_HOST_SHELL=fish; do
  check '! run provision.sh -- "${bad}" && ! log | grep -qF "cloudformation deploy"' "provision.sh must refuse ${bad}"
done

# Key minting: with no stored key, a configured OAuth client mints one just
# before the deploy; with neither, the hand route is named and nothing is built.
oauth_item="AGENT_HOST_TAILSCALE_OAUTH_ITEM=${op_item}"
key_absent=1 run provision.sh && check false 'provision.sh must refuse a missing key with no OAuth client'
check 'out | grep -qF "store a key by hand, or set AGENT_HOST_TAILSCALE_OAUTH_ITEM" && ! log | grep -qE "^(curl|op) |cloudformation deploy"' "provision.sh must name both routes and build nothing, got: $(out)"

key_absent=1 run provision.sh -- "${oauth_item}" || { out >&2; exit 1; }
check '[[ $(log | grep "^op " | tr "\n" "|") == "op read ${op_item}/username|op read ${op_item}/credential|" ]]' "provision.sh must read the client by its 1Password reference only, got: $(log | grep '^op ')"
check '[[ $(log | grep -c "^curl --silent --show-error --fail --config -$") == 2 ]]' "curl must take each request on standard input with no other argument, got: $(log | grep '^curl ')"
check 'log | grep -qx "curl token request carries the client" && log | grep -qx "curl key request carries the token"' "the requests must carry the client and the token, got: $(log)"
body=$(log | sed -n 's/^curl key body //p')
check 'jq -e --arg tag tag:ki-techne-agent-host '"'"'.capabilities.devices.create == {reusable: false, ephemeral: false, preauthorized: true, tags: [$tag]} and .expirySeconds == 3600'"'"' >/dev/null 2>&1 <<<"${body}"' "the key must be single-use, not ephemeral, pre-approved, tagged and one hour, got: ${body}"
check 'log | grep -qF "ssm put-parameter --region eu-west-1 --name /ki/techne/agent-host/tailscale-auth-key --type SecureString --value file:///dev/stdin" && ! log | grep -qF -- --overwrite && log | grep -qx "aws received the minted key on standard input"' "the key must reach Parameter Store on standard input without overwriting, got: $(log)"
check '[[ $(log | grep -oE "validate-template|put-parameter|cloudformation deploy" | tr "\n" " ") == "validate-template put-parameter cloudformation deploy " ]]' "the key must be minted after validation and before the deploy, got: $(log)"
check 'out | grep -qF "minted Tailscale auth key kStubKeyId for tag:ki-techne-agent-host, single-use and expiring in 60 minutes"' "provision.sh must report the minted key by id, got: $(out)"
check '[[ -z $(leaks) ]]' "a credential reached an argument, the output or disk: $(leaks)"

key_absent=1 run provision.sh -- AGENT_HOST_TAILSCALE_OAUTH_CLIENT_ID="${client_id}" AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET="${secret}" || { out >&2; exit 1; }
check '! log | grep -q "^op " && log | grep -qx "aws received the minted key on standard input"' "provision.sh must mint from an op run environment without 1Password, got: $(log)"
check '[[ -z $(leaks) ]]' "a credential reached an argument, the output or disk: $(leaks)"

run provision.sh -- "${oauth_item}" || { out >&2; exit 1; }
check '! log | grep -qE "^(curl|op) |put-parameter" && log | grep -qF "cloudformation deploy"' "provision.sh must use a stored key without minting, got: $(log)"

key_absent=1 token_refused=1 run provision.sh -- "${oauth_item}" && check false 'provision.sh must stop when Tailscale refuses the client'
check '! log | grep -qE "put-parameter|cloudformation deploy" && [[ -z $(leaks) ]]' "a refused client must store and build nothing and leak nothing, got: $(log)"
key_absent=1 run provision.sh -- AGENT_HOST_TAILSCALE_OAUTH_CLIENT_ID="${client_id}" AGENT_HOST_TAILSCALE_OAUTH_CLIENT_SECRET="not-${secret}" && check false 'provision.sh must refuse a malformed client secret'
check '! log | grep -qE "^curl |cloudformation deploy" && out | grep -qx "the Tailscale OAuth client secret is malformed" && [[ -z $(leaks) ]]' "a malformed secret must be refused unnamed before any request, got: $(out)"

run mint-tailscale-key.sh --check -- "${oauth_item}" || { out >&2; exit 1; }
check 'out | grep -qx "Tailscale accepted the OAuth client (scope: auth_keys); no key was minted" && [[ $(log | grep -c "^curl --") == 1 ]] && ! log | grep -q "^AWS_PROFILE"' "--check must exchange the token only, with no AWS call, got: $(log)"
check '[[ -z $(leaks) ]]' "a credential reached an argument, the output or disk: $(leaks)"
check '! grep -nE "<<|>" "${scripts}/mint-tailscale-key.sh" | grep -vE ">&2|>/dev/null"' 'mint-tailscale-key.sh must use no here-document, here-string or file redirection, which may touch disk'

# stop.sh: reads the status with a short connect timeout, warns, and always stops.
run stop.sh || { out >&2; exit 1; }
check 'log | grep -qF -- "--profile knowledge-islands-techne-agent-host --region eu-west-1 --filters Name=tag:ki-agent-host-id,Values=agent-host Name=tag:ki-lifecycle,Values=prototype Name=tag:Name,Values=ki-techne-agent-host Name=instance-state-name,Values=pending,running"' "stop.sh must select the agent host with the operator profile, got: $(log)"
check 'log | grep -qE "^ssh -o ConnectTimeout=5 .* ki-techne-agent-host bash -s -- --json --expect knowledge-islands/apps-knowledgeislands.info "' "stop.sh must read the status with a short connect timeout and the declared repositories, got: $(log)"
check 'log | grep -qF "ec2 stop-instances" && ! out | grep -q warning' 'stop.sh must stop a clean host without a warning'

status=at-risk run stop.sh || { out >&2; exit 1; }
check 'out | grep -qF "at-risk knowledge-islands/alpha" && out | grep -qF "at-risk knowledge-islands/beta" && ! out | grep -qF gamma' "stop.sh must name the repositories at risk, got: $(out)"
check 'log | grep -qF "ec2 stop-instances"' 'stop.sh must stop a host with work at risk'

status=unknown run stop.sh || { out >&2; exit 1; }
check 'out | grep -qF "unknown knowledge-islands/alpha: git status failed" && out | grep -qF "unknown: declared repository knowledge-islands/beta is absent"' "stop.sh must report unknown work, got: $(out)"
check 'log | grep -qF "ec2 stop-instances"' 'stop.sh must stop a host whose work is unknown'

for case in unreachable malformed mismatched; do
  status=${case} run stop.sh || { out >&2; exit 1; }
  check 'out | grep -qF "status could not be read" && log | grep -qF "ec2 stop-instances"' "stop.sh must warn that a ${case} status could not be read and stop anyway, got: $(out)"
done

status=unreachable run stop.sh --now || { out >&2; exit 1; }
check '! log | grep -q "^ssh" && ! out | grep -q warning && log | grep -qF "ec2 stop-instances"' 'stop.sh --now must stop without reading the status'

cat >"${work}/bin/aws-stopped" <<'STUB'
#!/usr/bin/env bash
[[ "$1 $2" == 'ec2 describe-instances' ]] && { echo "AWS_PROFILE=${AWS_PROFILE:-} $*" >>"${STUB_LOG}"; exit 0; }
exec "$(dirname "$0")/aws-real" "$@"
STUB
mv "${work}/bin/aws" "${work}/bin/aws-real"
cp "${work}/bin/aws-stopped" "${work}/bin/aws"
chmod +x "${work}/bin/aws"
run stop.sh || { out >&2; exit 1; }
check 'out | grep -qx "no running agent host found" && ! log | grep -q "^ssh" && ! log | grep -qF stop-instances' 'stop.sh must leave a stopped host alone without reading its status'
mv "${work}/bin/aws-real" "${work}/bin/aws"

# destroy.sh: rebuild and withdraw.
run destroy.sh || true
check 'out | grep -qF "usage: destroy.sh rebuild|withdraw" && [[ ! -s ${work}/aws.log ]]' 'destroy.sh must refuse to run without an operation'
run destroy.sh withdraw || true
check 'out | grep -qF "set CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host" && [[ ! -s ${work}/aws.log ]]' 'destroy.sh must refuse before any call without the confirmation'
run destroy.sh rebuild --discard knowledge-islands/alpha --discard-unreadable-host -- "${confirm}" || true
check 'out | grep -qF usage && [[ ! -s ${work}/aws.log ]]' 'destroy.sh must refuse both overrides together'

run destroy.sh withdraw -- "${confirm}" || { out >&2; exit 1; }
check 'log | grep -qE "^ssh -o ConnectTimeout=10 .* ki-techne-agent-host bash -s -- --json --expect "' "withdraw must read the status first, got: $(log)"
check 'log | grep -qF "cloudformation delete-stack --profile knowledge-islands-techne --region eu-west-1 --stack-name ki-techne-agent-host"' 'withdraw must delete the agent-host stack'
check 'log | grep -qF -- "--names /ki/techne/agent-host/tailscale-auth-key /ki/techne/agent-host/github-token /ki/techne/agent-host/model-api-key /ki/techne/agent-host/ubuntu-pro-token"' 'withdraw must delete every agent-host parameter'
check 'out | grep -qF "the operator role and its inline policy"' 'withdraw must list the manual footprint'

run destroy.sh rebuild -- "${confirm}" || { out >&2; exit 1; }
check 'log | grep -qF "cloudformation delete-stack" && ! log | grep -q "ssm delete-parameter"' "rebuild must delete the stack and keep every parameter, got: $(log)"
check 'out | grep -qF "Kept /ki/techne/agent-host/github-token and /ki/techne/agent-host/model-api-key" && out | grep -qF "remove the old ki-techne-agent-host device"' 'rebuild must print the rebuild sequence'

for operation in rebuild withdraw; do
  status=at-risk run destroy.sh "${operation}" -- "${confirm}" && check false "${operation} must refuse work at risk"
  check '! log | grep -q delete && out | grep -qF "knowledge-islands/alpha: 2 uncommitted, 1 unpushed" && out | grep -qF -- "--discard knowledge-islands/alpha knowledge-islands/beta" && out | grep -qF "git bundle create"' "${operation} must refuse, list the work at risk and the recovery routes, got: $(out)"
done
status=at-risk run destroy.sh withdraw --discard knowledge-islands/alpha -- "${confirm}" && check false 'withdraw must refuse a discard that omits a repository at risk'
check '! log | grep -q delete' 'withdraw must delete nothing when the discard omits a repository'
status=at-risk run destroy.sh withdraw --discard knowledge-islands/alpha knowledge-islands/beta knowledge-islands/gamma -- "${confirm}" && check false 'withdraw must refuse a discard naming a repository not at risk'
status=at-risk run destroy.sh withdraw --discard-unreadable-host -- "${confirm}" && check false 'withdraw must refuse the unreadable-host override for a readable host'
status=at-risk run destroy.sh rebuild --discard knowledge-islands/beta knowledge-islands/alpha -- "${confirm}" || { out >&2; exit 1; }
check 'log | grep -qF "cloudformation delete-stack" && out | grep -qF "discarding the at-risk work in: knowledge-islands/alpha knowledge-islands/beta"' "rebuild must proceed when the discard names exactly the work at risk, got: $(out)"

run destroy.sh withdraw --discard knowledge-islands/alpha -- "${confirm}" && check false 'withdraw must refuse a discard when nothing is at risk'

for case in unknown unreachable malformed mismatched; do
  status=${case} run destroy.sh withdraw -- "${confirm}" && check false "withdraw must refuse a ${case} status"
  check '! log | grep -q delete && out | grep -qF -- "--discard-unreadable-host"' "withdraw must refuse a ${case} status and name the override, got: $(out)"
  status=${case} input='discard ki-techne-agent-host' run destroy.sh withdraw --discard-unreadable-host -- "${confirm}" || { out >&2; exit 1; }
  check 'log | grep -qF "cloudformation delete-stack" && log | grep -qF "ssm delete-parameters"' "withdraw must proceed for a ${case} status with the override and confirmation, got: $(out)"
done
status=unknown run destroy.sh withdraw --discard knowledge-islands/alpha -- "${confirm}" && check false 'withdraw must refuse a named discard for an unknown status'
status=unreachable input='yes' run destroy.sh withdraw --discard-unreadable-host -- "${confirm}" && check false 'withdraw must refuse a wrong typed confirmation'
check '! log | grep -q delete && out | grep -qF "confirmation did not match"' 'withdraw must delete nothing without the typed confirmation'

status=other-host run destroy.sh rebuild -- "${confirm}" && check false 'rebuild must refuse a status from another instance'
check '! log | grep -q delete && out | grep -qF "the status came from instance i-0fedcba9876543210, but stack ki-techne-agent-host holds i-0123456789abcdef0"' "rebuild must name both instances, got: $(out)"

# A stack that is already gone: no guard, and withdrawal still removes the parameters.
stack_absent=1 status=unreachable run destroy.sh withdraw -- "${confirm}" || { out >&2; exit 1; }
check '! log | grep -q "^ssh" && ! log | grep -qF delete-stack && log | grep -qF "ssm delete-parameters" && out | grep -qF "already gone"' "a rerun withdraw must skip the gone stack and remove the parameters, got: $(out)"
stack_absent=1 run destroy.sh rebuild -- "${confirm}" || { out >&2; exit 1; }
check '! log | grep -q delete' 'a rerun rebuild must change nothing'

# A second binding's values, on another account and region.
scratch=(
  AWS_PROFILE=scratch-admin AWS_REGION=eu-central-1 EXPECTED_AWS_ACCOUNT=111111111111
  AGENT_HOST_ID=scratch AGENT_HOST_NAME=ki-techne-scratch AGENT_HOST_TAILSCALE_NAME=scratch-tail
  AGENT_HOST_TAILSCALE_TAG=tag:ki-techne-scratch AGENT_HOST_STACK_NAME=ki-techne-scratch
  AGENT_HOST_PARAMETER_PREFIX=/ki/techne/scratch/ AGENT_HOST_INSTANCE_TYPE=t3.large AGENT_HOST_VOLUME_SIZE=60 AGENT_HOST_SHELL=bash
  AGENT_HOST_REPOSITORIES="${work}/scratch-repositories.txt"
)
printf '# scratch\nscratch/one https://example.invalid/one.git\n' >"${work}/scratch-repositories.txt"
account=111111111111 stack_host_id=scratch
run provision.sh -- "${scratch[@]}" || { out >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == "AWS_PROFILE=scratch-admin cloudformation deploy --region eu-central-1 --stack-name ki-techne-scratch "*" --parameter-overrides AgentHostId=scratch HostName=ki-techne-scratch TailscaleHostname=scratch-tail TailscaleTag=tag:ki-techne-scratch ParameterPrefix=/ki/techne/scratch InstanceType=t3.large VolumeSize=60 Shell=bash --tags ki-agent-host-id=scratch "* ]]' "provision.sh must pass the second binding's values, got: ${deploy}"
check '! log | grep -qE "=agent-host( |$)|ki-techne-agent-host|/ki/techne/agent-host|655383751458|eu-west-1"' "provision.sh must not reach the first binding, got: $(log)"
key_absent=1 run provision.sh -- "${scratch[@]}" "${oauth_item}" || { out >&2; exit 1; }
check 'log | grep -qF "ssm put-parameter --region eu-central-1 --name /ki/techne/scratch/tailscale-auth-key " && log | grep -qF "\"tags\":[\"tag:ki-techne-scratch\"]" && log | grep -qF "\"description\":\"ki-techne scratch build\""' "minting must use the second binding's tag, region and prefix, got: $(log)"
check '! log | grep -qE "=agent-host( |$)|ki-techne-agent-host|/ki/techne/agent-host|655383751458|eu-west-1"' "minting must not reach the first binding, got: $(log)"

run stop.sh -- "${scratch[@]/AWS_PROFILE=scratch-admin/AWS_PROFILE=scratch-operator}" || { out >&2; exit 1; }
check 'log | grep -qF -- "--profile scratch-operator --region eu-central-1 --filters Name=tag:ki-agent-host-id,Values=scratch Name=tag:ki-lifecycle,Values=prototype Name=tag:Name,Values=ki-techne-scratch "' "stop.sh must select the second binding's host, got: $(log)"
check 'log | grep -qF "scratch-tail bash -s -- --json --expect scratch/one"' "stop.sh must read the second binding's host and repositories, got: $(log)"

run destroy.sh withdraw -- "${scratch[@]}" CONFIRM_DESTROY_AGENT_HOST=ki-techne-scratch || { out >&2; exit 1; }
check 'log | grep -qF -- "--stack-name ki-techne-scratch" && log | grep -qF -- "--names /ki/techne/scratch/tailscale-auth-key" && log | grep -qF "scratch-tail bash -s"' "withdraw must read and remove the second binding's host, stack and parameters, got: $(log)"
check '! log | grep -qE "=agent-host( |$)|ki-techne-agent-host|/ki/techne/agent-host|655383751458|eu-west-1"' "withdraw must not reach the first binding, got: $(log)"

# destroy.sh refuses a stack whose host id tag is not the binding's.
stack_host_id=agent-host
run destroy.sh withdraw -- "${scratch[@]}" CONFIRM_DESTROY_AGENT_HOST=ki-techne-scratch && check false 'withdraw must refuse a stack tagged for another binding'
check 'out | grep -qF "refusing unrecognised stack ki-techne-scratch" && ! log | grep -q delete-stack' 'withdraw must not delete a stack tagged for another binding'

((failures == 0)) || exit 1
echo 'agent-host AWS script checks passed'

#!/usr/bin/env bash
# check() evaluates its single-quoted conditions later, so they must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

# Offline checks for the agent-host AWS scripts (TECHNE-TOOLS-OPS-012,
# TECHNE-TOOLS-OPS-013). A stub aws records each call, and a stub ssh answers
# the status read with a canned report. With no binding variable set,
# provision.sh, stop.sh and destroy.sh must act on the agent-host binding's
# values exactly; with a second binding's values they must act on those values
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
  'ssm describe-parameters') echo SecureString ;;
  'ec2 describe-instances') echo i-0123456789abcdef0 ;;
esac
STUB
chmod +x "${work}/bin/aws"

# ssh answers the status read: STUB_STATUS names a report under reports/, or
# is unreachable (SSH's own 255).
cat >"${work}/bin/ssh" <<'STUB'
#!/usr/bin/env bash
cat >/dev/null
echo "ssh $*" >>"${STUB_LOG}"
case ${STUB_STATUS:-clean} in
  unreachable) echo 'ssh: connect to host: Operation timed out' >&2; exit 255 ;;
  malformed) echo 'Repositories under /home/techne/workspaces/kit'; exit 0 ;;
  *) cat "${STUB_REPORTS}/${STUB_STATUS:-clean}.json"; exit "$(cat "${STUB_REPORTS}/${STUB_STATUS:-clean}.exit")" ;;
esac
STUB
chmod +x "${work}/bin/ssh"

# report <name> <exit> <outcome> <repositories JSON> [problems JSON] [instance]
mkdir "${work}/reports"
report() {
  jq -n --arg outcome "$3" --argjson repositories "$4" --argjson problems "${5:-[]}" --arg instance "${6:-i-0123456789abcdef0}" \
    '{schema: "techne/host-workspace/v1", generated_at: "2026-10-08T00:00:00Z",
      host: {hostname: "ki-techne-agent-host", id: $instance}, workspace: "/home/techne/workspaces/kit",
      fetched: false, outcome: $outcome, repositories: $repositories, problems: $problems}' >"${work}/reports/$1.json"
  echo "$2" >"${work}/reports/$1.exit"
}
repo() { printf '{"path": "%s", "state": "%s", "branch": "main", "dirty": %s, "unpushed": %s, "stashes": 0, "upstream": null, "problem": %s}' "$@"; }
report clean 0 clean "[$(repo knowledgeislands/alpha clean 0 0 null)]"
report at-risk 3 at-risk "[$(repo knowledgeislands/alpha at-risk 2 1 null), $(repo knowledgeislands/beta at-risk 0 3 null), $(repo knowledgeislands/gamma clean 0 0 null)]"
report unknown 4 unknown "[$(repo knowledgeislands/alpha unknown 0 0 '"git status failed"')]" '["declared repository knowledgeislands/beta is absent"]'
report other-host 0 clean "[$(repo knowledgeislands/alpha clean 0 0 null)]" '[]' i-0fedcba9876543210
report mismatched 3 clean "[$(repo knowledgeislands/alpha clean 0 0 null)]"

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
  env -i HOME="${work}" PATH="${work}/bin:${bash_dir}:${jq_dir}:/usr/bin:/bin" STUB_LOG="${work}/aws.log" \
    STUB_REPORTS="${work}/reports" STUB_STATUS="${status:-clean}" STUB_STACK_ABSENT="${stack_absent:-}" \
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
check '[[ ${deploy} == *" --parameter-overrides AgentHostId=agent-host HostName=ki-techne-agent-host TailscaleHostname=ki-techne-agent-host TailscaleTag=tag:ki-techne-agent-host ParameterPrefix=/ki/techne/agent-host InstanceType=t3.medium VolumeSize=40 --tags ki-agent-host-id=agent-host ki-lifecycle=prototype ki-work-item=KI-ARCADIA-GOV-020" ]]' "provision.sh must pass the agent-host values, got: ${deploy}"
check 'log | grep -qF "Values=/ki/techne/agent-host/tailscale-auth-key"' 'provision.sh must look for the agent-host auth key'
check '! log | grep -qF ubuntu-pro-token' 'provision.sh must not look for an Ubuntu Pro token without Livepatch'

# Patching (TECHNE-TOOLS-OPS-022): a reboot window and Livepatch pass through
# as overrides, Livepatch needs the Ubuntu Pro token, and a bad window is refused.
run provision.sh -- AGENT_HOST_REBOOT_WINDOW=04:00 AGENT_HOST_LIVEPATCH=true || { out >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == *" VolumeSize=40 RebootWindow=04:00 Livepatch=true --tags "* ]]' "provision.sh must pass the patching values, got: ${deploy}"
check 'log | grep -qF "Values=/ki/techne/agent-host/ubuntu-pro-token"' 'provision.sh must look for the Ubuntu Pro token with Livepatch'
for bad in AGENT_HOST_REBOOT_WINDOW=4:00 "AGENT_HOST_REBOOT_WINDOW=Sun 04:00" AGENT_HOST_LIVEPATCH=yes; do
  check '! run provision.sh -- "${bad}" && ! log | grep -qF "cloudformation deploy"' "provision.sh must refuse ${bad}"
done

# stop.sh: reads the status with a short connect timeout, warns, and always stops.
run stop.sh || { out >&2; exit 1; }
check 'log | grep -qF -- "--profile knowledge-islands-techne-agent-host --region eu-west-1 --filters Name=tag:ki-agent-host-id,Values=agent-host Name=tag:ki-lifecycle,Values=prototype Name=tag:Name,Values=ki-techne-agent-host Name=instance-state-name,Values=pending,running"' "stop.sh must select the agent host with the operator profile, got: $(log)"
check 'log | grep -qE "^ssh -o ConnectTimeout=5 .* ki-techne-agent-host bash -s -- --json --expect knowledgeislands/apps-observatory "' "stop.sh must read the status with a short connect timeout and the declared repositories, got: $(log)"
check 'log | grep -qF "ec2 stop-instances" && ! out | grep -q warning' 'stop.sh must stop a clean host without a warning'

status=at-risk run stop.sh || { out >&2; exit 1; }
check 'out | grep -qF "at-risk knowledgeislands/alpha" && out | grep -qF "at-risk knowledgeislands/beta" && ! out | grep -qF gamma' "stop.sh must name the repositories at risk, got: $(out)"
check 'log | grep -qF "ec2 stop-instances"' 'stop.sh must stop a host with work at risk'

status=unknown run stop.sh || { out >&2; exit 1; }
check 'out | grep -qF "unknown knowledgeislands/alpha: git status failed" && out | grep -qF "unknown: declared repository knowledgeislands/beta is absent"' "stop.sh must report unknown work, got: $(out)"
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
run destroy.sh rebuild --discard knowledgeislands/alpha --discard-unreadable-host -- "${confirm}" || true
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
  check '! log | grep -q delete && out | grep -qF "knowledgeislands/alpha: 2 uncommitted, 1 unpushed" && out | grep -qF -- "--discard knowledgeislands/alpha knowledgeislands/beta" && out | grep -qF "git bundle create"' "${operation} must refuse, list the work at risk and the recovery routes, got: $(out)"
done
status=at-risk run destroy.sh withdraw --discard knowledgeislands/alpha -- "${confirm}" && check false 'withdraw must refuse a discard that omits a repository at risk'
check '! log | grep -q delete' 'withdraw must delete nothing when the discard omits a repository'
status=at-risk run destroy.sh withdraw --discard knowledgeislands/alpha knowledgeislands/beta knowledgeislands/gamma -- "${confirm}" && check false 'withdraw must refuse a discard naming a repository not at risk'
status=at-risk run destroy.sh withdraw --discard-unreadable-host -- "${confirm}" && check false 'withdraw must refuse the unreadable-host override for a readable host'
status=at-risk run destroy.sh rebuild --discard knowledgeislands/beta knowledgeislands/alpha -- "${confirm}" || { out >&2; exit 1; }
check 'log | grep -qF "cloudformation delete-stack" && out | grep -qF "discarding the at-risk work in: knowledgeislands/alpha knowledgeislands/beta"' "rebuild must proceed when the discard names exactly the work at risk, got: $(out)"

run destroy.sh withdraw --discard knowledgeislands/alpha -- "${confirm}" && check false 'withdraw must refuse a discard when nothing is at risk'

for case in unknown unreachable malformed mismatched; do
  status=${case} run destroy.sh withdraw -- "${confirm}" && check false "withdraw must refuse a ${case} status"
  check '! log | grep -q delete && out | grep -qF -- "--discard-unreadable-host"' "withdraw must refuse a ${case} status and name the override, got: $(out)"
  status=${case} input='discard ki-techne-agent-host' run destroy.sh withdraw --discard-unreadable-host -- "${confirm}" || { out >&2; exit 1; }
  check 'log | grep -qF "cloudformation delete-stack" && log | grep -qF "ssm delete-parameters"' "withdraw must proceed for a ${case} status with the override and confirmation, got: $(out)"
done
status=unknown run destroy.sh withdraw --discard knowledgeislands/alpha -- "${confirm}" && check false 'withdraw must refuse a named discard for an unknown status'
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
  AGENT_HOST_PARAMETER_PREFIX=/ki/techne/scratch/ AGENT_HOST_INSTANCE_TYPE=t3.large AGENT_HOST_VOLUME_SIZE=60
  AGENT_HOST_REPOSITORIES="${work}/scratch-repositories.txt"
)
printf '# scratch\nscratch/one https://example.invalid/one.git\n' >"${work}/scratch-repositories.txt"
account=111111111111 stack_host_id=scratch
run provision.sh -- "${scratch[@]}" || { out >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == "AWS_PROFILE=scratch-admin cloudformation deploy --region eu-central-1 --stack-name ki-techne-scratch "*" --parameter-overrides AgentHostId=scratch HostName=ki-techne-scratch TailscaleHostname=scratch-tail TailscaleTag=tag:ki-techne-scratch ParameterPrefix=/ki/techne/scratch InstanceType=t3.large VolumeSize=60 --tags ki-agent-host-id=scratch "* ]]' "provision.sh must pass the second binding's values, got: ${deploy}"
check '! log | grep -qE "=agent-host( |$)|ki-techne-agent-host|/ki/techne/agent-host|655383751458|eu-west-1"' "provision.sh must not reach the first binding, got: $(log)"

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

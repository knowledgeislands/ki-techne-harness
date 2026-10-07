#!/usr/bin/env bash
# check() evaluates its single-quoted conditions later, so they must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

# Offline checks for the agent-host AWS scripts (TECHNE-TOOLS-OPS-012). A stub
# aws records each call. With no binding variable set, provision.sh, stop.sh
# and destroy.sh must act on the agent-host binding's values exactly; with a
# second binding's values they must act on those values only.

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
      *Stacks\[0\].Tags*) echo "${STUB_STACK_HOST_ID}" ;;
      *Stacks\[0\].Outputs*) echo '[]' ;;
      *) exit 255 ;;
    esac ;;
  'ssm describe-parameters') echo SecureString ;;
  'ec2 describe-instances') echo i-0123456789abcdef0 ;;
esac
STUB
chmod +x "${work}/bin/aws"

bash_dir=$(dirname "$(command -v bash)")
# run <script> [VARIABLE=value...]: runs with no ambient AWS or binding variable.
run() {
  local script=$1
  shift
  : >"${work}/aws.log"
  env -i HOME="${work}" PATH="${work}/bin:${bash_dir}:/usr/bin:/bin" STUB_LOG="${work}/aws.log" \
    STUB_ACCOUNT="${account:-655383751458}" STUB_STACK_HOST_ID="${stack_host_id:-agent-host}" "$@" \
    bash "${scripts}/${script}" >"${work}/out.log" 2>&1
}
log() { cat "${work}/aws.log"; }

# The first binding, by default.
run provision.sh || { cat "${work}/out.log" >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == "AWS_PROFILE=knowledge-islands-techne cloudformation deploy --region eu-west-1 --stack-name ki-techne-agent-host "* ]]' "provision.sh must deploy ki-techne-agent-host in eu-west-1 with the admin profile, got: ${deploy}"
check '[[ ${deploy} == *" --parameter-overrides AgentHostId=agent-host HostName=ki-techne-agent-host TailscaleHostname=ki-techne-agent-host TailscaleTag=tag:ki-techne-agent-host ParameterPrefix=/ki/techne/agent-host InstanceType=t3.medium VolumeSize=40 --tags ki-agent-host-id=agent-host ki-lifecycle=prototype ki-work-item=KI-ARCADIA-GOV-020" ]]' "provision.sh must pass the agent-host values, got: ${deploy}"
check 'log | grep -qF "Values=/ki/techne/agent-host/tailscale-auth-key"' 'provision.sh must look for the agent-host auth key'

run stop.sh || { cat "${work}/out.log" >&2; exit 1; }
check 'log | grep -qF -- "--profile knowledge-islands-techne-agent-host --region eu-west-1 --filters Name=tag:ki-agent-host-id,Values=agent-host Name=tag:ki-lifecycle,Values=prototype Name=tag:Name,Values=ki-techne-agent-host Name=instance-state-name,Values=pending,running"' "stop.sh must select the agent host with the operator profile, got: $(log)"

run destroy.sh || true
check 'grep -qF "set CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host" "${work}/out.log" && [[ ! -s ${work}/aws.log ]]' 'destroy.sh must refuse before any call without the confirmation'
run destroy.sh CONFIRM_DESTROY_AGENT_HOST=ki-techne-agent-host || { cat "${work}/out.log" >&2; exit 1; }
check 'log | grep -qF "cloudformation delete-stack --profile knowledge-islands-techne --region eu-west-1 --stack-name ki-techne-agent-host"' 'destroy.sh must delete the agent-host stack'
check 'log | grep -qF -- "--names /ki/techne/agent-host/tailscale-auth-key /ki/techne/agent-host/github-token /ki/techne/agent-host/model-api-key"' 'destroy.sh must delete the agent-host parameters'

# A second binding's values, on another account and region.
scratch=(
  AWS_PROFILE=scratch-admin AWS_REGION=eu-central-1 EXPECTED_AWS_ACCOUNT=111111111111
  AGENT_HOST_ID=scratch AGENT_HOST_NAME=ki-techne-scratch AGENT_HOST_TAILSCALE_NAME=scratch-tail
  AGENT_HOST_TAILSCALE_TAG=tag:ki-techne-scratch AGENT_HOST_STACK_NAME=ki-techne-scratch
  AGENT_HOST_PARAMETER_PREFIX=/ki/techne/scratch/ AGENT_HOST_INSTANCE_TYPE=t3.large AGENT_HOST_VOLUME_SIZE=60
)
account=111111111111 stack_host_id=scratch
run provision.sh "${scratch[@]}" || { cat "${work}/out.log" >&2; exit 1; }
deploy=$(grep ' cloudformation deploy ' "${work}/aws.log")
check '[[ ${deploy} == "AWS_PROFILE=scratch-admin cloudformation deploy --region eu-central-1 --stack-name ki-techne-scratch "*" --parameter-overrides AgentHostId=scratch HostName=ki-techne-scratch TailscaleHostname=scratch-tail TailscaleTag=tag:ki-techne-scratch ParameterPrefix=/ki/techne/scratch InstanceType=t3.large VolumeSize=60 --tags ki-agent-host-id=scratch "* ]]' "provision.sh must pass the second binding's values, got: ${deploy}"
check '! log | grep -qE "=agent-host( |$)|ki-techne-agent-host|/ki/techne/agent-host|655383751458|eu-west-1"' "provision.sh must not reach the first binding, got: $(log)"

run stop.sh "${scratch[@]/AWS_PROFILE=scratch-admin/AWS_PROFILE=scratch-operator}" || { cat "${work}/out.log" >&2; exit 1; }
check 'log | grep -qF -- "--profile scratch-operator --region eu-central-1 --filters Name=tag:ki-agent-host-id,Values=scratch Name=tag:ki-lifecycle,Values=prototype Name=tag:Name,Values=ki-techne-scratch "' "stop.sh must select the second binding's host, got: $(log)"

run destroy.sh "${scratch[@]}" CONFIRM_DESTROY_AGENT_HOST=ki-techne-scratch || { cat "${work}/out.log" >&2; exit 1; }
check 'log | grep -qF -- "--stack-name ki-techne-scratch" && log | grep -qF -- "--names /ki/techne/scratch/tailscale-auth-key"' "destroy.sh must remove the second binding's stack and parameters, got: $(log)"
check '! log | grep -qE "=agent-host( |$)|ki-techne-agent-host|/ki/techne/agent-host|655383751458|eu-west-1"' "destroy.sh must not reach the first binding, got: $(log)"

# destroy.sh refuses a stack whose host id tag is not the binding's.
stack_host_id=agent-host
run destroy.sh "${scratch[@]}" CONFIRM_DESTROY_AGENT_HOST=ki-techne-scratch && check false 'destroy.sh must refuse a stack tagged for another binding'
check 'grep -qF "refusing unrecognised stack ki-techne-scratch" "${work}/out.log" && ! log | grep -q delete-stack' 'destroy.sh must not delete a stack tagged for another binding'

((failures == 0)) || exit 1
echo 'agent-host AWS script checks passed'

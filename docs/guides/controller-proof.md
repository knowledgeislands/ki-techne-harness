# Controller proof operations

This guide operates the `TECHNE-OPS-007` proof: one retained, single-node K3s controller cluster connected to Telegram, plus zero or more independently registered Kubernetes execution targets. The controller may use its own cluster as the `local` target. Additional targets are disposable capacity and do not become durable authority.

Techne Principal owns the architecture, security boundaries, decision criteria and retained proof evidence. This repository owns the runnable controller, bootstrap flow, Kubernetes resources, AWS templates, provider scripts and operational guide. The original migration boundary and source commits are recorded in the [repository overview](../../README.md).

## Operating model

- The controller is a single-replica Kubernetes Deployment using the `Recreate` strategy.
- Telegram is an outbound command channel. The controller exposes no webhook, Service, Ingress or public controller endpoint.
- The retained controller cluster is replaceable infrastructure, not durable work authority.
- Each command becomes a deterministic Kubernetes Job. The execution identity derives from the Telegram update ID and target ID.
- Replayed Telegram updates reconcile with the existing Job instead of creating duplicate work.
- Kubernetes objects and Telegram's confirmed-update boundary provide recovery. The proof deliberately has no SQLite database, operational journal or workflow engine.
- The `local` target uses the controller's restricted in-cluster ServiceAccount. Remote targets use separately scoped, time-bounded credentials.
- Workload Pods receive no Telegram token, AWS credential, controller credential or Kubernetes service-account token.

## Repository locations

- `apps/cli/` — typed `techne` operator command-line application.
- `apps/controller/` — dependency-free Python controller, fixtures and unit tests.
- `deploy/kubernetes/controller/` — controller namespaces, RBAC, configuration, network policy and Deployment.
- `deploy/kubernetes/execution/` — deterministic Job envelope.
- `deploy/kubernetes/target/` — namespace-scoped remote-target access.
- `infra/aws/` — retained-controller and disposable-target CloudFormation templates.
- `scripts/` — verification, upload, registration and lifecycle commands.

Install dependencies only at the repository root. Package-local `node_modules` directories and package-local lockfiles are prohibited and fail the repository gate.

## Defaults and cost boundary

The scripts default to:

- AWS account `655383751458`;
- profile `knowledge-islands-techne`;
- region `eu-west-1`;
- controller stack `ki-techne-ops-007-controller`;
- controller instance type `t3.medium`;
- target ID `target-001`;
- target stack `ki-techne-ops-007-target-001`.

The retained controller planning target is US$40 per month with a US$50 planning ceiling under ordinary proof traffic. This is an architectural guard, not a billing cap. The disposable target carries an expiry tag and shutdown backstop, but the teardown script remains the required cleanup mechanism.

## Security invariants

Never place the Telegram token, numeric operator identifiers, target bearer token, kubeconfig or AWS session material in Git, chat, command arguments, SSM Run Command parameters or retained evidence.

Credential admission is deliberately interactive. The Telegram values move directly from the operator's private terminal through an interactive SSM session into a Kubernetes Secret. A remote target token moves only between private interactive sessions and into the controller cluster Secret.

Before Telegram credentials are admitted, K3s must report both:

```text
Encryption Status: Enabled
Current Rotation Stage: reencrypt_finished
```

The bootstrap refuses to continue if either condition is absent.

## Prerequisites

The operator needs:

- Bun `1.4.1` and Node.js 22 or later;
- AWS CLI with the `knowledge-islands-techne` SSO profile;
- AWS Session Manager support;
- `jq`, Ruby and ShellCheck for repository verification;
- control of `@kitteth_bot` and its current BotFather token;
- one private Telegram message from the intended operator when discovering the initial offset.

Work from a checkout of the repository root:

```sh
cd /path/to/ki-techne-tools
./install.sh --link
techne diag
```

The local link runs the checkout source through Bun. `techne diag` is offline and reports installation provenance, runtime, executable path, working directory and effective non-secret controller configuration. A Homebrew installation instead uses the compiled release artifact and does not require Bun at runtime.

## Verify the repository

Run the complete local gate without installing dependencies in a subdirectory:

```sh
bun install
bun run test
```

The gate checks the root-only dependency layout, controller syntax, controller unit tests, JSON and Kubernetes manifests, shell syntax and ShellCheck.

Check the local AWS tooling, Session Manager plugin and expected AWS identity:

```sh
techne doctor
```

Doctor explains the active installation mode, checks Bun only for local source installations, then checks the AWS CLI, Session Manager plugin and expected AWS identity needed by controller operations.

Validate both AWS templates using the intended account and region:

```sh
aws sso login --profile knowledge-islands-techne
AWS_PROFILE=knowledge-islands-techne AWS_REGION=eu-west-1 bun run self:aws:validate
```

## Telegram preflight

Perform this in a private terminal. Read the token silently so it does not enter shell history:

```sh
read -rs 'TELEGRAM_BOT_TOKEN?Bot token: '
echo
export TELEGRAM_BOT_TOKEN
./scripts/telegram-preflight.sh
```

The preflight requires the identity `@kitteth_bot` and refuses an active webhook so polling cannot silently displace another integration.

Discover the intended private operator update without confirming or deleting it:

```sh
./scripts/discover-operator.sh
```

Confirm the intended update locally and retain its `user_id`, `chat_id` and `initial_offset` only for the interactive bootstrap. Do not paste those values into chat or commit them.

## Retained controller lifecycle

### Inspect or create the stack

Authenticate and inspect the expected stack first:

```sh
aws sso login --profile knowledge-islands-techne
techne controller status
```

Create it only when the stack is absent:

```sh
./scripts/provision-controller.sh
```

The template creates a `t3.medium` controller with a 16 GiB encrypted gp3 volume, IMDSv2, SSM access and no inbound security-group rules. Its public IPv4 address exists only for outbound internet access.

### Upload the secret-free package

Upload the controller source, manifests and lifecycle scripts through SSM Run Command:

```sh
./scripts/upload-package.sh
```

The upload contains no credential. It replaces `/opt/ki-techne-tools` on the retained host and reports the SSM command result.

### Enable and verify Secret encryption

For an existing cluster, run the supported single-server K3s rotation sequence and wait for re-encryption:

```sh
bun run self:controller:encrypt-secrets
```

New controller stacks start K3s with Secret encryption enabled, but the same verification remains mandatory before credential admission.

### Bootstrap credentials and deploy

Run the local launcher:

```sh
techne controller bootstrap
```

The launcher verifies AWS account `655383751458`, resolves the retained controller instance and opens an interactive SSM command. The remote bootstrap then:

1. verifies or completes K3s Secret encryption;
2. reads the Telegram token silently;
3. reads the operator user ID, chat ID and initial offset;
4. applies controller namespaces, service accounts, RBAC, ConfigMap and network policy;
5. creates or updates the encrypted Kubernetes Secret;
6. applies the single-replica controller Deployment and waits for readiness.

The values live only in the interactive processes and the Kubernetes Secret. Close the private terminal after bootstrap so they do not remain exported in a shell.

### Verify the deployment without reading secrets

Resolve the instance and open a normal interactive SSM session:

```sh
controller_instance_id=$(aws cloudformation describe-stacks \
  --profile knowledge-islands-techne \
  --region eu-west-1 \
  --stack-name ki-techne-ops-007-controller \
  --query 'Stacks[0].Outputs[?OutputKey==`ControllerInstanceId`].OutputValue | [0]' \
  --output text)
aws ssm start-session \
  --profile knowledge-islands-techne \
  --region eu-west-1 \
  --target "$controller_instance_id"
```

On the controller, run:

```sh
sudo k3s secrets-encrypt status
sudo k3s kubectl -n techne-controller rollout status deployment/techne-controller
sudo k3s kubectl -n techne-controller get deployment,pod,configmap,secret
sudo k3s kubectl auth can-i create jobs.batch \
  --as=system:serviceaccount:techne-controller:techne-controller \
  -n techne-execution
sudo k3s kubectl auth can-i get pods/log \
  --as=system:serviceaccount:techne-controller:techne-controller \
  -n techne-execution
```

Inspect object names and status only. Do not print or decode the Secret.

## Exercise the local target

Send these commands privately to `@kitteth_bot`:

```text
/targets
/run local
```

The target list must contain `local`. A run first reports the Telegram update ID and deterministic Job name, then returns the workload result. The Job is namespaced under `techne-execution`, runs without a service-account token and emits an evidence envelope containing its deterministic execution identity.

Repeatable safety checks are:

- send `/run missing` and confirm a visible rejection without a Job;
- send malformed `/run` or `/cancel` input and confirm the usage response;
- use `/cancel local <execution-update-id>` and confirm the deterministic Job is deleted or reported already absent;
- restart the controller Pod and confirm the Deployment returns to one ready replica;
- inspect Jobs before and after restart to confirm deterministic names are not duplicated.

The unit suite deterministically covers duplicate-update reconciliation, unauthorised input, failed Jobs, restart reconciliation and idempotent cancellation. Live checks should record only sanitised outcomes, not raw Telegram updates or operator identifiers.

## Add a disposable remote target

### Provision and upload

Create one independently disposable target in the controller VPC:

```sh
TARGET_ID=target-001 ./scripts/provision-target.sh
TARGET_ID=target-001 ./scripts/upload-target-package.sh
```

The target stack permits Kubernetes API port 6443 only from the controller security group. It receives no Telegram or AWS controller credential.

Resolve its instance and private IP for the two private SSM sessions:

```sh
aws cloudformation describe-stacks \
  --profile knowledge-islands-techne \
  --region eu-west-1 \
  --stack-name ki-techne-ops-007-target-001 \
  --query 'Stacks[0].Outputs'
```

Open the target session:

```sh
target_instance_id=$(aws cloudformation describe-stacks \
  --profile knowledge-islands-techne \
  --region eu-west-1 \
  --stack-name ki-techne-ops-007-target-001 \
  --query 'Stacks[0].Outputs[?OutputKey==`TargetInstanceId`].OutputValue | [0]' \
  --output text)
aws ssm start-session \
  --profile knowledge-islands-techne \
  --region eu-west-1 \
  --target "$target_instance_id"
```

### Prepare namespace-scoped access

Open an interactive SSM session to the target instance and run:

```sh
sudo /opt/ki-techne-tools/scripts/prepare-target.sh
```

The script creates only the `techne-execution` namespace, workload ServiceAccount and namespace-scoped controller RBAC. It writes a short-lived token and public server CA under `/var/lib/ki-target/` with mode `0600`.

### Register from the controller

Transfer the public CA and short-lived bearer token directly between private interactive target and controller sessions. The CA may be copied as a file. Paste the bearer token only into the registration script's hidden prompt, then clear the local clipboard. Do not use chat, a command argument, an environment assignment, SSM Run Command or retained evidence as the transfer channel.

On the controller, set only the non-secret target details and run:

```sh
export TARGET_ID=target-001
export TARGET_API_SERVER='https://<target-private-ip>:6443'
export TARGET_CA_FILE='/path/to/transferred/server-ca.crt'
sudo -E /opt/ki-techne-tools/scripts/register-target-on-controller.sh
```

The script stores the token and CA in the controller cluster Secret, updates the target ConfigMap, restarts the controller Deployment and waits for readiness.

Confirm registration from Telegram:

```text
/targets
/run target-001
```

The returned envelope must have the same shape as a local run while naming `target-001`.

## Remote-target restart and cancellation proof

For restart reconciliation:

1. send `/run target-001`;
2. note the reported execution update ID;
3. restart the controller Pod while the Job exists;
4. wait for the new controller Pod to become ready;
5. confirm the same deterministic execution identity is reported and no second Job exists.

For cancellation, send:

```text
/cancel target-001 <execution-update-id>
```

Confirm the named Job is deleted or already absent. Repeating the command must remain idempotent and must not create another Job.

## Deregister and destroy the target

On the controller, remove the remote target credential and restore the local-only configuration:

```sh
sudo /opt/ki-techne-tools/scripts/deregister-target-on-controller.sh
```

From the repository root, destroy only the disposable target stack:

```sh
TARGET_ID=target-001 ./scripts/destroy-target.sh
```

The destroy script verifies the AWS account and `ki-work-item=TECHNE-OPS-007` stack tag before deletion. After it completes, verify that the target stack, EC2 instance and controller-side target credential are absent while the retained controller Deployment remains ready.

Do not run `destroy-controller.sh` during the proof. Controller destruction requires separate explicit authority and the exact stack name in `CONFIRM_DESTROY_CONTROLLER`.

## Evidence and cleanup

Retain only sanitised evidence:

- stack and instance identifiers;
- timestamps and lifecycle outcomes;
- controller and target readiness states;
- deterministic execution identities and redacted outcome envelopes;
- checksum and encryption-state confirmation;
- post-teardown resource inventory;
- cost summary.

Do not retain Telegram tokens, bearer tokens, kubeconfigs, numeric operator identifiers, raw Telegram updates, Secret contents, AWS session material or command output containing any of them.

Record sanitised proof outcomes in the active `TECHNE-OPS-007` roadmap review in Techne Principal. This repository retains implementation provenance and operating instructions, not canonical architectural authority or operational state; superseded proof packages remain recoverable from Git history.

## Recovery and troubleshooting

- **Controller Pod is not ready** — inspect Deployment events and Pod status without printing Secret values. Confirm the Secret and ConfigMaps exist, the source ConfigMap matches the uploaded package and the bot has no active webhook.
- **Telegram sends no response** — confirm `@kitteth_bot`, operator user/chat allowlist and initial offset in the private bootstrap flow. Do not print the Secret to debug them.
- **A command reappears after restart** — inspect the deterministic Job name. Replay should reconcile the existing Job; a second Job is a proof failure.
- **Remote target is unreachable** — confirm the target private IP, controller-to-target security-group rule, CA file and short-lived token lifetime. Do not widen the Kubernetes API to public ingress.
- **Target token expired** — generate a new time-bounded token on the target and repeat the private interactive registration. Never make the proof token permanent.
- **A target teardown stalls** — inspect CloudFormation events, but do not delete the retained controller stack or unrelated resources.
- **A package-local dependency directory appears** — remove it through the package owner's normal tooling and reinstall only at the repository root; `bun run test` must pass before proceeding.

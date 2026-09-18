# Controller proof operations

The proof keeps one K3s controller host running and registers ephemeral execution targets separately. Defaults point to AWS account `655383751458`, profile `knowledge-islands-techne`, region `eu-west-1` and controller stack `ki-techne-ops-007-controller`.

## Verify locally

Run from the repository root:

```sh
bun run test
AWS_PROFILE=knowledge-islands-techne bun run ki:aws:validate
```

These checks require no package-local installation. CloudFormation validation is read-only but requires a valid AWS session.

## Upload the retained-controller package

Authenticate to AWS, then upload the secret-free package:

```sh
aws sso login --profile knowledge-islands-techne
./scripts/upload-package.sh
```

The upload uses SSM Run Command only for public source and deployment resources. It never carries a credential.

Enable and verify K3s Secret encryption before admitting credentials:

```sh
bun run ki:controller:encrypt-secrets
```

## Bootstrap credentials interactively

Run:

```sh
bun run ki:controller:bootstrap
```

The local launcher verifies the AWS account and opens an SSM interactive command on the retained instance. The remote bootstrap:

1. enables K3s Secret encryption using the supported single-server rotation sequence;
2. waits for `Encryption Status: Enabled` and `Current Rotation Stage: reencrypt_finished`;
3. reads the Telegram token silently and reads the selected user, chat and initial-offset values;
4. creates or updates the Kubernetes Secret and waits for the controller Deployment.

Values live only in the interactive process and Kubernetes Secret. Do not paste them into chat, set them in command arguments, send them through SSM Run Command or retain them as proof evidence.

The encryption sequence follows the [K3s secrets-encrypt procedure](https://docs.k3s.io/cli/secrets-encrypt). New stacks also start K3s with [Secret encryption at rest](https://docs.k3s.io/security/secrets-encryption) enabled.

## Execution targets

Use `provision-target.sh` and `upload-target-package.sh` for a disposable target. Run `prepare-target.sh` on the target, transfer its short-lived token through a private non-recorded channel, then run `register-target-on-controller.sh` interactively on the controller. Never place the bearer token in an environment assignment, command argument, repository file or retained evidence.

After dispatch, cancellation and restart reconciliation are proven, deregister the target credential and destroy only the target stack. The controller stack is retained unless a separate explicit teardown authorisation is given.

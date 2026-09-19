# Telegram commands

The Techne controller accepts a deliberately small command set through `@kitteth_bot`. It polls Telegram outbound, accepts commands only from the configured operator in the configured private chat and exposes no webhook or public controller endpoint.

## Command summary

- **`/start`** — show the supported command summary.
- **`/help`** — show the same supported command summary.
- **`/targets`** — list registered execution-target identifiers.
- **`/run <target>`** — dispatch one deterministic Kubernetes Job to a registered target.
- **`/cancel <target> <execution-update-id>`** — delete the deterministic Job derived from an earlier `/run` command.

Telegram's bot-addressed forms, such as `/targets@kitteth_bot`, are also accepted. Free-form text and unsupported or incomplete commands receive the usage response; they do not create work.

## Discover targets

Send:

```text
/targets
```

The reply lists the target identifiers accepted by `/run` and `/cancel`:

```text
Targets: local
```

The retained controller cluster is registered as `local`. Additional target identifiers appear only while those clusters are registered.

## Run work

Send a target returned by `/targets`:

```text
/run local
```

The controller first acknowledges the Telegram update and target:

```text
Dispatching update <execution-update-id> to local
```

It then creates or reconciles the deterministic Job and returns its outcome and workload output:

```text
telegram:<execution-update-id>:local: completed
{"execution_id":"telegram:<execution-update-id>:local","outcome":"completed"}
```

Keep the execution update ID if the Job may need cancellation. Replaying the same Telegram update reconciles the same Job identity rather than creating a duplicate.

An unknown target is rejected without creating a Job:

```text
Update <execution-update-id> failed: unknown target: <target>
```

## Cancel work

Use the target and execution update ID from the acknowledgement of the original `/run` command:

```text
/cancel local <execution-update-id>
```

The controller reports one of two idempotent outcomes:

```text
techne-local-<execution-update-id>: cancellation requested
```

```text
techne-local-<execution-update-id>: already absent
```

`already absent` means the deterministic Job had already completed, had already been cancelled or never existed. It is not a second execution.

## Usage and access behaviour

Sending `/run` without a target, malformed `/cancel` input, free-form text or an unsupported command returns:

```text
Usage: /run <target> or /cancel <target> <execution-update-id>
```

Commands from any user or chat other than the configured private operator identity are ignored without a bot reply. Do not paste Telegram tokens, numeric operator identifiers or raw Telegram updates into issues, chat, Git or retained proof evidence.

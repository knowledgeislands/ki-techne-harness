# Operate Techne Harness

These guides are for the operator responsible for the deployed personal controller and execution fabric. They cover behaviour and recovery owned by Techne Harness rather than installation or command grammar owned by `tools-techne`.

## Start here

- [Use Telegram commands](telegram-commands.md) — discover targets, dispatch deterministic work, interpret results and request cancellation safely.
- Use the [`tools-techne` operator guides](https://github.com/knowledgeislands/tools-techne/tree/main/docs/guides/user) to install and authenticate `techne`, inspect controller readiness and open the private bootstrap session.

Harness lifecycle scripts under `operations/` are implementation details behind the CLI, not a second public operator interface. Runtime payloads under `deploy/runtime/` execute on provisioned hosts. Never pass credentials through command arguments, retained logs, issues or chat; interactive bootstrap reads them only on the authorised controller.

When CLI diagnostics, AWS identity and controller stack status pass but deployed behaviour fails, investigate the harness-owned controller application, Kubernetes resources and runtime payloads in this repository.

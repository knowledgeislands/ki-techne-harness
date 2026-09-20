# Harness operations

This directory contains local lifecycle implementations owned by the Techne Harness. They are implementation details behind the independently released `techne` operator interface, not a second public command surface.

## Ownership

- `aws/controller/` provisions, uploads, configures and destroys the retained controller.
- `aws/target/` provisions, uploads and destroys disposable execution targets.
- `aws/validate-cloudformation.sh` validates the harness's AWS templates.
- `telegram/` performs token preflight and discovers the private operator identity.

`tools-techne` should expose typed commands for retained workflows and select an explicit local or immutable harness artifact. These scripts remain with the harness because they package and invoke harness-owned templates and runtime payloads. Do not invoke them from Homebrew installation paths or duplicate them into the CLI repository.

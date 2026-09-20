# Runtime payloads

Runtime payloads execute on provisioned controller or target hosts. They are packaged with the Kubernetes resources and application source they operate, rather than exposed as local operator commands.

- `controller/` bootstraps the retained controller, enables K3s secret encryption, deploys the controller and manages remote-target registration.
- `target/` prepares namespace-scoped target credentials for transfer through the approved interactive secret boundary.

The local lifecycle implementations under `operations/` upload these directories as explicit harness artifacts. The `techne` CLI may select and invoke those artifacts but does not own their runtime behaviour.

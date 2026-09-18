# TECHNE-OPS-007 migration provenance

The initial controller proof came from `knowledgeislands/ki-techne-principal` at implementation baseline `51b780f6574be61728f4bb0258d9d17b0a3974bc`. Its last source-only proof commit was `ef758bf3c746f03afaf401dca570967ee9a89e6f`.

The following source groups moved with byte-identical contents; only their repository paths changed:

- `controller/controller.py` → `apps/controller/src/controller.py`
- `fixtures/*.json` → `apps/controller/fixtures/*.json`
- `manifests/controller/*.yaml` → `deploy/kubernetes/controller/*.yaml`
- `manifests/execution/*.json` → `deploy/kubernetes/execution/*.json`
- `manifests/target/*.yaml` → `deploy/kubernetes/target/*.yaml`
- `cloudformation/target-stack.yaml` → `infra/aws/target-stack.yaml`

The migration intentionally changes:

- test and operational-script paths to match the monorepo layout;
- `controller-stack.yaml` so new controller clusters start with K3s Secret encryption enabled;
- controller deployment so credential admission fails unless encryption is enabled and re-encryption has finished;
- bootstrap and verification tooling for the root-only workspace and retained controller.

The source comparison used byte comparisons before the destination repository was populated. Sanitised proof results and the canonical work lifecycle remain in Techne Principal; credentials and raw operational state do not migrate.

---
areas: { CTRL: 1, FAB: 1, OPS: 8 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CTRL` reserves through `001`.
- `FAB` reserves through `001`.
- `OPS` reserves through `008`.

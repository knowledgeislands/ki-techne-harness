---
areas: { CTRL: 0, FAB: 0, OPS: 1 }
---

# Roadmap issue ledger

This ledger reserves fixed issuing-area namespaces. Allocate the next work item in its area as one greater than that area's high-water mark; never lower a value or reuse an issued number after a record is pruned. Areas are not mutable themes or groups.

- `CTRL` reserves through `000`.
- `FAB` reserves through `000`.
- `OPS` reserves through `001`.

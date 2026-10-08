# Working on this agent host

This machine is an agent host of the Knowledge Islands `direct-host` recipe. These rules come from the recipe itself (ODR-KI-ARCADIA-001), so they apply whoever's instructions sit beside them.

## Two checkouts

Every repository here also has a checkout on the operator's workstation. Push where you worked: work is safe only once it is in Git on a remote. Before working on a repository that was last changed on the other machine, fetch, check its status and make sure the two are level.

## Roadmap writes

The operator's workstation checkout is the roadmap writing checkout for every Knowledge Islands repository. Do not create, change, accept or prune roadmap records here. When a session needs a roadmap change, report the change it needs to the operator instead.

The host marker at `~/.config/ki/host-marker` records that this machine is an agent host; `ki` will refuse roadmap writes where it is present once it honours the marker.

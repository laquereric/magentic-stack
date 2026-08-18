# deploy/

Container and orchestration definitions for the governed pod (the 5-container
MIND Pod from [`../runtimes/`](../runtimes/)).

Doctrine:
- **Two-pod mandatory** for CPCP: Rails BACK plus a distinct FRONT accessory,
  never co-located; FRONT→BACK linkage verified at deploy.
- **Boundary defaults on**, with testable upgrade/rollback and evidence export.
- Every deploy records the upstream pins in effect (see `upstreams/manifests/`).

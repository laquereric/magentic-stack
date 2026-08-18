# runtimes/back/  🟢 OWN IT — BACK

The BACK service: **Context / Memory / `/_cpcp`**. This is where the owned
contract is enforced. SHACL validation happens here; MIND reaches Effect only
through this seam.

- Implements [`../../interfaces/rails-cpcp/`](../../interfaces/rails-cpcp/).
- In the mandatory two-pod topology, BACK is the internal pod; FRONT is distinct.

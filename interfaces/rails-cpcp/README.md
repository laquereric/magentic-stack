# interfaces/rails-cpcp/  🟢 OWN IT

CPCP seam implementation — an additive Rails engine that projects resources as
CID-grounded JSON-RPC-LD at `/_cpcp`.

- **Canonical source:** `rails-cpcp`
- **Contract:** [`../../grammar/cpcp/`](../../grammar/cpcp/)
- **Deploy doctrine:** MANDATORY two-pod — Rails BACK plus a distinct FRONT
  accessory, never co-located. FRONT→BACK linkage must be verified.

# CPCP — coordination-protocol-contract-package

A **refocus**, not a rename. The letters stay C-P-C-P. Nothing on the
wire moves.

These are deliberately untouched:

| surface | value |
|---|---|
| vocabulary IRI | `https://w3id.org/laquereric/cpcp/ns#` (in every response; two live sites) |
| mounted path | `/_cpcp/rpc` |
| public gem | `rails-cpcp` (built into the rails-base image) |

Renaming any of them would look like a clarification and would be a
breaking change to every client that already speaks the IRI, the path,
or the gem name. The expansion is what the letters **mean**. The tokens
are the contract.

## The grant

> CPCP is the affordance a deterministic entity grants a
> non-deterministic entity.

BACK is the deterministic side: one writer, one shape, one journal.
MIND (or any agent) is the non-deterministic side: it proposes, it
does not commit. The seam is the grant. FRONT is DBless and talks
only over this grant; MIND reaches Effect only through it. That is
already how the pod is built (`runtimes/mind-pod`).

A deterministic system that lets a non-deterministic one in must be
able to say afterwards **what was done and on whose word**. The rules
below are not style. They are what that sentence requires.

### Never-raise envelopes

The boundary returns `{ ok: true, … }` or
`{ ok: false, error: { reason, because } }`. See
`interfaces/rails-cpcp/lib/rails_cpcp/envelope.rb`. An exception
across the seam is a story the agent can invent; a typed refusal is
an account. `because` names the missing or offending item so the
caller can correct it without guessing.

### operationId on writes

PUSH without `operationId` is refused (`:operation_id_required` in
`dispatcher.rb`). The id is the agent's word: the same id is
idempotent, a different id is a different effect. Without it there is
no way to tell a retry from a second intent. PULL does not carry one
because a read is not an intent.

### Sole writer

The far side of the grant is BACK. An agent cannot mark its own
Effect committed. MIND proposes; BACKJOB reconciles; the journal and
the SQLite volume are BACK's. If the non-deterministic side could
close its own write, the account would be written by the party being
accounted.

### Shape gating

What may be read (Context) and what may be done (Effect) is closed
SHACL, owned by OSI Level 8 (`grammar/`, `interfaces/rails-osi-level-8`).
CPCP is the **transport of that grant**, not the shapes. rails-cpcp
projects Rails resources into operations; rails-osi-level-8 says
which operations a profile admits. Do not restate OSI Level 8 here
— depend on it.

## Read access / write access

The organizing split already exists in the DSL, unnamed.
`direction: :pull` is **read access**. `direction: :push` is **write
access**. See `interfaces/rails-cpcp/lib/rails_cpcp/registry.rb`
(`direction` must be `:pull` or `:push`) and the blob registrations
in `interfaces/mmg-blob` (blob.get/stat/entries/list are pull;
blob.put/blob.delete are push).

Two faces of one grant, different obligations:

- A **read** costs nothing and promises nothing. No operationId. No
  journal row of intent. The envelope is still never-raise so a
  missing shape is a refusal, not a 500.
- A **write** carries an operationId and an account. Idempotency is
  keyed by that id. The writer on the far side is still BACK.

The keyword pair (`:pull` / `:push`) is the mechanism. Read/write
access is what it **means**. Call it that when describing the grant;
leave the DSL keywords on the wire.

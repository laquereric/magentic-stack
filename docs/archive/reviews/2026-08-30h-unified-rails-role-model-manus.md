<!--
Source: Manus cloud agent, task WrVmQbbfEi8G7VPo85tnLR
Commissioned 2026-08-30 by SuperDevAi on operator instruction, as a follow-up
to 2026-08-30g. Tests the operator proposal: one Rails image with ROLE=X for
projector / config / bus / persist / shapes, on the principle that a unified
Rails lifecycle matters more than execution efficiency.

Manus had NO repository access, and the prior Q2 table was NOT included in the
brief -- hence the repeated "exact prior row not established" hedges, which are
correct and deliberate. Facts in the brief were verified against the tree at
a8b2310 first.

STATUS: exploration. Nothing authorized. ADR 0046 (vault separate) is the only
topology decision taken so far.
-->

# Unified Rails Role-Selector Proposal: Decision Memo

**Scope and evidence boundary.** This memo tests the operator’s proposal against the prior target-function-to-production-container map using only the supplied brief [1]. There was no repository access, and the prior Q2 table itself was not included. Any exact prior-row wording or mapping not reproduced in the brief is therefore **not established**.

## Executive decision

**The proposal is better in one important respect, but it does not replace the heterogeneous map wholesale.** The prior map over-split the RDF projector if it treated it as a separate runtime/container merely because it had a distinct function name. The RDF projection is already Rails-side, and projector and backjob are both asynchronous derived-work loops on the same Rails image. Their meaningful distinction is **authority and write policy**: projector writes derived, rebuildable RDF; backjob must not write authoritative domain rows. That distinction does not, by itself, require separate packaging.

The evidence does **not** establish that `config`, `bus`, `persist`, or `shapes` should become Rails roles, nor that the Node service should be rewritten. The evidence affirmatively supports keeping VAULT separate under ADR 0046. A `ROLE=vault` on the shared image would defeat ADR 0046 by reuniting the published configuration surface with the credential asset and restoring the coupling that the ADR rejected.

The recommended shape is therefore:

> **Use one Rails image lineage where code, trust, authority, release cadence, and resource profile genuinely align. Retain separate containers where trust, durable ownership, or materially different operational boundaries require separation.**

## 1. Does the unified model replace the heterogeneous map?

**No—not as a blanket replacement.** It replaces the separate projector packaging, if that packaging was based only on runtime identity and not on an independent lifecycle, trust boundary, or resource requirement. It does not replace the separate-vault decision. It does not justify a Node-to-Rails conversion or Rails Event Store adoption without separate migration evidence.

| Prior-map area | Decision | Exact replacement/survival status |
|---|---|---|
| `graph-projector` / RDF projection | **Replace as a separately packaged runtime** with a Rails role or the existing async Rails worker family, provided derived-only RDF write permissions are explicit | The brief names the `graph-projector` container, but the exact Q2 row is **not established** |
| `backjob` | **Survives** as an operational role with its repaired transport/replay behavior and an enforced prohibition on authoritative writes | The role and defect status are established; exact Q2 wording is **not established** |
| Node `config` surface | **Survives for now** on the Node lineage; a Rails role remains an unapproved migration option | Exact prior Q2 row is **not established** |
| Node LLM data plane | **Survives for now**, including routing, provider adaptation, translation, discovery, verification, and related behavior | Exact prior Q2 row is **not established** |
| Rails Event Store / `bus` | **Do not add merely to complete the role list**; this would be new adoption, not relocation | The brief mentions options `(i)` and `(ii)` but does not reproduce their definitions; exact mapping is **not established** |
| Durable persistence / `persist` | **Survives as a distinct ownership boundary** from the bus | Exact prior Q2 row is **not established** |
| `shapes` | **Unresolved**; the function is not defined sufficiently to classify it | Any prior Q2 mapping is **not established** |
| VAULT | **Survives intact as a separate container under ADR 0046** | ADR 0046 and its conditions are established; exact prior Q2 wording is **not established** |

Accordingly, the operator is right about the projector correction, but the brief does not support replacing every purpose-built container with one Rails role-selector image.

## 2. Which proposed roles are legitimate, and which must remain separate?

| Proposed role | Decision | Reasoning grounded in the brief |
|---|---|---|
| `ROLE=projector` | Legitimate as a **logical role**; not established as a separate container | RDF projection is already Rails-side. Projector and backjob share the same broad asynchronous derived-work shape. Their write authorities differ, so the code must enforce derived-only projection, but packaging need not differ solely for that reason. |
| `ROLE=config` | Technically possible, but **not yet justified** | The Node service serves both the 8789 data plane and 8790 configuration UI from one process and contains substantial routing/provider/translation code. The brief does not establish that a Rails rewrite would pay back its migration risk. |
| `ROLE=bus` | **Not yet justified** | `rails_event_store` has zero hits. This role would adopt new infrastructure rather than relocate an existing component. |
| `ROLE=persist` | Legitimate only if it represents a real durable-ownership boundary | The bus must not own the durable event repository. Sharing an image does not remove that rule. Whether persistence needs a separate process, image, or deployment is **not established**. |
| `ROLE=shapes` | **Not established** | The brief does not define SHAPES’s function, writes, authority, resource profile, or lifecycle. |

### VAULT and ADR 0046

VAULT is the explicit exception to broad image unification. ADR 0046 separates it from the configuration surface because the UI is the attack surface and the vault is the asset; their churn rates differ; a UI crash must not cost the LLM plane its credential source; and an in-process allowlist is not meaningful. The binding conditions are an authenticated allowlisted API, no default caller token with fail-closed boot behavior, and read-back asymmetry: the config surface may write a secret but may never read one back.

A `ROLE=vault` on the shared image would defeat ADR 0046. It would restore co-residence between the published UI and the secret asset, and it would weaken the separation the ADR uses to make the allowlist and read-back asymmetry meaningful.

## 3. What does `ROLE=config` cost?

The brief requires separating **config-surface conversion** from **whole-service conversion**.

| Migration scope | What changes | Cost and risk |
|---|---|---|
| **Config surface only** | Move the 8790 configuration UI/control path to Rails while leaving the 8789 Node data plane in place | This is smaller than moving the whole service, but still a rewrite. The brief establishes that the existing Node service includes a UI directory and tests; exact UI size, migration duration, test count, and downtime are **not established**. Risks include feature-parity loss, authentication/authorization drift, and a new cross-runtime control/data-plane boundary. |
| **Whole Node service** | Move the UI plus routing, provider adaptation, translation, discovery, verification, sources, catalog, and router behavior to Rails | This is a materially larger rewrite. The brief establishes `server.mjs` at 350 lines plus the named modules and tests, and says one process serves both planes. Exact total code volume and schedule are **not established**. Risks include regressions in provider semantics, routing, verification, availability, and the loss of a working tested implementation during migration. |

The unified role model does **not** logically require moving the LLM data plane to Rails. A role selector is a packaging and deployment decision, not proof that Node behavior must be rewritten. Converting only the config surface is a possible future project, but it creates a split control/data-plane model. Converting the whole service maximizes Rails uniformity but incurs a broad rewrite without evidence that the lifecycle benefit offsets it.

The implementation discarded would be, at minimum, the existing Node service described in the brief—including `server.mjs`, its named modules, UI, and tests—if the whole service moved. For a config-only move, the existing UI/config implementation would be replaced or substantially rewritten. Exact discarded code volume and migration effort are **not established**.

## 4. Are `ROLE=bus` and `ROLE=persist` coherent together?

They are coherent only if the distinction remains **ownership and authority**, not merely two names selected from the same image. `bus` may publish or deliver events; `persist` may own the durable event repository. The bus must not own that repository. That separation survives a shared image, but it becomes a code-, credential-, mount-, and deployment-policy boundary rather than a boundary between different build artifacts.

| Arrangement | Boundary quality | Decision |
|---|---|---|
| Separate bus and persist containers/images | Stronger failure, credential, scaling, and rollback isolation | Safer default when durability and delivery have different operational profiles; exact profiles are **not established** |
| One image, separate `ROLE=bus` and `ROLE=persist` processes | Logical separation can survive, but dependency and release coupling increase | Possible, but not automatically superior |
| One process or one role owns both | Collapses the durable-authority boundary | Reject |

This does **not** make Rails Event Store option `(i)` automatically correct. Rails Event Store is not present; adopting it is a new architectural choice. Option `(ii)` may remain preferable if it preserves the durable repository boundary with less migration risk. The exact definitions of `(i)` and `(ii)` are **not established**, so no stronger conclusion is supportable.

## 5. Unified lifecycle or only unified build?

**One image guarantees a unified build artifact, not one lifecycle.** If roles restart, scale, and deploy independently, there are still N operational lifecycles over one digest. If they deploy together, there is one release lifecycle, but the roles become coupled: a small change for one role redeploys all roles, and a rollout or failure constraint in one role can affect the rest.

The operator’s principle explicitly asks for a unified **lifecycle**, not merely a unified build. It is satisfied only if the roles share a meaningful release, compatibility, and operational lifecycle. The brief does not establish that they should restart, scale, or deploy together. Thus the proposal currently demonstrates build coherence; lifecycle coherence remains a deployment-policy decision.

The practical compromise is a single Rails code/image lineage with independently selected roles, while preserving operational separation for VAULT, durable ownership, and any role with a materially different resource or release profile.

## 6. What does the unified image cost?

| Cost | Consequence |
|---|---|
| Any gem change rebuilds every role | Larger rebuild and redeploy blast radius; exact timing impact is **not established** |
| A CVE in any dependency touches every role | One remediation rollout reaches every role, even where the vulnerable dependency is irrelevant; exact vulnerability counts are **not established** |
| The image is the union of all dependencies | Larger image, attack surface, patch surface, and runtime dependency set; exact image size is **not established** |
| Resource profiles differ sharply | Bulk re-projection and a config UI may need different CPU, memory, concurrency, timeout, and autoscaling policies; exact profiles are **not established** |
| One release artifact couples rollbacks | Provenance is simpler, but independent rollback and release cadence are weaker |

The cost exceeds the coherence benefit **not at a fixed number of roles**, but when roles differ materially in **trust boundary, authority, durability, resource profile, or release cadence**. Role count is only a proxy. VAULT demonstrates why even one role can require separation; conversely, several same-trust, same-release, same-resource Rails workers may reasonably share an image.

The OCI-provenance recommendation from memo `(f)` strengthens the unified-image case, but only on the supply-chain axis. One image gives one digest, simplifying provenance, promotion, inventory, and reproducibility. It does not create one lifecycle, enforce authority separation, reduce the union dependency surface, or equalize resource profiles. It materially strengthens the **build/provenance** argument and only weakly strengthens the **operational lifecycle** argument.

## 7. Sequencing

**Proceed with the VAULT container under ADR 0046. Do not pause or redirect that work.** The vault decision is independently justified by trust and asset separation. Keep the configuration surface on its Node lineage for the current cutover unless a separately approved migration plan proves otherwise.

The first cutover step is unchanged: **isolate backjob storage and enforce the writer boundary**. The brief says `BACK_URL` is now set, completion records carry real `receipt_cid` and `outcome_cid`, replay is idempotent, and a checker rejects loopback-defaulted environment variables not explicitly set for the service. That fixes the stated backjob defect, but `Reconciliation.create!` remains untouched and is still a violation. The corrected map must preserve the distinction between legitimate derived RDF writes and forbidden authoritative domain writes.

| Order | Action | Gate |
|---:|---|---|
| 1 | Continue VAULT as a separate container under ADR 0046 | Do not introduce `ROLE=vault` into the shared image |
| 2 | Isolate backjob storage and remediate `Reconciliation.create!` | Do not treat repaired transport and replay as proof that authority is correct |
| 3 | Collapse separate projector packaging into the Rails worker/role family | Enforce derived-only RDF write permissions |
| 4 | Keep Node for config and the LLM data plane for now | Require parity, security, migration, and rollback evidence before conversion |
| 5 | Do not adopt Rails Event Store merely to fill `ROLE=bus` | Preserve bus versus durable-persistence ownership |
| 6 | Define SHAPES before assigning it to a role or container | Function, authority, resource, and lifecycle are currently **not established** |
| 7 | If one Rails artifact remains desirable, run a costed pilot with independent role restart/scale behavior and an explicit common release policy | Test whether the desired lifecycle is genuinely common rather than merely a shared digest |

## Final answer in one sentence

**Change the prior map by removing the separate projector container, but do not replace the entire heterogeneous map: preserve VAULT separation and the backjob writer-boundary work, defer Node-to-Rails config migration, do not infer Rails Event Store adoption from `ROLE=bus`, keep persistence ownership distinct, and leave SHAPES unresolved until defined.**

## Reference

[1]: /home/ubuntu/upload/pasted_content_cIMHKovO1ZPvmskG4QSEjc.txt "Operator brief supplied with the task"

All factual claims in this memo are derived from the supplied operator brief [1]. No external sources or repository contents were used.

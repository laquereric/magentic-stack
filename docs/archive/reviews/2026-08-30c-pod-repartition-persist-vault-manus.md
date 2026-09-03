# Architecture Decision Memo: Re-partitioning the MIND Pod

**Status:** Recommendation for exploration only; no change is authorized by this memo.

## Executive recommendation

Adopt the six-container repartitioning **in principle**, but do not implement the proposal exactly as written. It is a better six-container answer than adding a seventh persistence service, provided that **PERSIST owns physical storage, BACK is the only domain-authorized writer, BACKJOB has no storage mount, and VAULT is treated as a high-trust secret broker rather than as a general-purpose co-owner of persistence**.

The proposal does not eliminate concentration risk. VAULT can become a compromise bridge to the entire data plane, and bundling VAULT with Switchyard creates a second, serious concentration of privilege and attack surface. That is acceptable as an interim six-container design only if access is narrowly scoped, credentials are not exposed to BACK or BACKJOB, and the design preserves a future seam for separating the vault from routing. A generic SQL/RDF API would be premature and should be explicitly rejected.

The current topology already disproves the premise that BACK is presently an enforced sole physical writer: both BACK and BACKJOB mount the same SQLite volume. The migration should therefore be judged by whether it creates **new enforceable boundaries**, not whether it preserves an invariant that already exists only by convention.

## 1. Does this satisfy the required separation at six containers?

**Yes, conditionally.** It satisfies the required separation of **credentials from physical data** without adding a seventh container, if and only if PERSIST does not receive a secrets volume and VAULT does not itself mount the SQLite or Oxigraph data volumes.

The important distinction is between the following three properties:

| Property | Proposed result | Recommendation |
|---|---|---|
| Physical data ownership | PERSIST owns SQLite and Oxigraph storage | Keep this arrangement |
| Credential ownership | VAULT owns credentials and brokers access | Keep, but minimize credentials and scope |
| Application access | BACK, BACKJOB, and FRONT use CPCP contracts | Enforce by removing volumes and direct secret access |

PERSIST should expose provider-specific persistence operations over a narrow internal contract. VAULT should provide only the credentials or capability needed for an approved operation. BACK and BACKJOB should never receive a database file, database password, or vault storage mount.

This is materially better than placing credentials and physical data in SWITCH because a compromise of the routing component no longer automatically implies filesystem access to the data. It is not complete isolation: VAULT remains a highly trusted bridge. The proposal meets the separation requirement at the container-count constraint, but it does not provide independent fault or compromise domains for every sensitive function.

The claim that PERSIST can authenticate to VAULT, or that Switchyard can safely broker the required credentials, is **not established** from the supplied topology. That behavior must be proven from code and configuration before implementation.

## 2. Is VAULT-to-PERSIST credential chaining materially better, or merely one hop removed?

**It is materially better for direct blast radius, but not equivalent to strong isolation.** VAULT becomes a control-plane compromise that can acquire access to PERSIST; it does not become harmless merely because the data volume is elsewhere.

The improvement is real when the following conditions hold:

1. PERSIST has no credentials that can access unrelated systems.
2. VAULT issues narrowly scoped, short-lived capabilities rather than returning a broad credential bundle.
3. PERSIST accepts requests only from authenticated, authorized callers and does not trust arbitrary VAULT-mediated instructions.
4. VAULT cannot directly read or modify PERSIST’s data volumes.
5. Network policy prevents BACK, BACKJOB, and FRONT from bypassing the intended contract.

Without those controls, the architecture is largely **one hop removed**. A VAULT compromise could still obtain the means to read, alter, delete, or exfiltrate all PERSIST-managed data. If the same credential also authorizes LLM operations or other infrastructure, the blast radius is wider than the data plane.

The correct decision is therefore: **accept VAULT as the six-container compromise, but document it as a trusted control-plane dependency, not as a security boundary that makes PERSIST independent of VAULT.** Do not claim that this design provides defense in depth until credential scope, issuance semantics, network reachability, and audit behavior are established. Those properties are currently **not established**.

## 3. What happens to the two-level writer invariant?

The invariant remains expressible and becomes more enforceable:

> **BACK is the sole domain-authorized writer; PERSIST is the sole physical storage executor.**

BACK does not need to hold a database to be the domain-authorized writer. It owns the application commands and decides which state transitions are valid. PERSIST owns the mechanics of committing those transitions to SQLite and Oxigraph.

The invariant should be rewritten operationally as follows:

| Layer | Sole responsibility | Enforcement mechanism |
|---|---|---|
| Domain authorization | BACK alone may issue state-changing domain commands | CPCP authentication and authorization; reject writes from BACKJOB and FRONT |
| Physical execution | PERSIST alone may open or mutate SQLite/Oxigraph storage | Only PERSIST mounts data volumes; no other service has filesystem access |
| Background work | BACKJOB may request approved work but may not commit directly | BACKJOB has no data volume and uses a worker CPCP contract |
| Presentation | FRONT may read or request actions through BACK | No persistence mount, no vault credentials, no direct PERSIST access |

Removing BACKJOB’s direct mount makes the physical-storage half enforceable for the first time. Removing BACK’s mount does not weaken domain ownership; it makes the distinction explicit. However, it is not sufficient by itself. If PERSIST exposes an unrestricted SQL endpoint, BACKJOB could still become a de facto writer over the network. PERSIST must expose command-level or narrowly defined provider operations, not arbitrary SQL or SPARQL mutation to every caller.

The current claim that BACKJOB actually writes the database is **not established**. The compose file establishes that it can access the file, not that application code uses that access. Treat that capability as a defect regardless of observed behavior.

## 4. Does co-locating SQLite and Oxigraph pressure the design toward a generic SQL/RDF API?

**No. One container can host two provider-specific adapters without creating a generic semantic API.** The container boundary is a deployment boundary, not an API-design boundary.

PERSIST should have two explicit internal adapters:

```text
PERSIST
├── SQLite adapter       -- relational transactions and relational queries
├── Oxigraph adapter    -- RDF/SPARQL operations and graph transactions
└── narrow CPCP facade  -- only approved domain operations, with provider-specific calls where needed
```

Do not create an abstraction such as `put(entity)` or `query(graph_or_table)` merely to make the two engines look alike. SQL and RDF have different transaction, query, consistency, indexing, and failure semantics. A false common abstraction would hide those differences and encourage accidental cross-store atomicity claims.

The external contract should be either:

- a set of domain commands whose implementation deliberately coordinates the two adapters; or
- two clearly named provider-specific contract namespaces, such as relational and graph operations, when callers genuinely need provider semantics.

If one logical operation requires both stores, define its consistency guarantee explicitly. Unless a real two-phase commit or equivalent recovery protocol exists, do not describe the operation as atomically committed across SQLite and Oxigraph. The availability of such a protocol is **not established**.

A single PERSIST container is reasonable now because the objective is to avoid service proliferation. Splitting the engines later is justified only by an independently demonstrated need: different scaling, failure isolation, ownership, upgrade cadence, or security policy. Splitting them now would be premature.

## 5. Is bundling VAULT with Switchyard the same rejected concentration?

**It reintroduces a significant concentration, although not exactly the same one.** A vault that also routes LLM traffic has a broad attack surface and high privilege. This is the most concerning part of the six-container proposal.

The distinction is that the previous objection concerned a component simultaneously owning or terminating credentials and physical persistence. In the new design, PERSIST owns physical data while VAULT owns credentials and routing. That removes direct filesystem co-location, but it does not remove the possibility that a compromised VAULT can reach all sensitive systems through its credentials.

Therefore, proceed only with these constraints:

| Control | Required decision |
|---|---|
| Data volumes | VAULT must not mount SQLite or Oxigraph volumes |
| Credential scope | Separate PERSIST credentials from LLM/provider credentials where feasible |
| Routing authority | Switchyard must not receive unrestricted vault-admin capability |
| Secret exposure | Secrets should be resolved server-side or as short-lived capabilities; do not inject broad secrets into callers |
| Network access | VAULT must have only the egress and ingress required for brokering and routing |
| Auditability | Record credential issuance, use, rotation, and failed authorization events |
| Future seam | Keep vault storage/broker interfaces independent from Switchyard interfaces |

The exact privilege set and Switchyard behavior are **not established** from the supplied material. Do not approve the combined VAULT image on the assumption that Switchyard is a passive router. Inspect its code, exposed ports, outbound destinations, secret-handling paths, and runtime user before treating the bundle as acceptable.

The combined service is an **interim consolidation**, not a clean final security architecture. Splitting it immediately is premature under the stated container constraint; ignoring the concentration is not acceptable.

## 6. Is MIND genuinely unaffected, and does it still hold no credential?

**MIND is not established to be unaffected.** The compose excerpt shows no declared MIND volume or secret mount, but that does not prove that the image contains no credential, reads one from its environment, receives one at runtime, or depends on SWITCH/Switchyard behavior.

The safe answer is:

- From the supplied compose facts, MIND has no demonstrated direct credentials mount.
- It may still be affected by changed service names, network paths, authentication requirements, or routing endpoints.
- Whether it holds, requests, caches, or forwards credentials is **not established**.

Before migration, inspect MIND’s environment variables, startup configuration, outbound connections, service-discovery names, and any code paths that call Switchyard or persistence. Then run it against the new contracts with credential access denied by default. The MIND image should remain unchanged only if those tests prove that its dependencies and endpoint names remain compatible.

Do not make “MIND unchanged” a migration assumption. Make it a proof gate.

## 7. What migration order avoids two writers or an ownerless store?

Use a **quiesced cutover**. Continuous write availability during the physical ownership transfer is not required by the brief, and attempting to preserve it would add complexity and risk. The requirement should be interpreted as: never permit simultaneous writers, and never declare PERSIST owner until it has a verified, usable copy of the data.

### Phase 0: Establish the contract and inventory

Freeze the intended interfaces before changing containers. Identify every process that opens SQLite, every process that mutates Oxigraph, every database path, every volume mount, every secret source, and every network caller. Because actual BACKJOB write behavior and Switchyard internals are **not established**, treat both as unknowns to resolve.

**Proof gate:** repository/configuration search and runtime tracing show the complete writer and credential inventory; the proposed CPCP operations and authorization rules are documented; rollback artifacts and backups are tested.

### Phase 1: Build PERSIST without declaring ownership

Create the PERSIST image with separate SQLite and Oxigraph adapters. Attach temporary or restored data volumes, but keep BACK and BACKJOB stopped or isolated from the new instance. Do not expose mutation endpoints beyond an allowlist.

**Proof gate:** PERSIST starts with empty or test data, passes SQLite and Oxigraph integrity checks, exposes health checks, rejects unauthorized callers, and demonstrates backup/restore for both stores.

### Phase 2: Quiesce all old writers

Enter maintenance mode. Stop BACKJOB first so it cannot create new background writes. Drain or reject new write commands at BACK. Stop BACK. Confirm that no process retains the SQLite file or Oxigraph store open. Take a final consistent source snapshot while all writers are stopped.

**Proof gate:** container state, open-file checks, application logs, and volume inspection show zero active writers. The source snapshot has recorded checksums and passes database-specific integrity checks.

### Phase 3: Restore and validate the PERSIST copy

Restore the final snapshot into PERSIST-owned volumes. Do not mount those volumes into BACK, BACKJOB, FRONT, VAULT, or MIND. Start PERSIST in a restricted mode and validate row counts, key records, graph counts, and application-level invariants against the source snapshot.

**Proof gate:** the restored stores pass integrity and application consistency checks; PERSIST is the only container with physical access; the old volumes are retained read-only for rollback and are not attached to active services.

### Phase 4: Establish the new authorization path

Start PERSIST as the only physical storage executor. Start BACK with its old `DB_PATH` and data mount removed, configured to use the CPCP contract. Keep BACKJOB stopped. Run read and write smoke tests through BACK, including retries and failure handling.

**Proof gate:** BACK can perform every required approved operation through the contract; direct filesystem access is absent; PERSIST rejects BACKJOB, FRONT, and arbitrary mutation requests; only authenticated BACK commands can perform domain writes.

### Phase 5: Reintroduce BACKJOB without storage access

Start BACKJOB with no `mind-data` mount and no database credential. Configure it to submit jobs or commands through the approved contract. Begin with a disabled or read-only job class, then enable mutation-producing jobs after observing authorization and idempotency behavior.

**Proof gate:** container inspection proves no persistence mount; negative tests prove BACKJOB cannot write directly or invoke unrestricted provider mutations; duplicate delivery and retry tests prove jobs are idempotent or safely deduplicated.

### Phase 6: Integrate VAULT and validate MIND/FRONT

Only after persistence cutover is stable, enable VAULT-mediated credential access. Rotate credentials as part of the cutover rather than carrying forward broad legacy credentials. Then validate FRONT and MIND against their contract endpoints and network policies.

**Proof gate:** audit logs show only approved credential requests; VAULT cannot access data volumes; MIND and FRONT have no unintended secret path; all service-to-service calls use the intended identities and endpoints.

### Rollback rule

Rollback must itself be a quiesced cutover. Stop BACK and BACKJOB, stop PERSIST, preserve the PERSIST-side audit trail and snapshot, and only then restore the old stack against the pre-cutover snapshot. Never run old volume-mounted writers and PERSIST concurrently. A rollback that starts the old writers while PERSIST remains active violates the invariant.

## Final decision

Proceed with the six-container design as the **recommended constrained architecture**, subject to proof gates. Rename GRAPH to PERSIST and SWITCH to VAULT only together with actual capability reduction: remove data mounts from application containers, remove BACKJOB’s direct mount, define provider-specific adapters, and restrict credential scope.

The design is not ready for implementation if “VAULT” merely becomes SWITCH plus a credential store with unchanged privileges. That would be cosmetic repartitioning. The non-premature work is enforcing storage ownership and contract boundaries. The premature work is inventing a generic SQL/RDF semantic API, splitting PERSIST before operational evidence exists, or claiming that MIND is unaffected without inspecting and testing it.

## Source boundary

This assessment relies only on the topology and constraints supplied in the brief. Claims about actual BACKJOB writes, Switchyard’s internals, MIND’s runtime credential behavior, and cross-store transaction semantics are **not established** without repository and runtime inspection.

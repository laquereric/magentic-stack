# Cross-SLICE RDF Federation: SPARQL `SERVICE` vs Delta-Bus SYNC

This document evaluates the two candidate mechanisms for cross-SLICE RDF federation within a Rails 8 + SQLite/OxiRS architecture at the scale of thousands of isolated slices: query-time federation via SPARQL 1.1 `SERVICE` and replication via Delta-Bus SYNC. The evaluation validates the hypothesis that Delta-Bus SYNC is the superior choice for this specific architecture and scale, primarily due to strict isolation requirements.

## 1. SPARQL 1.1 `SERVICE` Federation in Production Reality

The SPARQL 1.1 Federated Query extension introduced the `SERVICE` keyword to allow a query author to direct a portion of a query to a remote SPARQL endpoint [1]. While conceptually powerful, `SERVICE` introduces significant operational challenges in production, particularly at scale.

### Semantics, Failures, and Timeouts

By default, if a remote endpoint invoked via `SERVICE` is slow, unresponsive, or returns an error, the entire query fails [1]. The specification provides the `SILENT` keyword (e.g., `SERVICE SILENT <url>`) to mitigate this. When `SILENT` is used, errors from the remote endpoint are ignored, and the failed clause is treated as returning a single empty solution mapping [1]. 

However, `SILENT` does not inherently solve the problem of hanging queries. The W3C specification does not define a standard timeout mechanism for `SERVICE` calls [1]. Consequently, timeout behavior is entirely dependent on the specific SPARQL engine's HTTP client implementation. If the engine does not enforce strict outbound HTTP timeouts, a slow remote endpoint will cause the calling query to block indefinitely, tying up resources on the querying slice.

### Scale Limits and Security

Research on large-scale SPARQL federation indicates that traditional `SERVICE`-based engines struggle to scale beyond a few dozen endpoints [2]. A 2024 study introducing the FedUP engine noted that state-of-the-art federation engines suffer serious performance degradation as the number of endpoints increases, primarily due to the combinatorial explosion of source selection and the cost of evaluating useless combinations [2]. While advanced engines like FedUP can handle hundreds of endpoints, they require tracking provenance and computing quotient summaries, adding significant complexity [2].

Security is another major concern. Allowing user-controlled or dynamically generated `SERVICE` URIs exposes the system to Server-Side Request Forgery (SSRF) attacks [3]. Furthermore, SPARQL 1.1 does not specify a standard way to pass authentication credentials to remote endpoints within the `SERVICE` clause [4]. Credentials must usually be configured out-of-band in the engine's settings, making dynamic, authenticated peer-to-peer federation highly complex to manage securely.

## 2. Engine Support: Oxigraph and OxiRS

The viability of the `SERVICE` approach depends heavily on the capabilities of the chosen RDF engines: Oxigraph (current) and OxiRS (future).

### Oxigraph

**As Callee:** Oxigraph provides a standalone HTTP server (`oxigraph_server`) that implements the SPARQL 1.1 Protocol [5]. It can successfully act as the target (callee) of a `SERVICE` request from another endpoint.

**As Caller:** Oxigraph implements the `SERVICE` keyword and can act as a caller. However, its implementation has notable limitations:
*   **Timeout Issues:** As of mid-2025, Oxigraph lacks a built-in configuration parameter for query timeouts, meaning queries can run indefinitely in the background even if the initial HTTP request is killed [6]. This confirms the risk of synchronous coupling and hanging queries.
*   **Custom Functions:** There are reported issues (e.g., Issue #1624) where `SERVICE` calls fail when interacting with custom extension functions [7].
*   **Variable Binding:** Users have reported unexpected behavior regarding variable sharing in federated queries (e.g., Issue #838) [8].

### OxiRS

OxiRS, positioned as a modern, Rust-native semantic web platform, supports SPARQL 1.2 and advanced features.
*   **`oxirs-arq` and `oxirs-fuseki`:** The documentation for `oxirs-arq` explicitly mentions "Federation Support - Basic federated query capabilities," and `oxirs-fuseki` includes modules like `federated_query_executor` and `federated_query_planner` [9] [10]. This indicates that OxiRS does support `SERVICE` as both caller and callee.
*   **The Delta-Bus Shift:** Crucially, the OxiRS roadmap and the `oxirs-stream` crate strongly corroborate the hypothesis that the ecosystem is moving toward streaming and replication. `oxirs-stream` provides "Real-time streaming support with Kafka/NATS/MQTT/OPC-UA I/O, RDF Patch, and SPARQL Update delta" [11]. This demonstrates a deliberate architectural shift by the OxiRS developers toward Delta-Bus sync for high-performance, distributed knowledge graphs, rather than relying solely on query-time `SERVICE`.

## 3. RDF Delta/CDC Replication over an Event Bus

Replicating RDF changes using an event bus offers an asynchronous alternative to query-time federation.

### Patterns and Formats

The established pattern for RDF replication is the exchange of change logs. The most prominent format is **RDF Patch**, an append-only log of triple/quad additions and deletions [12]. Apache Jena provides "RDF Delta," a system specifically designed for recording and publishing changes to RDF datasets using RDF Patch logs to maintain synchronized copies [13]. 

Another emerging standard is **Linked Data Event Streams (LDES)**, which publishes an append-only collection of immutable members (events) [14]. While LDES is more oriented toward publishing open data streams, RDF Patch is more suited for internal, exact state replication between identical stores.

To track provenance, **RDF-star (SPARQL-star)** or the newer **RDF 1.2 triple terms** can be used to attach metadata (e.g., `trace_id`, source slice) directly to the replicated triples.

### Consistency and Conflict Handling

Delta replication inherently provides **eventual consistency**. Slices will read stale data until they process the latest patches from the bus. 

For conflict resolution, simple "last-writer-wins" based on timestamps is common but can lead to lost updates in active-active scenarios. More robust systems use Vector Clocks or CRDTs (Conflict-free Replicated Data Types). The `oxirs-stream` crate explicitly includes a `multi_region_replication` module with support for `VectorClock`, `ConflictResolution`, and `ReplicationStrategy` [11], indicating that OxiRS provides native, production-grade tools for handling distributed conflicts.

### Event Bus Options

While Kafka is the industry standard for high-throughput event streaming, it is operationally heavy and expensive. 
*   **NATS JetStream:** NATS JetStream is a lightweight, highly performant alternative that provides the necessary persistence, at-least-once/exactly-once delivery guarantees, and replay capabilities required for RDF patch replication [15]. It is significantly simpler to deploy and manage than Kafka, making it an ideal fit for the "Solid" ethos.
*   **Postgres LISTEN/NOTIFY:** While Postgres can be used for lightweight messaging, `LISTEN/NOTIFY` does not scale well for high-volume event sourcing or durable replication, as it lacks built-in persistence and consumer group management [16].

## 4. Isolation and Failure-Domain Comparison

The decisive criterion for this architecture is per-slice isolation: a degraded peer must never wedge the querying slice.

| Feature | Query-Time Federation (`SERVICE`) | Delta-Bus SYNC (Replication) |
| :--- | :--- | :--- |
| **Coupling** | **Synchronous.** The querying slice blocks waiting for the remote peer's HTTP response. | **Asynchronous.** Slices query their local, replicated copy of the data. |
| **Failure Impact** | **Cascading.** A slow peer causes the querying slice's thread/connection to hang. Even with `SILENT`, aggressive timeouts and circuit breakers are required to prevent resource exhaustion. | **Isolated.** If a peer goes down, the querying slice continues to serve queries instantly using the last known state. The only impact is data staleness. |
| **Latency** | High and unpredictable, bound by the slowest remote endpoint in the query. | Low and predictable, bound only by local SQLite/OxiRS read performance. |
| **Scale Ceiling** | Tens to hundreds of endpoints (requires advanced engines like FedUP). | Thousands of slices (limited only by the event bus's fan-out capacity and local storage). |

Given the hard constraint that "a slow or down PEER must NEVER wedge the querying slice," `SERVICE` is fundamentally flawed for this architecture. It recreates the exact synchronous coupling issue experienced with SQLite, but across the network. Delta-Bus SYNC completely decouples query execution from peer availability.

## 5. Consistency/Freshness Tradeoff in Production

In production knowledge graph systems, the choice between federation and replication hinges on the tradeoff between freshness and performance/reliability.

A hybrid query execution study demonstrated that while live queries provide fresh results, they suffer from significant latency [17]. Production systems, especially those embracing microservices, increasingly favor the "Database per Service" pattern with asynchronous event-driven replication to ensure isolation and autonomy [18]. 

In these architectures, **eventual consistency is accepted as the cost of high availability and isolation**. Query-time freshness is only mandated for transactional operations (e.g., financial ledgers), which are typically handled within a single, authoritative domain rather than across a massive federation. For cross-slice knowledge sharing and observability, the replication lag of a Delta-Bus (typically milliseconds to seconds) is entirely acceptable.

## 6. Concrete Recommendation

**Recommendation: Implement Delta-Bus SYNC (Replication) via NATS JetStream.**

This approach strictly adheres to the hard constraints: it guarantees per-slice isolation, eliminates synchronous cross-node coupling, and scales gracefully to thousands of slices.

### Justification and Implementation Details

1.  **Isolation:** Queries never leave the local slice. A slice queries its local OxiRS instance, which contains both its private graph and the replicated public/shared graphs from peers.
2.  **Bus Technology:** Use **NATS JetStream**. It provides the necessary durability and replayability for RDF Patch logs without the operational overhead of Kafka. It aligns perfectly with the low-cost, mainstream requirement.
3.  **Data Format:** Use **RDF Patch** format over the bus. When a slice updates its local graph (e.g., via a Rails Event Store projection), it publishes the corresponding RDF Patch to a NATS subject (e.g., `slice.{id}.public.patches`).
4.  **Provenance:** Utilize **RDF 1.2 triple terms** (supported by OxiRS) to attach provenance metadata (source slice ID, RES event ID) to replicated triples.
5.  **Migration Path:** 
    *   *Phase 1 (Oxigraph):* Rails projects RES events into local Oxigraph. A separate background worker tails the RES, generates RDF Patches, and publishes to NATS. Another worker subscribes to NATS and applies patches to the local Oxigraph via SPARQL Update.
    *   *Phase 2 (OxiRS):* Replace Oxigraph with `oxirs-fuseki`. Leverage the `oxirs-stream` crate to natively handle the NATS subscription and RDF Patch application, removing the need for custom Ruby workers for the replication layer. The SPARQL-HTTP membrane remains unchanged for the Rails app.
6.  **Discovery:** Avoid a central registry. Use a curated peer-list distributed via configuration or a dedicated "directory" NATS stream. Slices subscribe only to the NATS subjects of the peers they care about.

## 7. Missing Considerations and Alternatives

*   **The Hybrid Fallback:** While Delta-Bus is the primary mechanism, a highly restricted hybrid approach could be considered for rare, deep-dive queries where staleness is unacceptable. A slice could use `SERVICE SILENT` with an extremely aggressive, hard-enforced timeout (e.g., 500ms) to query a specific peer. However, given Oxigraph's current lack of timeout controls [6], this should be deferred until `oxirs-fuseki` is fully deployed and its timeout semantics are verified.
*   **Storage Costs:** Replicating graphs across thousands of slices will increase local storage requirements (SQLite/RocksDB footprint). Careful consideration must be given to *what* is replicated. Slices should likely only subscribe to specific named graphs (e.g., a shared community ontology) rather than the entire dataset of every peer.
*   **Replication Lag Spikes:** Under heavy write load, NATS consumer lag can spike. The system must be designed to tolerate scenarios where a slice is temporarily minutes or hours behind the fleet state.

---

### References

[1] W3C, "SPARQL 1.1 Federated Query," March 2013. [Online]. Available: https://www.w3.org/TR/sparql11-federated-query/
[2] J. Aimonier-Davat et al., "FedUP: Querying Large-Scale Federations of SPARQL Endpoints," The ACM Web Conference 2024, April 2024. [Online]. Available: https://hal.science/hal-04538238/document
[3] Invicti, "Server-Side Request Forgery (SSRF)." [Online]. Available: https://www.invicti.com/learn/server-side-request-forgery-ssrf
[4] W3C SPARQL 1.2 GitHub Issues, "add Authentication to Federation #117." [Online]. Available: https://github.com/w3c/sparql-12/issues/117
[5] Docs.rs, "oxigraph_server 0.2.4." [Online]. Available: https://docs.rs/oxigraph_server/0.2.4
[6] Oxigraph GitHub Issues, "Timeout parameter #1336," July 2025. [Online]. Available: https://github.com/oxigraph/oxigraph/issues/1336
[7] Oxigraph GitHub Issues, "Issue with custom functions in SERVICE call #1624," February 2026. [Online]. Available: https://github.com/oxigraph/oxigraph/issues/1624
[8] Oxigraph GitHub Issues, "Federated query does not as expected #838," March 2024. [Online]. Available: https://github.com/oxigraph/oxigraph/issues/838
[9] Docs.rs, "oxirs-arq." [Online]. Available: https://docs.rs/oxirs-arq
[10] Docs.rs, "oxirs-fuseki." [Online]. Available: https://docs.rs/oxirs-fuseki
[11] Docs.rs, "oxirs-stream 0.3.1." [Online]. Available: https://docs.rs/crate/oxirs-stream/latest/source/src/lib_header.txt
[12] Apache Jena, "RDF Patch." [Online]. Available: https://jena.apache.org/documentation/rdf-patch/
[13] A. Seaborne, "RDF Delta - Replicating RDF Datasets." [Online]. Available: https://afs.github.io/rdf-delta/
[14] W3C, "Linked Data Event Streams," May 2026. [Online]. Available: https://w3id.org/ldes/specification
[15] Synadia, "NATS and Kafka Compared," November 2024. [Online]. Available: https://www.synadia.com/blog/nats-and-kafka-compared
[16] Hacker News, "Postgres LISTEN/NOTIFY does not scale." [Online]. Available: https://news.ycombinator.com/item?id=44490510
[17] J. Umbrich et al., "Hybrid SPARQL queries: fresh vs. fast results," ISWC 2012. [Online]. Available: https://aidanhogan.com/docs/iswc2012.pdf
[18] Microservices.io, "Pattern: Database per service." [Online]. Available: https://microservices.io/patterns/data/database-per-service.html

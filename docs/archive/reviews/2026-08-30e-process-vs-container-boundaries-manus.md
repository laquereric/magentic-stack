# Recommendation

**Stop treating container count as the primary architecture decision.** Decide first which components require independent trust, failure, resource, scaling, lifecycle, and deployment boundaries. Then choose processes, containers, or VM-backed containers to implement those requirements. The current six-versus-seven argument is partly a Docker packaging artifact, but not entirely: some boundaries remain meaningful even when process supervision is available.

The strongest conclusions from the supplied inventory are that `back`, `backjob`, and `front` currently share one image and source but have different roles, `switch` is a Node process rather than the previously assumed Rust/Switchyard component, and `backjob` is a second Oxigraph/SQLite writer. The earlier Rust co-location scenario should be discarded; it does not describe the current system. [1]

## 1. Is the container-count debate largely an artifact of Docker’s process model?

**Yes, largely—but only for the packaging question.** If a runtime provided first-class supervision, per-process health reporting, restart policy, logging, resource accounting, and lifecycle control, several arguments about whether two logically related processes need separate containers would disappear. In particular, “one container per executable” is not itself an architectural principle. It is a convenient deployment convention for runtimes that do not otherwise supervise a process tree well.

However, container count still carries real meaning when it expresses a boundary that processes alone do not adequately provide. A container normally provides a separately addressable unit for image distribution, identity, filesystem mounts, network policy, cgroups, namespace isolation, secrets exposure, restart policy, scaling, and orchestration. A supervisor can reproduce some of these properties, but not all of them with equal strength or equal operational clarity.

The practical rule is therefore:

| Question | If the answer is “yes” | Recommended boundary |
|---|---|---|
| Must this component have a different trust level or secret set? | A process compromise must not expose the other component | Separate container; possibly a stronger VM boundary |
| Must it scale or restart independently? | Its lifecycle differs materially | Separate container or independently supervised unit |
| Must it have materially different CPU, memory, network, or filesystem policy? | Shared limits would be unsafe or wasteful | Separate container |
| Is it only a role selector over the same code and image? | No independent trust, lifecycle, or resource requirement exists | Consider one supervised process group, but measure first |

For this pod, the review should stop debating six versus seven as an abstract target. The current count is not established as correct or incorrect. What is established is that some count arguments are artifacts of packaging, while the security and storage-writer arguments are not.

## 2. Which current boundaries are genuine security or fault boundaries, and which are Docker artifacts?

**`VAULT` versus `SWITCH` is a genuine trust boundary.** The stated reason is credential handling, and that reason survives the process/container question. If `SWITCH` does not need the vault’s credentials, then a compromise or bug in `SWITCH` should not automatically obtain them. Keep that separation unless a deliberate threat-model review proves the exposure acceptable.

**`BACK`, `BACKJOB`, and `FRONT` are not demonstrated security boundaries merely because they are separate containers.** They use the same image and source, differing by the `ROLE` environment variable. That makes the separation look primarily like a deployment and lifecycle choice. It may still be operationally meaningful if the roles need independent scaling, restarts, resource limits, network access, or secret sets, but those properties are not established by the facts provided.

Their common image also does not prove that they are safe to co-locate. A shared image is packaging evidence, not evidence of equal trust or equal failure behavior. A bug in common code can affect all three whether they are in one container or three; conversely, separate containers can still be weakly isolated if they share volumes, credentials, or a vulnerable host interface.

**`BACKJOB` versus the other storage-writing roles is a genuine data-integrity and fault boundary concern.** The inventory establishes that `BACKJOB` writes SQLite and is a second Oxigraph writer. [1] That is materially different from a role that merely happens to share an image. Whether the current writes are safe, serialized, transactional, or corruption-resistant is **not established**. Treat the second writer as a design defect or an explicitly justified exception until proven otherwise.

The resulting classification is:

| Current separation | Assessment | Action |
|---|---|---|
| `VAULT` / `SWITCH` | Genuine trust boundary | Preserve separate security domains; do not merge for convenience |
| `BACK` / `BACKJOB` / `FRONT` | Boundary not established; currently looks largely packaging- and lifecycle-driven | Re-evaluate from trust, scaling, restart, and resource requirements |
| `BACKJOB` / SQLite-Oxigraph storage | Genuine integrity/fault concern because it is an additional writer | Remove the direct write or explicitly redesign the storage protocol |
| `GRAPH` / `MIND` and other listed roles | Exact required boundary not established from the brief | Do not make topology claims without their access and failure requirements |

## 3. Does logical cohesion justify co-location when language affinity is absent?

**Logical cohesion is necessary but not sufficient.** Different languages do not prevent co-location. A Node process, a Rust process, and a Rails process can run under one supervisor. But that arrangement is justified only when the components also share a lifecycle, trust level, scaling shape, resource profile, and acceptable failure domain.

Otherwise, a multi-runtime container merely moves the coupling into a supervisor configuration, startup ordering rules, signal propagation, log routing, health checks, image construction, and shutdown behavior. That coupling is not eliminated; it becomes harder to see and may be owned by nobody.

For the proposed `SWITCH` ecosystem, **do not create a multi-runtime container now**. The premise is already unstable: the measured `SWITCH` container is Node-based, while NVIDIA NeMo Switchyard is a separate upstream of Rust crates and is not run by that container. [1] The fact that these pieces are logically related does not establish that they share lifecycle, failure, scaling, or credential requirements. Those requirements are **not established**.

Keep independently deployable components separate until there is a concrete demonstrated benefit from co-location. If they must be started together for local development, use a development composition or a supervisor as a convenience layer; do not make that convenience layer the production trust or deployment architecture.

## 4. What does Docker’s one-process model buy, and what would supervision lose?

The one-process-per-container convention buys **operational separability**, not magical process isolation. It gives the orchestrator a simple primary health signal, a clear exit status, straightforward restart semantics, independently assignable container resources, and a clean unit for logs, metrics, networking, mounts, secrets, rollout, and scaling.

A capable supervisor can provide much of the process-management portion: child restart, signal forwarding, dependency ordering, health checks, log collection, and possibly per-process limits. Therefore, the earlier claim that these capabilities are inherently unavailable inside one container is too strong.

What supervision does not automatically reproduce is the full boundary represented by separate containers. Sibling processes may still share the same container namespaces, filesystem view, mounted secrets, network policy, cgroup hierarchy, and failure domain. One process can exhaust shared resources, corrupt shared state, or exploit a shared privileged interface. Per-process cgroups and additional sandboxing may reduce those risks, but their exact effectiveness depends on the supervisor and runtime; it is **not established** here.

The blunt recommendation is to retain separate containers whenever independent **security, resource, scaling, rollout, or fault-domain behavior** is required. Use a supervised multi-process container only for components whose shared failure and trust domain is intentional and documented. Do not use “Docker only supports one process” as the justification; use the actual boundary requirement.

## 5. Is designing pod topology around `apple/container` a mistake?

**Yes. Designing the production topology around it would be a mistake.** The cited project describes Linux containers as lightweight virtual machines on a Mac, is optimized for Apple silicon, and requires an Apple-silicon Mac running macOS 26. [2] The stated production target is a Linux VPS. Therefore, `apple/container` is a development-environment runtime for this decision, not an established production deployment target.

Using it as the topology authority risks producing a development arrangement whose isolation, networking, filesystem behavior, startup behavior, resource accounting, and VM boundaries do not match production. OCI image compatibility does not establish runtime-behavior compatibility. [2]

Its VM-backed isolation is a reason to consider **more** boundaries only if the production runtime also provides and needs that isolation. It is not a reason to collapse application boundaries during design. More containers can mean more VM instances, more memory overhead, more startup cost, and more operational objects; fewer can mean a larger blast radius. The trade-off is runtime-specific and has not been measured here.

Use the Linux production runtime as the topology reference. Test `apple/container` separately for developer ergonomics or additional local isolation, but do not infer production container count from it. This entire VM-per-container optimization is premature until the target VPS runtime, resource budget, and threat model are fixed.

## 6. Does `BACKJOB` writing SQLite change the `PERSIST` recommendation?

**It does not change the principle; it exposes that the current system violates it.** If the recommendation is that `PERSIST` is the sole physical storage executor, then `BACKJOB` directly writing SQLite means that recommendation is not true today. The inventory establishes `BACKJOB` as a second writer. [1]

The correct action is to make one of two explicit decisions. The recommended decision is to remove direct SQLite/Oxigraph writes from `BACKJOB` and route persistence through `PERSIST`, with an API or durable command mechanism appropriate to the required consistency and throughput. This keeps storage ownership, locking, migrations, recovery, and observability in one component.

The alternative is to declare `BACKJOB` a co-owner of persistence and design an explicit multi-writer protocol. That would require documented transaction boundaries, concurrency control, crash recovery, backup semantics, schema/migration ownership, and tests for conflicting writes. None of those properties is established in the brief, so treating the current second writer as safe would be an inference and should not be done.

Whether `BACKJOB` and `PERSIST` run in one container, separate containers, or separate VM-backed containers is secondary. The **sole physical storage executor** rule is a logical ownership and integrity rule; it is independent of packaging. Container separation can reinforce the rule by removing filesystem access, but it cannot repair an architecture that still grants `BACKJOB` a write path.

## Bottom line

The operator is right that several prior arguments were about a Docker packaging artifact. In particular, the fact that three roles share an image and the fact that multiple runtimes might need a supervisor do not, by themselves, determine the container count. The correction about `SWITCH` also invalidates the earlier Rust-based scenario.

The operator is not right if the conclusion is that logical cohesion should generally collapse containers into one supervised multi-runtime unit. **Trust, resource, lifecycle, failure, and storage-integrity boundaries remain real even when process supervision is available.** Preserve `VAULT`/`SWITCH` separation, treat `BACKJOB`’s second writer as an unresolved integrity defect, avoid designing production around `apple/container`, and defer any topology reduction until the actual boundary requirements are documented and tested.

### References

[1]: /home/ubuntu/upload/pasted_content_SSsinnB4eYcyGwFwJFDXIC.txt "User-supplied architecture brief and quoted repository inventory"

[2]: https://github.com/apple/container "apple/container README and repository"
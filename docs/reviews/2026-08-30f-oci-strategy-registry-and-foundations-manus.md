# Dev-on-VMs, OCI Images, and a Coherent VPS Management Story

## Executive recommendation

Adopt **OCI images as the immutable delivery unit for runnable services**, and use a single OCI-compliant registry as the promotion boundary. Keep `app-shacl-store` as the semantic package and admission system that it is; do not replace it wholesale with OCI. Attach existing SLSA provenance, SBOMs, and signatures to image or artifact digests using OCI referrers and cosign. Standardize a small number of **family-specific foundation images**, pin every `FROM` to a digest, and rebuild dependent images when a foundation digest changes.

Use Apple Container for fast developer feedback and isolation, but add a Linux CI or staging test before production. The compatibility target is the **application and image contract**, not identical kernels, networking, storage, resource accounting, or failure behavior. Do not introduce a model OCI format for NVIDIA NOOA or Switchyard source submodules yet. That is premature unless you have a concrete need to distribute large immutable model/runtime bundles outside normal Git and image delivery.

## 1. Are we reinventing OCI?

**Partly, but not in the places that matter most.** OCI already provides content-addressed manifests and blobs, image/artifact media types, and—since OCI Image and Distribution 1.1—`subject`, `artifactType`, and a Referrers API for attaching signatures, attestations, SBOMs, and other metadata to a manifest [1]. An OCI image digest identifies the manifest and therefore the referenced config and layers [2]. Those facilities overlap directly with the package format’s content-addressed identity and its use of signed release evidence.

The correct replacement boundary is therefore narrow: represent a runnable service as an OCI image; identify it by its immutable digest; publish its SBOM, SLSA provenance, release attestations, and signatures as referrers to that digest; and use registry distribution for copying the exact bytes between CI, development, staging, and production. Cosign is already the right ecosystem mechanism for signatures and attestations. Its documented workflow signs an image reference and can attach custom attestations, but it requires access to a registry [3].

| `app-shacl-store` capability | OCI replacement? | Recommendation |
|---|---:|---|
| Content-addressed identity for a manifest and blobs | Yes, for OCI-delivered images/artifacts | Use the OCI manifest digest as the release identity. Do not use a mutable tag as the deployment identity. |
| Dependency closure | No, not completely | Preserve the package’s closure semantics. OCI descriptors describe referenced blobs and referrers associate metadata, but OCI does not by itself provide your distinction between a missing digest and an unresolvable host or a complete application dependency graph. |
| Signed provenance | Partly | Store provenance as an OCI referrer/attestation, while retaining the predicate schema and policy that interpret it. OCI stores and relates the evidence; it does not decide whether the evidence is acceptable. |
| Revocation | No | Preserve the append-only admission registry and revocation rules. A registry is not a revocation authority, and an OCI digest remains a valid content identifier even if your policy later forbids deployment. |
| Append-only admission registry | No | Keep it. This is a policy and audit ledger, not an image transport primitive. |
| Trust envelope and ordered fail-closed verification | No | Keep it as the verifier/policy layer. Cosign can provide signatures, but your ordered checks and failure semantics are application-specific. |
| Exact declaration of which bytes a claim covers | Partly | OCI digests give precise coverage for blobs and manifests. Keep your explicit coverage declaration where a claim covers a package subset, canonical representation, dependency closure, or external content. |
| Package metadata and custom typed payloads | Yes, when distribution is useful | Use an OCI artifact with a versioned config media type and explicit layer media types, preferably through ORAS. ORAS documents this exact model for arbitrary files, configs, and multiple typed layers [4]. |

The blunt conclusion is that **OCI should become the transport and identity envelope, not the replacement for your package semantics**. Rewriting `app-shacl-store` merely to claim OCI conformance would be premature and would likely weaken the existing fail-closed policy model. The useful integration is to make an `app-shacl-store` release optionally point at, or be represented by, an OCI manifest digest, then keep the admission registry authoritative for whether that digest is deployable.

## 2. What maps from dev-on-VMs to prod-on-VPS, and what does not?

Apple Container consumes and produces OCI-compatible container images and runs Linux containers inside lightweight virtual machines on Apple silicon [5]. That means the same image manifest, config, layers, entrypoint, environment defaults, and application files can be pulled in development and on the VPS. It does **not** mean the two executions have the same kernel, virtual machine topology, cgroup implementation, networking path, filesystem behavior, device access, or failure modes.

The smallest useful cross-environment guarantee is an **image-and-application contract**:

1. The image is pulled by digest and is runnable for the declared platform, initially `linux/arm64` for Apple Silicon and whatever Linux VPS architecture is actually deployed. If the VPS is `amd64`, publish a multi-platform image or build/test a separate platform variant; the exact VPS architecture is not established from the brief.
2. The image’s entrypoint, command, environment-variable contract, listening ports, signal handling, exit codes, health check, and required writable paths are documented and tested.
3. The service has no hidden dependency on host-installed packages, host paths, mutable container identity, or a particular kernel feature unless that dependency is explicitly part of the production contract.
4. Persistent data is outside the image and has an explicit ownership, migration, backup, and recovery procedure. Image replacement must not mutate durable state implicitly.
5. Resource and failure behavior is tested at the application boundary: startup timeout, readiness, graceful termination, crash restart, dependency loss, disk-full behavior, and database or queue reconnect behavior.
6. The release is verified by digest and policy before execution. “The tag points at the expected build” is not a sufficient guarantee.

Do **not** attempt to make these identical: the guest kernel and kernel configuration; VM versus host-container overhead; cgroup and memory-pressure details; network interface and DNS behavior; filesystem mounts, permissions, and performance; CPU architecture and optional instruction sets; GPU or accelerator access; clock, entropy, and device behavior; restart orchestration; and the exact signal or shutdown timing. Those are runtime acceptance-test concerns, not OCI-image concerns. The Linux CI/staging target must test behaviors Apple Container cannot establish.

In particular, many development VMs are not a reason to create many production VMs. The mapping is **one service image to one or more runtime instances**, not “one development VM becomes one VPS.” Development isolation is a means of feedback; production topology should be selected for availability, resource isolation, storage integrity, and operational simplicity.

## 3. What is the coherent VPS management process?

Adopt a registry now, but keep the process deliberately small. Continue building in CI, push immutable images to one private OCI registry, and deploy to the VPS by digest. Building on the production box is acceptable as a temporary experiment, but it is not a defensible promotion mechanism: it conflates build and runtime trust, makes rollback depend on local cache state, and leaves no clean answer to “which exact bytes ran?”

The registry need not be a platform project. Choose one managed private registry or one small self-hosted OCI registry that supports the OCI Distribution API and the referrer behavior required by your evidence workflow. The specific provider is **not established** from the brief, and you should verify support for private repositories, retention, authentication, digest pulls, referrers, and backups before choosing it. Do not deploy a full artifact platform merely because the ecosystem offers one.

A defensible flow is:

| Stage | Required action | Release invariant |
|---|---|---|
| Build | CI builds the service image from pinned inputs and records the Git commit, base-image digests, platform, and build metadata | The image is reproducible enough to identify all material inputs; exact reproducibility is not established and should not be claimed without a test |
| Verify | Run unit/integration tests, image vulnerability checks, startup/health tests, and the Linux-runtime acceptance tests | The candidate passes the same application contract expected in production |
| Publish | Push the image under a temporary or commit tag, resolve its manifest digest, and publish the digest as the release identity | Tags are labels only; the digest is authoritative |
| Evidence | Attach the existing SLSA provenance, SBOM, governance evidence, and cosign signature/attestation to the digest | Evidence refers to the exact manifest digest, not merely the repository or tag |
| Admit | Have the existing admission registry record the digest, dependency closure, policy decision, and revocation state | OCI transport does not replace admission policy |
| Promote | Promote by copying or authorizing the already-built digest; do not rebuild for production | The production candidate is byte-identical to the verified candidate |
| Deploy | The VPS pulls the exact digest, verifies policy, starts the service, and records the deployed digest and configuration | The operator can answer what is running and revert to the previous digest |
| Roll back | Repoint the service to the prior admitted digest and restore or migrate data according to the data procedure | Rollback is an image selection operation, not a rebuild |

A registry-less flow can remain viable if releases are rare, the VPS is the only target, and the operator manually preserves image archives, digests, signatures, and deployment records. But given that you already generate signed evidence and are explicitly seeking promotion semantics, **registry-less deployment is now the wrong default**. It saves one service while imposing manual distribution and audit work exactly where OCI registries are designed to help.

## 4. What does foundation-plus-customization layering require?

Do not create one universal foundation. Create a small set of **foundation families** aligned with real runtime contracts: Ruby application, Node application, Python application, and perhaps a separate distroless/runtime family where it genuinely reduces attack surface. `oxigraph` should remain a separately governed upstream dependency unless you have a demonstrated need to own a foundation around it. A shared foundation that tries to serve Ruby, Node, Python, and distroless workloads would be artificial coupling, not standardization.

Every foundation and application `FROM` reference should be pinned by digest. A tag such as `ruby:3.4.9-slim` is a version hint, not immutable identity. Record the human-readable tag as metadata, but make the digest the build input. The final image should also carry labels or attestations identifying the foundation digest, source revision, build system, and platform.

A foundation program needs an owner, a defined rebuild cadence, automated vulnerability and license checks, a supported-runtime policy, and a dependent-image rebuild trigger. The correct dependency rule is:

> A foundation digest is immutable. A new foundation build is a new digest. Every customization that wants the new fixes must be rebuilt and retested against that new digest.

If a foundation is rebuilt while customizations remain pinned to the old digest, nothing silently changes: the customization continues to use the old bytes. That is good for reproducibility and bad for patch uptake. The old image remains a valid historical release, but it is no longer the patched release. If you instead use tags and rebuild without recording the resolved digest, you get the worst of both worlds: moving inputs without a reliable release identity.

Do not attempt “live base-layer replacement” in production. Build a new final image, attach fresh evidence, run tests, admit it, and promote it. The provenance chain should say which foundation digest was consumed; the final-image attestation must be regenerated because the final manifest changed. Whether your current SLSA workflow already records all base-layer digests is **not established** and should be checked before claiming complete transitive provenance.

## 5. Are OCI artifacts applicable to the AI models here?

The Docker article says something narrower than “put all AI-related material in OCI.” It describes Docker Model Runner’s model format for distributing standalone LLMs through OCI registries. The model artifact has a typed config containing model metadata, uses typed layers such as GGUF and license files, keeps large model files uncompressed and separately addressable, and separates models from inference engines [2]. Docker’s stated benefits are avoiding a new distribution toolchain, enabling registry-based discovery and sharing, and allowing runtimes to select model variants without bundling every model with every inference engine [2].

That is a real solution for **large immutable model files, multiple quantized variants, and independent model/runtime distribution**. It is not automatically a solution for upstream source submodules. On the facts supplied, NVIDIA NOOA and Switchyard are pinned upstream submodules, not trained weights or a set of large inference-ready model files. Their primary identity is a source commit plus its source provenance and build inputs. Keep that identity in Git/submodule locks and your existing provenance system.

For this system, adopting Docker’s model artifact format now is **premature**. Use it only if one of these concrete requirements appears: the built model/runtime payload is too large or awkward for normal source/image delivery; multiple environments need the same immutable payload; the inference engine must be upgraded independently; or registry-backed caching, access control, signing, and rollback are materially useful. If that happens, package the actual distributable payload as a versioned OCI artifact with explicit media types and attach the same evidence/admission policy used for service images. Do not put a source checkout into a model artifact merely because it contains AI code, and do not bundle large model files into every service image by default.

## 6. Which OCI ecosystem technology should be used or ignored?

Use a small, coherent set rather than adopting the ecosystem wholesale.

| Technology | Decision | What it buys you |
|---|---|---|
| OCI image/distribution specifications | **Use** | A standard manifest, digest, layer, pull, and distribution contract. OCI 1.1 adds `subject`, `artifactType`, and the Referrers API for associated evidence [1]. |
| One private OCI registry | **Use now** | Immutable distribution, digest-based promotion, caching, rollback, and a central location for images and optional artifacts. Provider choice and exact feature support are not established. |
| Cosign/Sigstore | **Keep and integrate** | Signature and attestation workflows for the exact image/artifact digest. Your current signed release evidence is an asset; do not replace it with an unconnected signing system [3]. |
| ORAS | **Use only when publishing non-image artifacts** | A practical CLI/library for pushing arbitrary typed files, config objects, and multiple layers to an OCI registry [4]. It is appropriate for a future `app-shacl-store` OCI representation or a real model payload, not necessary for ordinary service images. |
| SLSA provenance | **Keep** | Build provenance and verifiable relationships between source, builder, inputs, and output. OCI can carry or reference this evidence; it does not define the provenance policy. |
| SBOM and vulnerability scanner | **Use, if already present or easy to operate** | A release gate and attached evidence for the final image and its foundations. The exact current scanner and its coverage are not established. Avoid making a scanner a substitute for runtime tests. |
| Multi-platform image manifests | **Use if Apple and VPS architectures differ** | One release reference can select the correct platform image. The VPS architecture is not established, so first record it and test the selected variant. |
| Helm, Kubernetes, Notary v1, a full artifact platform, or a model registry | **Ignore for now** | None is required by one operator with one VPS and the stated deployment shape. Reconsider only when the operational problem exists. |
| A custom OCI registry client or custom image format | **Ignore** | Use existing Docker/OCI clients and standard manifests. Custom code would add maintenance without solving the stated trust-policy gap. |

The most important operational rule is to avoid confusing **storage/distribution**, **evidence**, and **admission policy**. OCI and a registry solve the first. Cosign and SLSA help with the second. `app-shacl-store` currently owns the third. Keep those layers separate and connect them by immutable digest.

## Bottom line

The next implementation should be a thin vertical slice, not an ecosystem migration: build one service image in CI with all base references digest-pinned; push it to one private registry; attach the existing provenance and signature evidence; record the digest in `app-shacl-store`; pull and verify that digest in a Linux staging target; then deploy that same digest to the VPS with an explicit rollback record. Add ORAS only when a non-image artifact has a concrete distribution requirement. Defer model OCI packaging and any attempt to make Apple Container and the VPS runtime behavior identical.

## References

[1]: <https://opencontainers.org/posts/blog/2024-03-13-image-and-distribution-1-1/> "OCI Image and Distribution Specs v1.1 Releases"

[2]: <https://www.docker.com/blog/oci-artifacts-for-ai-model-packaging/> "Why Docker Chose OCI Artifacts for AI Model Packaging"

[3]: <https://docs.sigstore.dev/cosign/signing/signing_with_containers/> "Signing Containers — Sigstore"

[4]: <https://oras.land/docs/how_to_guides/pushing_and_pulling/> "Pushing and Pulling — ORAS"

[5]: <https://github.com/apple/container> "apple/container — GitHub"

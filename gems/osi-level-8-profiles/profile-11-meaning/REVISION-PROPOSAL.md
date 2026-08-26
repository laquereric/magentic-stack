# Profile 11 — revision proposal (ACCEPTED 2026-08-20)

**Status: accepted.** Accepted as written on 2026-08-20, which means the
recommendation in §9 including its declines:

- **Adopted:** Delta 1 (content by reference), Delta 3 (alignment objects),
  Delta 4 (verification evidence).
- **Gated, not adopted:** Delta 2 (Apache Ossie interop) — blocked on verifying §0
  independently. Accepting this document does not verify that fact.
- **Declined:** the rename cascade, and a parallel `semantic.*` refusal registry.

`profile-11-meaning.md` is still unchanged and still normative. Acceptance
authorises the work; it does not perform it. Each adopted delta needs the spec
amended, both ttl copies updated, conformance extended, and a migration for
existing rows before anything depends on it.

Source: a hard review by the Manus cloud agent, task `H4ZQVbSAToqGsxFbjFa9Xq`,
2026-08-20, verdict **RESHAPE**, prompted by
`magentic-market-ai/docs/research/OntologyVsSemantic.md`. Recommendations below are
mine; where I disagree with the review I say so and why.

---

## 0. A factual correction that must be verified first

The source article states that **OSI (Open Semantic Interchange)** shipped **v1.0 in
January 2026**. The review reports that primary sources do not corroborate this, and
that the initiative moved to the Apache Software Foundation as **Apache Ossie
(Incubating)** in July 2026, with **0.1.1** the latest released version and
`0.2.0.dev0` in development.

**Verify this independently before acting on it.** It is the kind of claim that is
easy to get wrong in either direction, and it decides whether we bind to a stable
standard or to a moving incubator project. If the review is right, then binding
Profile 11 to "OSI v1.0" would have anchored us to a version that does not exist —
which is precisely the failure this profile exists to prevent, committed by us.

Nothing else in this proposal depends on the answer, except §3.

---

## 1. The diagnosis

Profile 11 governs three different kinds of artifact as if they were one:

| Paradigm | Question it answers | Where it leaked into P11 |
|---|---|---|
| **Semantic layer** | "what is our revenue?" — calculation, joins, filters | `OperationBinding` |
| **Ontology / glossary** | "what is a customer?" — classes, relations, axioms | `Concept`, and the *content* of `DefinitionRevision` |
| **Governance** | "may this be acted on, by whom, on what evidence?" | everything else, and this is what P11 is actually for |

The review's sharpest sentence: as written, Profile 11 is *"neither a pure
semantic-layer nor a true ontology nor a governance gate."* I think that is right,
and the cause is one field.

## 2. Delta 1 — definition content becomes a reference (RECOMMENDED)

`DefinitionRevision` currently holds `content` as a string with a digest. That makes
it a **fourth competing home for meaning**, against the "define once; BI, agents and
governance all read the same definition" principle the article argues for.

Replace embedded content with a reference:

    normativeArtifact: {
      artifactIri, artifactKind, profileOrFormat, versionIri,
      contentDigest { algorithm, value }, mediaType,
      componentSelector, retrievalPolicy
    }

Profile 11 then governs an artifact **by digest** without holding it. This is the
one change I would make regardless of what else is decided: it is small, it removes
a genuine architectural fault, and it strengthens rather than weakens the receipt
model — a receipt already pins digests, so pinning an external artifact digest is
the same move applied one level out.

**Cost:** a migration for existing `DefinitionRevision` rows, and a retrieval policy
we do not currently specify.

## 3. Delta 2 — interoperate with Apache Ossie, do not reinvent (RECOMMENDED, gated on §0)

If the correction in §0 holds, `normativeArtifact` should be able to reference an
Ossie semantic-model artifact directly, with `profileOrFormat` naming it. That buys
cross-tool conformance for free and keeps us out of the business of specifying
semantic-model syntax.

**Do not** claim conformance to a version that is still incubating. Reference it as
a supported `artifactKind`, not as a dependency.

## 4. Delta 3 — local vs global needs real objects (RECOMMENDED)

Our `agreement: none | local | federated` names the problem the article calls the
long-term hard one — reconciling domains that modelled semantics independently — and
does not solve it. `federated` is a label with nothing behind it.

The review proposes `SemanticAlignmentAssertion` and `FederationAgreement`, with
participants, subject references, mapping artifacts and proof evidence. That is the
same move that fixed `dispute`: a dimension with no object behind it cannot carry
provenance. I would adopt it, and keep `agreement` as the derived summary rather
than replacing it — exactly as `dispute` now works.

## 5. Delta 4 — verification evidence, including ontology consistency (RECOMMENDED)

`SemanticVerificationEvidence` with `verificationKind` covering
`ontology-consistency`, `schema-validation`, `semantic-model-compile`, plus verifier,
input digests and result.

This closes a real gap I raised and the review confirmed: **ontologies derive facts;
Profile 11 derives bands from evidence but never from the artifact's own
consistency.** A definition whose axioms are inconsistent should not be able to reach
`formalization=testable`, and today nothing stops it.

## 6. What I would NOT adopt

**The rename cascade.** `Concept` → `SemanticSubject`, `DefinitionRevision` →
`SemanticArtifactRevision`, `OperationBinding` → `ComputationBinding`. The names are
arguably more precise, but this is churn across committed, passing code and two ttl
copies, and it buys clarity rather than capability. If Delta 1 lands, the confusion
the renames address is mostly gone: once content is a reference, `DefinitionRevision`
plainly governs a revision rather than being one.

**A parallel `semantic.*` refusal registry.** The review proposes
`semantic.artifact-missing`, `semantic.scope-underdetermined` and others alongside
the existing `meaning.*` set. Two refusal vocabularies for one profile is the exact
fault we just repaired elsewhere in this codebase — a caller would have to know both.
Add the new *reasons* to the existing `meaning.*` registry instead.

## 7. The sequencing objection, unresolved

The article puts governance signals **third**, after a semantic layer and a light
ontology. We built the gate with neither underneath. The review calls this
"gate mis-timing" and warns it risks premature approvals.

I do not think this invalidates the profile — a gate that refuses is useful even
with nothing to gate, and Delta 1 makes P11 explicitly *about* artifacts it does not
own. But it does mean **Profile 11 cannot be demonstrated honestly without a
semantic artifact to point at.** The three-numbers case is the test to build.

## 8. The three-numbers test

Finance 10.2M, Marketing 10.4M, agent 9.8M. The review's modelling, which I accept:
not one Concept with three revisions in different scopes, but **three distinct
subjects** — `RecognizedRevenue`, `AttributedRevenue`, `CashCollectedRevenue` — each
with its own scope, policy and evidence, plus an explicit alignment relation to a
global revenue concept, and a dispute object if reconciliation is required.

That is a better answer than the one I would have given from the current spec, and
it is the concrete argument for Delta 3.

## 9. Recommendation

Adopt Deltas 1, 3, 4 (content-by-reference, alignment objects, verification
evidence). Gate Delta 2 on verifying §0. Decline the renames and the parallel
refusal registry. Build the three-numbers case as the conformance demonstration.

None of this is adopted. Each delta needs the spec amended, both ttl copies updated,
conformance extended, and a migration for existing rows.

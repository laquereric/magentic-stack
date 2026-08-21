<!--
Drafted 2026-08-20 after an adversarial critique by the Manus cloud agent
(task da2yEB8NPsTLTzdQHkEYfg, verdict: ADOPT WITH MODIFICATION). Review-ready
draft. Citations reflect that critique and are not independently verified.
-->

# OSI Level 8 — Profile 11: Meaning (Semantic Actability)

**Level 8 asks whether a message may cross the boundary. Profile 11 asks whether the
TERMS in it are admissible for the use being attempted.** A closed SHACL shape can
validate a perfectly-formed message whose central term is disputed, superseded, or
merely proposed. *Well-formed* and *fit to act on* are different properties, and only
the first is currently decidable.

## Core rule

**This profile does not decide what a term means.** Meaning is a social fact and no
protocol settles it; SKOS says as much about itself, and PROV-O records who attested
what without adjudicating truth [1][2]. Profile 11 decides something narrower and
decidable:

> Is this **definition revision** admissible for **this named use**, in **this scope**,
> under **this policy**, given **this evidence** — as of a stated sequence?

That question has a reproducible answer. "The meaning is settled" does not.

A Level-8 implementation MUST NOT treat a Profile 11 decision as a claim about the
world. It is a gate over artifacts.

## Why this is not Profile 5, 8 or 10

The profile earns its place only if this dependency direction is explicit. It pools
evidence from siblings and contributes exactly one thing: the gating decision.

| Sibling | Owns | Profile 11 uses it for |
|---|---|---|
| **P5** Biography and provenance | who asserted what, when, derived from what | the attestation trail behind a definition revision |
| **P6** Enterprise authorization evidence | whether an actor may attest at all | signer authority on an attestation |
| **P7** Observation and outcome | test and usage results | evidence that a binding actually holds |
| **P4** Durable cyborg execution | the operation that will run | the operation revision a binding pins |
| **P8** Architectural learning loop | proposals from observed use | candidate revisions entering the ladder |
| **P10** Intent | what the actor wants | the named use a decision is scoped to |

**Profile 11 owns none of that evidence.** It owns the policy evaluation over it, and
the receipt. A conforming implementation MUST reference sibling artifacts by IRI rather
than copying their content, so there is one home per fact (P2's reference-passing rule
applied to governance).

## Entity model

Thirteen record types, all immutable and content-addressed. Every field used in a gating
decision MUST be referential and provenance-linked. The original six remain the
actability core; `SemanticDispute` and `DisputeResolution` give the `dispute`
dimension attributable objects (they do not replace that dimension).
`SemanticAlignmentAssertion` and `FederationAgreement` give the `agreement`
dimension attributable objects the same way (they do not replace that dimension).
`SemanticVerificationEvidence` is the evidence that a revision's artifact is
internally consistent; without a passing `ontology-consistency` result,
`formalization=testable` MUST NOT hold.
`StewardshipTranslation` and `TranslationReview` are audience renderings of a
grounded Concept — they do **not** compete with `DefinitionRevision` and they
assert nothing about truth (they are not `SemanticAttestation`). There is no
`DefinitionTranslation` record.

| Record | Purpose | Pins |
|---|---|---|
| **Concept** | the term itself | absolute IRI, label, scope |
| **DefinitionRevision** | one immutable statement of the term | revision IRI, `normativeArtifact` (by digest), scope |
| **SemanticAttestation** | an actor vouching for a revision | signer, scope, evidence refs, P6 authority, time |
| **OperationBinding** | the revision wired to something runnable | definitionRevision, operationRevision, contractDigest, shapeDigest |
| **SemanticActivation** | which revision is current for a scope | policyRevision, selected revision, baseSequence |
| **ActabilityReceipt** | the decision, reproducible later | the exact tuple, derived bands, asOfSequence, digests |
| **SemanticDispute** | a scoped, attributable objection | target IRI, scope, raiser, claim, P5/P7 evidence refs |
| **DisputeResolution** | a traceable close of one dispute | dispute IRI, resolver, scope, P6 authority, disposition |
| **StewardshipTranslation** | an audience rendering of one Concept | `refersTo` Concept, `groundedIn` DefinitionRevision, audience, scope, author, rendering |
| **TranslationReview** | attributable accept / return / reject of a translation | translation IRI, reviewer, scope, P6 authority, outcome |
| **SemanticAlignmentAssertion** | a scoped, attributable local alignment between subjects | subject, alignsWith, participant, scope, mappingArtifact, evidenceRef |
| **FederationAgreement** | a federated agreement covering subjects across participants | subject, participant, scope, mappingArtifact, evidenceRef, P6 authority |
| **SemanticVerificationEvidence** | a signed check of an artifact revision | targetArtifactRevision, verificationKind, verifier, importClosureDigest, inputSnapshotDigest, result, producedAt, signedBy |

The current state of a Concept is **an activation row, never a mutated field** — the
same construction Profile 9 uses for design-token and ACIA successors.

The `dispute` dimension remains `none` | `open` | `resolved`. It is **not replaced**
by these objects. The evaluator still reads the dimension. The objects give that
dimension a target, scope, raiser, evidence, and a resolution that can be attributed.
Integrity: `dispute=open` holds for a scope exactly when at least one applicable
`SemanticDispute` lacks a valid `DisputeResolution`; `resolved` holds only when every
applicable dispute has one; `none` holds when no applicable dispute exists. Producers
that flip the dimension without the corresponding record are non-conforming.

The `agreement` dimension remains `none` | `local` | `federated`. It is **not
replaced** by alignment objects. The evaluator still reads the dimension, derived
from the objects: `none` when no applicable `SemanticAlignmentAssertion` exists;
`local` when at least one applicable assertion exists and no applicable
`FederationAgreement` covers the subject; `federated` when an applicable
`FederationAgreement` exists. The evaluator MUST NOT read `SemanticAttestation.agreement`
as stored state. Producers that flip the dimension without the corresponding
record are non-conforming. A `SemanticAlignmentAssertion` names `subject`,
`alignsWith`, `participant`, `scope`, `mappingArtifact`, and `evidenceRef`. A
`FederationAgreement` additionally names P6 `authorityRef`.

`formalization` remains `narrative` | `structured` | `testable` on the revision.
`testable` MUST NOT hold unless the latest applicable
`SemanticVerificationEvidence` with `verificationKind=ontology-consistency`
has `result=pass`. Missing evidence refuses `meaning.verification-missing`;
`result=fail` refuses `meaning.verification-failed` (because names the
revision, verificationKind, result, and scope). `schema-validation` and
`semantic-model-compile` are additional kinds in the same closed set; a fail
of the latest applicable evidence of any kind also refuses
`meaning.verification-failed`. These reasons live in the existing `meaning.*`
registry — there is no parallel `semantic.*` set.

A `DefinitionRevision` MUST NOT hold normative `content`. It pins a
`normativeArtifact` `{ artifactIri, artifactKind, profileOrFormat, versionIri,
contentDigest { algorithm, value }, mediaType, componentSelector, retrievalPolicy }`.
Profile 11 governs that artifact **by digest** and is not a fourth home for
meaning. A put that still carries `content` is refused (unknown predicate;
because names `content`). Required on the artifact: `artifactIri` and
`contentDigest.algorithm` + `contentDigest.value`. Missing or unverifiable
digest refuses `meaning.artifact-missing` (because names the revision,
`artifactIri`, digest, and scope). Existing rows that still carry `content`
are not rewritten (append-only); their bytes are copied into the artifact log
so a past receipt can still recompute.

A `StewardshipTranslation` MUST name exactly one `refersTo` Concept and one
`groundedIn` DefinitionRevision; that revision MUST belong to the Concept. A
translation does not alter `definitionLifecycle`, `agreement`, `binding`, or the
derived band. A `TranslationReview` records `approved` | `returned` | `rejected`
with reviewer and P6 `authorityRef`. Reviewing or using a translation whose
grounding revision is `withdrawn` or superseded MUST refuse
`meaning.translation-grounding-insufficient` (because names the translation,
Concept, grounding revision, and scope).

## Maturity: five closed dimensions, three derived bands

A single status column is the failure mode, not the design. It invites **maturity
inflation**: if one label unlocks the work, everything drifts to that label. So the
stored dimensions are closed sets, and the useful bands are **derived and never
stored**.

Stored (each a closed set, so conformance stays decidable):

- `definitionLifecycle` — `candidate` | `active` | `deprecated` | `withdrawn`
- `agreement` — `none` | `local` | `federated`
- `dispute` — `none` | `open` | `resolved`
- `formalization` — `narrative` | `structured` | `testable`
- `binding` — `unbound` | `declared` | `verified` | `stale`

Derived (computed per request, per scope, MUST NOT be persisted as state):

| Band | Holds when | Licenses |
|---|---|---|
| **explorable** | registered revision, lifecycle not `withdrawn`, scope declared, no blocking evidence | quote, reason about, plan against — **no Effects** |
| **plan-eligible** | explorable + `lifecycle=active` + `agreement>=local` + `formalization>=structured` + `dispute!=open` | commit to a plan; still no Effects |
| **effect-eligible** | plan-eligible + `binding=verified` + exact operation/contract digests + policy revision + authoritative attestation | dispatch an Effect |

These are the provisional / clarified / executable rungs of the original proposal,
kept as a human-facing vocabulary but **relocated from stored state to computed
result**. You cannot promote a term by editing it. You can only add evidence.

## Promotion, demotion, and inflation

- Promotion is never asserted; it is the arithmetic of evidence under a policy
  revision. There is no "set band" operation, and an implementation offering one is
  non-conforming.
- Demotion is automatic and requires no ceremony: withdraw an attestation, open a
  dispute, or change a pinned digest, and the band recomputes downward on the next
  evaluation.
- Every decision cites `policyRevision` and `asOfSequence`, so a past decision remains
  reproducible after the evidence moves on. A receipt is a claim about a moment, not a
  standing permission.

## Refusals

Level 8 refuses rather than raises. A Profile 11 refusal MUST carry a machine-readable
`because` enumerating **the missing evidence and what would satisfy it** — prose is
non-conforming, because the caller's next move has to be computable.

| Reason | Meaning |
|---|---|
| `meaning.term-unregistered` | no Concept for this IRI |
| `meaning.definition-version-required` | a bare term was used where a revision is required |
| `meaning.definition-inactive` | revision is `candidate`, `deprecated` or `withdrawn` |
| `meaning.scope-mismatch` | admissible somewhere, not in this scope |
| `meaning.actability-insufficient` | band below what the attempted use requires |
| `meaning.definition-contested` | `dispute=open` |
| `meaning.attestation-invalid` | signer lacked P6 authority, or evidence expired |
| `meaning.operation-binding-missing` | no binding for this operation |
| `meaning.binding-stale` | a pinned digest changed since verification |
| `meaning.policy-indeterminate` | request carried unknown properties (closed-shape rule) |
| `meaning.translation-grounding-insufficient` | a StewardshipTranslation is syntactically complete but cannot be responsibly affirmed as an account of its declared referent (grounding revision withdrawn or superseded) |
| `meaning.artifact-missing` | a DefinitionRevision's normativeArtifact digest is missing or unverifiable |
| `meaning.verification-missing` | `formalization=testable` but no applicable ontology-consistency evidence |
| `meaning.verification-failed` | applicable verification evidence has `result=fail` |

## Conformance

An implementation is falsified by any of these.

1. Register a candidate revision with scope and structured form → **explorable**, and
   `plan-eligible` MUST NOT hold.
2. Add an operation binding with no test evidence → refuse
   `meaning.actability-insufficient`.
3. Attest the exact tuple (`definitionRevision`, `operationRevision`, `contractDigest`,
   `implementationDigest`) → receipt with band **effect-eligible**.
4. **Change only the `contractDigest`** → MUST refuse `meaning.binding-stale` and MUST
   NOT dispatch. *This is the decisive case: it fails any implementation that resolves
   meaning at execution time instead of pinning it.*
5. Open a challenge, re-evaluate at the same `asOfSequence` → the earlier receipt still
   reproduces; a new evaluation yields `meaning.definition-contested`.
6. Send an unknown property → refuse `meaning.policy-indeterminate`.
7. Raise a `SemanticDispute` against an otherwise effect-eligible tuple →
   `dispute=open` for that scope and a new evaluation yields
   `meaning.definition-contested`. A `DisputeResolution` with `disposition` in
   `uphold|dismiss|require-revision` makes `dispute=resolved`; the resolution
   names resolver and P6 `authorityRef`.
8. A `StewardshipTranslation` without both `refersTo` and `groundedIn` is refused.
   A `TranslationReview` names reviewer and P6 `authorityRef`. A translation whose
   grounding `DefinitionRevision` is `withdrawn` or superseded refuses
   `meaning.translation-grounding-insufficient`.
9. A `DefinitionRevision` that still carries `content` (no `normativeArtifact`) is
   refused. A revision whose artifact digest is missing or unverifiable refuses
   `meaning.artifact-missing`.
10. No alignment objects → `agreement=none`. A `SemanticAlignmentAssertion` without
    a covering `FederationAgreement` → `agreement=local`. A `FederationAgreement`
    covering the subject → `agreement=federated`. An attestation that stores
    `agreement=federated` without those objects MUST NOT make `federated` hold.
11. A revision with `formalization=testable` and no passing
    `ontology-consistency` `SemanticVerificationEvidence` refuses
    `meaning.verification-missing` or `meaning.verification-failed`. It MUST NOT
    be treated as testable.

A conforming implementation MUST reproduce a past receipt from its pinned identifiers
alone. If a receipt cannot be recomputed without consulting current state, the
implementation is non-conforming.

## Persistence (non-normative)

The normative core is a **portable, content-addressed, append-only event log**. It is
deliberately not defined in terms of any framework: a guarantee that depends on one
vendor's triggers is not portable, and the receipts must be verifiable by digest
wherever they are read.

ActiveRecord is the reference materialization in this repository, following the
Profile 9 precedent exactly: `governed_columns` plus a ledger check, `BEFORE UPDATE`
and `BEFORE DELETE` triggers refusing mutation on every table, and current state
expressed as an activation row. That gives the durable substrate; the digests give the
portability. Neither alone is sufficient.

## Prior art, and what is genuinely left

Each of these solves part of the problem and none solves the gate [1]-[10].

- **SKOS** — concept registry substrate. Explicitly *not* a formal world-model, and it
  defines no maturity lifecycle [1].
- **PROV-O** — the attestation and derivation trail. Records provenance; does not
  adjudicate denotation [2].
- **OWL 2** — version IRIs, deprecation, annotation. Versioning without governance
  transitions or runtime gating [3].
- **W3C process (WD → CR → REC)** — a maturity ladder for *documents*, a useful
  analogy and not a model of domain-term denotation [4].
- **ISO 25964** — vocabulary governance practice. It does **not** define a term-maturity
  ladder, and citing it as if it did would be wrong [5].
- **SBVR** — business vocabulary and rules; a candidate input, not a wire-level gate [6].
- **FIPA ACL / KQML, Austin and Searle** — commitment and communicative acts; framing
  for *how* something is asserted, not whether the term is fit to act on [7][10].
- **Data contracts / schema registries** — the closest analogue for the `binding`
  dimension, governing interface stability rather than semantic content [8].
- **Peircean semiotics** — conceptual grounding only [9].

What remains unsolved by all of them, and is this profile's contribution: **a
reproducible, scope-bound, evidence-driven decision about whether a term's revision may
drive an Effect right now** — with a receipt that recomputes.

## Open questions

- `agreement=federated` needs a concrete cross-organisation attestation format; it is
  named here and not specified.
- Fast-path policy for low-risk scopes is required to prevent the gate becoming
  bureaucratic theatre people route around. Unspecified.
- Dispute *objects* now record target, raiser, scope, evidence, and a traceable
  `DisputeResolution` (resolver, disposition `uphold|dismiss|require-revision`, P6
  authority IRI). What remains deferred is **who has authority to resolve** — this
  profile records the resolution and its P6 evidence IRI; it does not decide the
  authority policy that licenses a given resolver.

## References

[1] SKOS Reference, W3C, 2009 — https://www.w3.org/TR/skos-reference/
[2] PROV-O: The PROV Ontology, W3C, 2013 — https://www.w3.org/TR/prov-o/
[3] OWL 2 versioning and annotation properties, W3C, 2012 — https://www.w3.org/TR/owl2-syntax/
[4] Types of documents W3C publishes — https://www.w3.org/standards/types/
[5] ISO 25964-1/2, Thesauri and interoperability with other vocabularies
[6] SBVR 1.5, OMG — https://www.omg.org/spec/SBVR/1.5/About-SBVR
[7] FIPA Communicative Act Library — https://www.fipa.org/specs/fipa00037/SC00037J.html
[8] Confluent Schema Registry data contracts — https://docs.confluent.io/platform/current/schema-registry/fundamentals/data-contracts.html
[9] Peirce's Theory of Signs, SEP — https://plato.stanford.edu/entries/peirce-semiotics/
[10] Speech Acts, SEP — https://plato.stanford.edu/entries/speech-acts/

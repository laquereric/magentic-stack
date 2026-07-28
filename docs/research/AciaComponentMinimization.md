# Minimizing a Shared Component Vocabulary: Converting Landing Pages into Reusable Component Trees

**Expert guidance brief**

Scope: 52 independently generated, self-contained landing pages in HTML; current baseline of approximately 17 base components; an RDF graph and SPARQL substrate; aim to minimize the total number of distinct components by reusing a shared vocabulary via a component tree representation. Edits to pages are allowed if they unlock reuse. The objective is to drive higher-level structures (fewer, larger reusable components) to reduce rendering model complexity and cost, while maintaining page quality and accessibility. A semantic-web substrate (RDF + SPARQL) is used for graph-tagging, provenance, and querying repeated sub-structures.

> Executive position: The goal is not to minimize the raw count of component names alone, but to minimize the description length of the 52 pages given a shared vocabulary. A small, well-structured grammar that derives all pages with bounded variation typically yields greater cost-efficiency than a tiny vocabulary with large per-page customization. The approach balances model complexity against data fidelity (MDL principle) and emphasizes high-level reusable components (organisms/templates) as the primary source of compression. The incumbent ~17 base components should remain the baseline, but the vocabulary must be validated against a minimum-description-length objective over the corpus and constrained by quality gates.

---

## 1) Componentization strategy — parsing a page into a component tree (atomic design levels: atoms/molecules/organisms/templates)

- Create a canonical representation: parse each landing page into a semantic layout tree (SLT) that preserves provenance and removes incidental DOM noise. Each SLT node is labeled with a compact tuple: <semantic-role, content-role, layout-kind, layout-arity, behavior-kind, responsive-signature, token-signature>.
  - Semantic-role captures landmarks and meaningful sections (e.g., banner, main, navigation, form).
  - Content-role identifies functional blocks (hero, feature, metric, pricing, etc.).
  - Layout-kind and layout-arity distinguish stacking, grid, split, carousel, etc. to separate structure from markup.
  - Behavior-kind encodes interactivity (static, link, button, form, disclosure, carousel).
  - Responsive-signature encodes responsive behavior (e.g., 2col→stack, mobile order constraints).
  - Token-signature maps to design tokens (colors, typography, spacing) rather than hard-coded CSS.

- Boundary discipline: collapse wrappers only when they add no semantic, behavioral, or layout contract. A candidate component boundary must have a coherent responsibility, a compact interface (finite props/slots), stable responsive behavior, and be reusable without dependence on ancestors/siblings or page-specific CSS.

- Two-tier design language: use Atomic Design as a diagnostic vocabulary, not a hard extraction rule. Treat tokens (design-token surface) separately from atoms/molecules/organisms/templates so that the vocabulary targets structural reuse while tokens normalize styling. Prefer organisms and templates as the primary compression frontier, while preserving atoms/molecules when their semantics or accessibility are stable across pages.

- Canonical component form: a component includes semantic root, a fixed skeleton with finite variants, a typed props schema, a set of named slots, and token constraints. Variants should be finite enums; avoid unbounded, free-form interfaces. A merge is only valuable if its combined skeleton and configurations reduce the total corpus cost more than it increases surface area elsewhere.

- Example boundary: a FeatureSection may be defined as a section with a stable heading, body, a media slot, and an actions slot, with two variant axes for media position and tone. This structure supports reuse across multiple pages without anchoring to a particular page’s content.

- Renderer contract: the final consumer model should render a compact component tree (JSON-like) rather than raw DOM. Example: a LandingShell with an internal Hero component and a MetricGrid, where each component is invoked with typed props and stable slots.

---

## 2) Structural mining — detecting common/near-duplicate sub-structures across 52 pages

- Multi-stage pipeline: Normalize → exact subtree hashing → frequent substructure mining → approximate clustering → verification via weighted tree edit distance → cluster synthesis → global tree-cover selection.

- Normalization: convert each page's DOM into an SLT with tokens for text placeholders and asset placeholders in order to minimize incidental variation while preserving semantic structures and behavior.

- Exact matching: fingerprint exact subtrees using Merkle-like hashes that depend on a canonical representation of the subtree (node label, ordered children, and slot placeholders).

- Approximate matching: use structured signatures (root label, subtree size, path-based fingerprints, geometry and token distributions) to identify plausible near-duplicates for more expensive comparison.

- Distance metric: use a typed, weighted tree-edit distance (insert/delete/modify) to score differences. Differences that preserve a component’s semantic/interaction contract are low-cost; changes to landmark semantics or critical interactions are high-cost and may veto a merge.

- Clustering: apply conservative clustering (e.g., complete linkage or medoid-based) to avoid chaining weak similarities into a single cluster. The goal is to derive a small, coherent set of candidate skeletons that can be parameterized by props/slots.

- Candidate generation: generate least-general-generalization (LGG) from clusters or paired candidates, then validate against the boundary budgets (allowed number of variants, props, slots, etc.). Only consider candidates whose boundary contracts are within budgets; disallow open-ended interfaces.

- RDF/SPARQL bookkeeping: store every page version as a named graph; record exact fingerprints, approximate buckets, cluster memberships, candidate skeletons, and provenance. Use SPARQL to perform provenance-aware discovery (e.g., which exact structures appear in at least three pages) and to audit the reuse efficiency.

- Practical mining rule: begin with exact, content-stable patterns across at least 3 pages and a minimum size for a candidate (roughly five SLT nodes). Expand to near-duplicates and then to higher-level organism-level patterns as evidence accrues.

---

## 3) The MINIMIZATION objective — when to merge two near-duplicate components vs keep distinct

- Objective framing: MDL-based model selection. Let J(V, A, R) be the total description length (model cost plus data cost, including rewrite and quality costs). The search aims to minimize J, with hard quality gates that cannot be violated.

- Components of the objective:
  - Ldef(V): cost of the vocabulary (skeletons, variants, props/slots, dependencies, and documentation/tests).
  - Lderive(A|V): cost of deriving per-page structures given the vocabulary (selected components, prop values, slots, ordering, and any residuals).
  - Lresidual(T|A, V): cost of any remaining page-specific subtrees not covered by a canonical component.
  - Loverride(A): cost for page-level adapters or escapes (raw HTML, uncontrolled class/style changes).
  - Lrewrite(R): cost of approved transformations (tiered rewrite budgets).
  - Risk(R): penalty for high-risk rewrites or integrations (forms, payment flows, accessibility-sensitive changes).
  - Qloss(P, R): penalty for quality loss when a rewrite is applied (regarding visual or accessibility impact).

- Acceptance rules: a merge is acceptable if semantic and interaction contracts match; the least-general generalized skeleton remains a bounded interface; there is page support (e.g., in at least three pages); and the full J decreases by a practical margin (ΔJ < 0 by a margin ε). Guardrails include: no more than three structural variants per organism, seven primary props, and three named slots. Merges that cross Tier-3 boundaries or introduce unbounded interfaces are rejected.

- Metrics to track:
  - Vocabulary count K = number of callable component definitions.
  - Distinct-page support per component (prefer high cross-page reuse).
  - Weighted organism coverage (nontrivial, recurring components that cover many pages).
  - Residual-tree ratio (amount of page structure still not captured by components).
  - Structural configuration entropy (to penalize overly varied variants/slots).
  - Override density (amount of page-specific CSS/markup introduced by a merge).
  - Rewrite burden (Tier 0–2 rewrite costs, plus review effort).
  - Constrained-renderer burden (how hard it is for the renderer to instantiate pages from the vocabulary).

- Merge strategy decisions: prefer parameterizing with props and slots over copying assets; if two components share a common skeleton, extract and reuse a shell; avoid merges that require open-ended markup or unbounded attributes; if the only gain is shallow wrapping, reject or split the boundary.

- Example decision rules:
  - Same skeleton with small data variations → merge with props.
  - Same skeleton with different linearized content → merge with finite variants.
  - Same skeleton but different semantic region → merge with typed slots; if not feasible, keep distinct.
  - Similar visuals but different accessibility semantics or landmark structure → keep distinct.
  - Two components sharing a common shell but with distinct bodies → extract the shell as a separate component only if independently reusable.

- Release gates: ensure quality checks (WCAG compliance, Core Web Vitals) before concluding a merge; require gating tests and visual diffs for each rewrite; maintain a provenance ledger so decisions are auditable.

---

## 4) Exhaustive iterative algorithm to approach the minimum (proposal-merge → re-measure → accept/reject)

Phase overview: The algorithm seeks to minimize J(V, A, R) over a finite candidate universe, defined by the current vocabulary, boundary budgets, allowed subtree sizes, and a fixed corpus version. It performs iterative proposals, global re-measurement, and acceptance decisions with clear audit trails.

- Phase 0: Baseline state. Compute an initial state using the incumbent vocabulary V0 (about 17 components) and no rewrites. Derive per-page trees and compute the initial J0.
- Phase 1: Candidate enumeration. Generate candidates from four sources: exact normalized subtree hashes; frequent closed/maximal subtrees; approximate clusters; and pairwise unifications of existing active definitions.
- Phase 2: Candidate evaluation. For each candidate, infer the least-general skeleton, propose prop/slot/variant schemas, and determine if the candidate stays within budgets. If the candidate introduces an open-ended interface or violates rewrite budgets, reject early.
- Phase 3: Global re-measurement after each proposal. Recompute a minimum-cost, non-overlapping tree cover across all affected pages, re-render pages, and run hard quality gates (visual, semantic, accessibility, and performance). If quality gates fail, reject the candidate.
- Phase 4: Acceptance check. If the proposal yields ΔJ < 0 by at least ε, accept it; otherwise, continue. Maintain an explicit ledger of all decisions, including rejected candidates and their reasons.
- Phase 5: Look-ahead and escape. If no single merge improves J, perform a bounded look-ahead to test coordinated moves among top candidates. If a coordination improves J, adopt it and re-measure.
- Phase 6: Branch-and-bound. When a reduced universe is stabilized (e.g., after several convergences), consider branch-and-bound to find an optimum within the reduced candidate space. If the search completes, report an optimal solution within the bounded universe; if not, report the best-known solution and the remaining optimality gap.
- Phase 7: Stopping criteria. Converge when no accepted merge improves J by ε across a complete pass, and look-ahead yields no further gains. Stop also under explicit budgets or time constraints; document which criteria triggered the stop. Convergence is reported as operational, search, or certificate-based depending on the stopping condition.

- Guardrails and guardrail-based metrics:
  - Enforce bound budgets for variants/props/slots per organism, with initial values (e.g., 3 variants, 7 props, 3 slots).
  - Require MDL improvement thresholds to justify rewrites; disallow Tier-3 changes from automatic minimization.
  - Maintain robust RC (regression checks): semantic, accessibility, rendering, and performance gates.

- Output artifacts:
  - A normalized tree and fingerprint index for every source page.
  - An RDF evidence dataset and a full decision ledger for each candidate.
  - The selected vocabulary with typed schemas and per-page derivations.
  - A quality-report matrix and a vocabulary-cost scorecard (K, MDL, coverage, entropy, etc.).
  - A final convergence statement indicating whether the optimum was achieved within the bounded universe or if a best-known solution is reported.

---

## 5) How much page rewriting is worth it, and guardrails to keep pages good

- Rewrite guidelines: rewrite only when a normalization turns accidental variation into a stable contract, yielding net MDL savings that exceed rewrite costs and risk. Normalize token values, reduce wrapper noise, and align similar sections to canonical skeletons; preserve content, semantics, accessibility, and interactions.
- Guardrails: prevent loss of critical content, preserve URLs and tracking hooks, avoid changing fundamental page goals, avoid changing marketing claims, and ensure accessibility and performance remain within agreed baselines. Each rewrite must be accompanied by a diffs-based, human-reviewed diff and thorough automated checks (WCAG conformance, Core Web Vitals, and layout stability).
- Tier policy for rewrites:
  - Tier 0: normalization of implementation (token replacement, minor wrapper removal) with automatic acceptance after tests.
  - Tier 1: canonical structural rewrites that swap in a canonical component skeleton while preserving semantics and content order; automatic after tests and diffs.
  - Tier 2: deliberate design normalizations to unlock reuse via a high-value organism/template; requires human review.
  - Tier 3: changes to information architecture or product claims; excluded from automatic minimization and require broader governance.
- Release gating: all rewrites must pass visual diffs at desktop/tablet/mobile breakpoints, maintain semantic structure and accessibility, and pass performance budgets; record all changes in RDF provenance.

---

## 6) An exhaustive, end-to-end pipeline (concrete, pipeline-oriented steps)

1) Freeze and baseline: version all 52 source pages, collect baseline screenshots, and record content/metadata/Accessibility/Performance baselines.
2) Canonicalize: parse DOM into SLTs, collapse safe wrappers, tokenize style into tokens, and generate SLTs with provenance.
3) Index and graph-tag: compute exact hashes, geometry signatures, and fingerprints; register these in RDF.
4) Mine candidates: run exact-match discovery, frequent-subtree mining, approximate clustering, and candidate synthesis.
5) Synthesize definitions: apply LGG to generate finite props/slots/invariants.
6) Score globally: re-cover affected pages, compute J, and generate a scorecard.
7) Refactor and validate: implement Tier 0–2 rewrites, render at breakpoints, and execute QA gates.
8) Iterate and certify: re-enumerate changed candidates, run bounded look-ahead, optionally run branch-and-bound, and produce a convergence certificate.
9) Govern: enforce a component registry and a clear policy that new component definitions must beat incumbent cost; require provenance for all changes.

- End-state artifact: a canonical, provenance-preserving semantic tree corpus with a compact component grammar that derives all 52 pages via typed component calls, with tokens encoding visual decisions and explicit, expensive, page-specific residuals captured as exceptions.

---

## 7) Prior art (atomic design, design tokens, component/UI mining, grammar induction, MDL, tree-substitution grammars)

- Atomic Design provides a hierarchical vocabulary (atoms, molecules, organisms, templates, pages) for thinking about component boundaries and composition. It informs boundaries and the compression frontier, but must not force every subtree into a named layer. [1]
- Design tokens (and tokens tokens grammar) help separate visual normalization from structural componentization; a shared token vocabulary supports consistent rendering and reduces variation in CSS surface, enabling more stable component reuse. The Design Tokens Community Group and related draft formats provide structured token/group/alias concepts; production use should pinned to a stable release rather than drafts. [9]
- Frequent subtree mining (FREQT-like) and tree-edit-distance-based similarity provide formal methods to identify recurrent substructures in tree-structured data, including DOM trees or SLTs. These form the core of candidate generation and similarity scoring, enabling scalable discovery of reusable fragments across many pages. [4] [5]
- Tree-substitution grammars (TSG) and their induced grammar variants offer a principled framework for representing reusable subtree fragments with substitution sites (slots). Inducing a TSG provides an explicit vocabulary for reusable fragments and their parameters, aligning well with the boundary/slot approach. [7]
- The MDL principle provides a rigorous framework for model selection in a two-part code: minimize the description length of the model plus the data given the model. MDL supports balancing vocabulary complexity against corpus compression and guards against overfitting by penalizing model complexity. [6]
- RDF and SPARQL provide a robust provenance- and governance-friendly data model for recording the evolving vocabulary, merges, and quality checks. RDF graphs can represent page provenance, component definitions, and derivations; SPARQL supports pattern matching, aggregation, and path queries for governance and auditing. [2] [3]
- Prior art related to automated generation and extraction of reusable web components from mockups or DOM structures demonstrates the feasibility of automated approaches to identify and instantiate reusable components from real-world web pages. Notable examples include VizMod-style approaches and related semantic segmentation methods for UI code generation. [8]
- The broader body of literature on site-level template extraction, DOM-based content extraction, and web-template extraction supports the feasibility of identifying boilerplate and common substructures across a corpus of pages, a prerequisite for cross-page component reuse. [4] [9] [10]

---

## References

> The following sources underpin the guidance with concrete methodologies and theoretical grounding. Inline citations use numeric references that appear in the text.

1. Brad Frost, Atomic Design Methodology. https://atomicdesign.bradfrost.com/chapter-2/
2. RDF 1.1 Concepts and Abstract Syntax. https://www.w3.org/TR/rdf11-concepts/
3. SPARQL 1.1 Query Language. https://www.w3.org/TR/sparql11-query/
4. Asai, et al., Efficient Substructure Discovery from Large Semi-structured Data. https://globals.ieice.org/en_transactions/information/10.1587/e87-d_12_2754/_p
5. Zhang & Shasha, Simple Fast Algorithms for the Editing Distance between Trees and Related Problems. https://epubs.siam.org/doi/10.1137/0218082
6. Grünwald, A Tutorial Introduction to the Minimum Description Length Principle. https://arxiv.org/abs/math/0406077
7. Cohn, Goldwater, Blunsom, Inducing Tree-Substitution Grammars. https://www.jmlr.org/papers/volume11/cohn10b/cohn10b.pdf
8. Bajammal, Mazinanian, Mesbah, Generating Reusable Web Components from Mockups. https://dl.acm.org/doi/10.1145/3238147.3238194
9. Design Tokens Format Module 2025.10 (Draft). https://www.designtokens.org/tr/drafts/format/
10. WCAG 2.2 — Web Content Accessibility Guidelines. https://www.w3.org/TR/WCAG22/
11. Web Vitals — web.dev. https://web.dev/articles/vitals

---

If you want to share or publish this guidance, you can copy the Markdown above into a GitHub GFM document and reference the sources via the embedded inline citations and the official URLs listed in the References section.

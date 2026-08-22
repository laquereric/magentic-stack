# Gemini Prompt — StewardshipTranslation Board Restyle

```text
Restyle the attached screenshot of the working **StewardshipTranslation Board** page. This is a governed decision surface, not a consumer dashboard: it must feel like a calm, serious financial or clinical review instrument where a responsible actor verifies what is known, disputed, permitted, and attributable before acting.

What you are looking at: a PageShell with a ScopeTrail breadcrumb, page title, ContextBanner, FilterBar, then two PanelFrames. The centrepiece is the host-owned five-column “Board projection” grid: **Inputs | Orientation | Meaning | Clarification | Stewardship**; it becomes a single stack below 48rem. A second stacked panel, “Selected exploration: evidence and eligibility,” contains a ReferentBridge, EvidencePanel, Disclosure, two ActionControls, and two inline RefusalNotices.

The product’s governing requirement is that, for any concept and declared scope, a person must be able to see the grounded definition, evidence-backed actability, disputes, binding state, and authorization boundary before attempting an operation; every permitted clarification or translation must be attributable and reviewable. A future audit must trace each audience rendering to the same canonical referent, active definition revision, attestation/dispute history, binding evidence, and authorization context. Make those requirements visible in the hierarchy: preserve an unbroken reading path from referent and scope to evidence, derived eligibility, refusal, and action; make provenance and review state legible as first-class supporting information rather than hidden metadata; and make the action boundary subordinate to its evidence.

Treat these as non-negotiable constraints:

- **CSS only.** The generated markup must remain exactly unchanged. Do not add wrappers, alter DOM order, rename or remove attributes, or propose component changes. Target only the existing `vv-*` classes and existing attributes, including `data-ux-node-cid`, `data-ux-node-id`, `data-ux-component-kind`, `data-ux-acia-digest`, `data-ux-token-digest`, `data-ux-content-role`, and `aria-label`.
- Express the restyle primarily through values in `@layer vv-tokens` using the existing CSS custom-property seam (`--vv-accent`, `--vv-ink`, `--vv-canvas`, font and spacing scales). Add narrowly scoped selectors only where tokens cannot achieve the intended distinction.
- Do not alter, hard-code, or otherwise fight the board’s host-owned `p9.r1.grid.board-5` responsive recipe or its 48rem stacking breakpoint.
- **Colour never carries meaning alone.** Keep explicit text labels, badges, iconography only where already available through CSS, borders, weight, and/or pattern alongside any colour. `Explore:` remains text. Do not treat green/red as `MEANING_BAND`; green/red may only support a Profile-11 band view and must not be the sole signal.
- Refusals are normal, inline journey content—not errors, toasts, hidden states, or decorative warnings. Derived actability is never stored or manually set: do not introduce any control or treatment that implies a steward can mark something executable; promotion occurs by adding evidence.
- Use system font stacks only; no web fonts, images, icons, external assets, or network-dependent techniques. Accessibility is essential: maintain strong contrast, clear focus-visible states, readable density, and non-colour status differentiation.

Return an implementation-ready proposal, not a mood board:

1. Start with a brief **current-design audit**: identify the most consequential ways the screenshot may already fail the mission (especially any weak distinction between refusal, evidence, derived eligibility, provenance, and ordinary content).
2. Give a compact **design rationale** tied directly to the mission and audit traceability, not personal taste.
3. Provide a concrete token block: exact hex values, system font stacks, type scale, line-height, spacing scale, radii, borders, shadows, focus treatment, and semantic/status tokens. Keep the palette restrained and professional.
4. Provide a CSS patch in `@layer vv-tokens` plus any necessary scoped selectors for existing `vv-*` classes and/or the listed existing attributes. Do not use hypothetical selectors or pseudocode; if a selector cannot be known from the screenshot, state the target attribute/class pattern and the intended rule precisely.
5. State how the patch makes evidence, canonical referent/provenance, derived eligibility, inline refusals, and action controls distinguishable without relying on colour; include responsive behaviour that leaves the existing five-column-to-stack recipe intact.

Favor hierarchy, typographic discipline, subtle surfaces, restrained separators, and evidence-led action over dashboard widgets, gradients, decorative illustration, excessive cards, or marketing-style visual effects.
```

## Short note

I excluded speculative component names, detailed record values, and an invented interaction model because the restyle must be grounded in the screenshot and constrained to the existing generated DOM. There is a small practical tension between asking for exact selectors and not providing a class inventory; the prompt resolves it by requiring Gemini to use known `vv-*` classes and existing attribute patterns, and to flag any selector it cannot verify instead of inventing markup.

The “no iconography” requirement was not stated; the prompt permits only CSS-supported differentiation where it is already structurally available, while expressly prohibiting external icon assets. This avoids an accidental demand for new DOM or network-loaded media.

## Delivery note

Paste only the content inside the fenced `text` block into Gemini alongside the PNG. The surrounding headings and short note are for the implementation team.

*Prepared by Manus AI.*

---

This Markdown file is the primary artifact; a PDF companion is supplied for convenient review.

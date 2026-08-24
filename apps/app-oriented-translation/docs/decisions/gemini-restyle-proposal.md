Here's an implementation-ready proposal for restyling the "Translation Board" page, adhering strictly to your constraints.

---

### 1. Current-Design Audit

The current design, while functional, lacks the gravity and structured clarity required for a "governed decision surface" in a financial or clinical context.

*   **Weak Distinction & Flat Hierarchy:**
    *   **Context/Filter:** `ContextBanner` and `FilterBar` blend into the background, not clearly signaling their role in defining the scope and parameters of the review.
    *   **Board Projection:** The five columns (`Inputs` to `Stewardship`) lack internal structure. `DataList` items are simple text blocks with `ActionControl`s, making it hard to discern factual statements, derived eligibility, or review states.
    *   **`ActionControl` Prominence:** Buttons are uniformly prominent, suggesting immediate action rather than a cautious, evidence-led process. This contradicts the requirement for actions to be "subordinate to its evidence."
    *   **`StatusBadge` Obscurity:** The badge is small and visually indistinct, failing to convey its importance in signaling the status of a concept.
    *   **Refusal Clarity:** `RefusalNotice` currently relies solely on red for distinction, which is explicitly forbidden as a sole signal and risks being interpreted as an "error" rather than "normal, inline journey content."
*   **Lack of Provenance/Auditability:**
    *   Crucial `data-ux-acia-digest` and `data-ux-token-digest` attributes are entirely invisible, rendering provenance (a first-class requirement) as hidden metadata.
*   **Aesthetic & Density:**
    *   The overall aesthetic is very stark and generic, lacking the "calm, serious" feel of a review instrument. Density is high, especially within `DataList` items, making complex information harder to parse.
*   **Action Boundary:** Actions are often placed directly next to the descriptive text without explicit visual cues linking them to supporting evidence, undermining the "evidence-led action" principle.

### 2. Design Rationale

The restyle aims to transform the board into a document-like, structured review instrument, emphasizing clarity, hierarchy, and auditability.

*   **Establish a Clear Visual Hierarchy:**
    *   Utilize a typographic scale, varied background tints, and subtle borders to define distinct sections (Context, Filter, Board, Exploration), guiding the user's eye through the decision-making process.
    *   Panel frames receive subtle shadows and borders to feel like tangible documents.
*   **Prioritize Information Over Action:**
    *   `ActionControl`s are visually subdued (transparent background, accent border) by default, signifying they are available but not urging immediate action. They gain prominence on `hover` and `focus` to indicate interactability without dominating the layout.
    *   Content within `DataList` items will have clear internal padding and spacing for readability.
*   **Make Provenance and Review State First-Class:**
    *   Provenance digests (`data-ux-acia-digest`, `data-ux-token-digest`) are explicitly rendered with a monospace font, smaller size, muted color, and a subtle dashed border, making them legible yet subordinate to primary content.
    *   `StatusBadge` gains a subtle border and uppercase styling for non-color distinction, reinforcing its role as a state indicator.
*   **Integrate Refusals as Structured Content:**
    *   `RefusalNotice` receives a soft, non-alarming background color, a distinct border, and a unicode "⛔" symbol (permitted as it's system-font-stack available CSS content, not an image) to provide clear, non-color-reliant distinction as normal, but unexecutable, content.
*   **Professional, Restrained Palette:**
    *   A cool-toned neutral palette (grays, off-whites) forms the base, with a single, deep blue accent for interactive elements. This creates a calm, professional environment with high contrast and accessibility.
*   **Responsive Integrity:**
    *   The styles are designed to be fluid and complement the host's 48rem stacking breakpoint, primarily by adjusting spacing and borders *within* stacked column blocks for improved readability.

This approach ensures an unbroken reading path from the concept's referent and scope through its supporting evidence, derived eligibility, and any refusals, to the point of action, fulfilling the auditability and governed decision surface requirements.

### 3. Concrete Token Block

```css
@layer vv-tokens {
  :root {
    /* Color Palette */
    --vv-canvas-base: #f8f9fa; /* Overall page background */
    --vv-canvas-surface: #ffffff; /* Main panel backgrounds */
    --vv-canvas-subtle: #eef2f6; /* Subtle background for distinction (e.g., filter bar, grid area, inner elements) */
    --vv-canvas-raised: #e0e6ec; /* Slightly darker for distinct elements or headers */
    --vv-canvas: var(--vv-canvas-surface); /* Default panel background */

    --vv-ink-base: #212529; /* Primary text */
    --vv-ink-secondary: #495057; /* Secondary text, labels, subtle info */
    --vv-ink-tertiary: #6c757d; /* Tertiary text, metadata, provenance */
    --vv-ink-disabled: #adb5bd; /* Disabled states */
    --vv-ink-contrast: #ffffff; /* Ink on accent/dark backgrounds */
    --vv-ink: var(--vv-ink-base); /* Default ink */

    --vv-accent-base: #0056b3; /* Primary interactive color (a deep blue) */
    --vv-accent-hover: #004085; /* Darker on hover */
    --vv-accent-focus: #0056b3; /* Focus ring color */
    --vv-accent-light: #e6f0fa; /* Light accent for backgrounds or subtle indicators */
    --vv-accent-border: #80bdff; /* Focus border */
    --vv-accent: var(--vv-accent-base); /* Default accent */

    /* Semantic/Status Tokens */
    /* Refusal is normal content, needs distinct but non-alarming treatment */
    --vv-status-error-light: #fbeae1; /* Soft peach/cream for refusal background */
    --vv-status-error-dark: #a85f4e; /* Darker reddish-brown for refusal text */
    --vv-status-error-border: #d49a8e; /* Subtle border for refusal */

    /* Typography */
    --vv-font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji";
    --vv-font-size-xs: 0.75rem; /* For provenance, smallest labels */
    --vv-font-size-sm: 0.875rem; /* For small text, metadata */
    --vv-font-size-base: 1rem; /* Default body text */
    --vv-font-size-md: 1.125rem; /* For important text, subheadings */
    --vv-font-size-lg: 1.25rem; /* For section titles */
    --vv-font-size-xl: 1.5rem; /* For major titles like "Board projection" */
    --vv-font-size-xxl: 2rem; /* For page title "Translation Board" */
    --vv-font-weight-normal: 400;
    --vv-font-weight-medium: 500;
    --vv-font-weight-bold: 700;
    --vv-line-height-tight: 1.2;
    --vv-line-height-base: 1.5;
    --vv-line-height-loose: 1.7;

    /* Spacing Scale */
    --vv-spacing-xs: 0.25rem;
    --vv-spacing-sm: 0.5rem;
    --vv-spacing-md: 1rem;
    --vv-spacing-lg: 1.5rem;
    --vv-spacing-xl: 2rem;
    --vv-spacing-xxl: 3rem;

    /* Radii */
    --vv-radius-sm: 0.125rem;
    --vv-radius-md: 0.25rem;
    --vv-radius-lg: 0.5rem; /* For card-like elements */

    /* Borders */
    --vv-border-width-sm: 1px;
    --vv-border-width-md: 2px;
    --vv-border-color-light: #e0e6ec; /* Lighter border for internal divisions */
    --vv-border-color-default: #ced4da; /* Standard border for panels */
    --vv-border-color-dark: #adb5bd; /* Darker border for stronger separation */

    /* Shadows (subtle, for depth) */
    --vv-shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.03);
    --vv-shadow-md: 0 2px 5px rgba(0, 0, 0, 0.06), 0 0px 1px rgba(0, 0, 0, 0.03);

    /* Focus Treatment */
    --vv-focus-ring-color: var(--vv-accent-border);
    --vv-focus-ring-width: 2px;
    --vv-focus-ring-offset: 2px;
  }
}
```

### 4. CSS Patch

```css
/* Overall Page Styling */
body {
  background-color: var(--vv-canvas-base);
  font-family: var(--vv-font-family);
  color: var(--vv-ink-base);
  line-height: var(--vv-line-height-base);
  margin: 0;
  padding: var(--vv-spacing-xl); /* Overall page padding */
  font-size: var(--vv-font-size-base);
}

/* Page Title and Breadcrumb */
h1[data-ux-component-kind="PageTitle"] {
    font-size: var(--vv-font-size-xxl);
    font-weight: var(--vv-font-weight-bold);
    color: var(--vv-ink-base);
    margin-bottom: var(--vv-spacing-sm);
    margin-top: var(--vv-spacing-xl); /* Space from the top of the body */
}

span[data-ux-component-kind="ScopeTrail"] {
    font-size: var(--vv-font-size-sm);
    color: var(--vv-ink-tertiary);
    margin-bottom: var(--vv-spacing-lg);
    display: block;
}

/* Context Banner and Filter Bar */
div[data-ux-component-kind="ContextBanner"] {
  background-color: var(--vv-accent-light);
  color: var(--vv-ink-secondary);
  padding: var(--vv-spacing-md) var(--vv-spacing-lg);
  border-radius: var(--vv-radius-sm);
  margin-bottom: var(--vv-spacing-lg);
  border-left: var(--vv-border-width-md) solid var(--vv-accent-base); /* Strong visual cue */
  font-size: var(--vv-font-size-sm);
}

div[data-ux-component-kind="FilterBar"] {
  background-color: var(--vv-canvas-subtle);
  padding: var(--vv-spacing-md) var(--vv-spacing-lg);
  border-radius: var(--vv-radius-sm);
  margin-bottom: var(--vv-spacing-xl);
  border: var(--vv-border-width-sm) solid var(--vv-border-color-light);
  font-size: var(--vv-font-size-sm);
}

/* SemanticText Headings */
h2[data-ux-content-role="semantic-text-title"] {
  font-size: var(--vv-font-size-xl);
  font-weight: var(--vv-font-weight-medium);
  margin-top: var(--vv-spacing-xxl); /* Significant space from previous section/panel */
  margin-bottom: var(--vv-spacing-lg);
  color: var(--vv-ink-base);
}

/* Panel Frames (Board Projection & Selected Exploration) */
div[data-ux-component-kind="PanelFrame"] {
    background-color: var(--vv-canvas-surface);
    border: var(--vv-border-width-sm) solid var(--vv-border-color-default);
    border-radius: var(--vv-radius-md);
    padding: var(--vv-spacing-lg) var(--vv-spacing-xl);
    margin-bottom: var(--vv-spacing-xl);
    box-shadow: var(--vv-shadow-sm);
}

/* Board Projection Grid */
.vv-grid.board-5 {
  gap: var(--vv-spacing-sm); /* Gap between columns */
  background-color: var(--vv-canvas-subtle); /* Subtle background for the entire board area */
  padding: var(--vv-spacing-md);
  border-radius: var(--vv-radius-md);
  border: var(--vv-border-width-sm) solid var(--vv-border-color-light);
}

/* Column Headers within Board Projection */
.vv-grid.board-5 > div[data-ux-content-role="column-header"] {
  font-size: var(--vv-font-size-lg);
  font-weight: var(--vv-font-weight-bold);
  padding: var(--vv-spacing-md);
  text-align: left;
  color: var(--vv-ink-base);
  background-color: var(--vv-canvas-raised); /* Darker background for headers */
  border-radius: var(--vv-radius-sm);
  margin-bottom: var(--vv-spacing-sm);
  border-bottom: var(--vv-border-width-sm) solid var(--vv-border-color-default);
}

/* DataList Items within columns */
/* This targets the individual item containers (e.g., "Email — Harbour alert...") */
div[data-ux-component-kind="DataList"] > div:not([data-ux-content-role="column-header"]) {
  background-color: var(--vv-canvas-surface);
  border: var(--vv-border-width-sm) solid var(--vv-border-color-light);
  border-radius: var(--vv-radius-sm);
  padding: var(--vv-spacing-md);
  margin-bottom: var(--vv-spacing-sm); /* Spacing between items */
  line-height: var(--vv-line-height-tight);
}

/* Text content within DataList items */
div[data-ux-component-kind="DataList"] > div > p {
  font-size: var(--vv-font-size-sm);
  color: var(--vv-ink-secondary);
  margin-top: 0;
  margin-bottom: var(--vv-spacing-sm); /* Space before action control */
}

/* MetricStrip Component */
div[data-ux-component-kind="MetricStrip"] {
    background-color: var(--vv-canvas-surface);
    border: var(--vv-border-width-sm) solid var(--vv-border-color-light);
    border-radius: var(--vv-radius-sm);
    padding: var(--vv-spacing-md);
    margin-bottom: var(--vv-spacing-sm);
    font-size: var(--vv-font-size-sm);
    color: var(--vv-ink-secondary);
}

/* Status Badge */
span[data-ux-component-kind="StatusBadge"] {
  display: inline-flex;
  align-items: center;
  gap: var(--vv-spacing-xs);
  padding: var(--vv-spacing-xs) var(--vv-spacing-sm);
  font-size: var(--vv-font-size-xs);
  font-weight: var(--vv-font-weight-medium);
  border-radius: var(--vv-radius-sm);
  margin-bottom: var(--vv-spacing-sm);
  background-color: var(--vv-canvas-subtle);
  color: var(--vv-ink-secondary);
  border: var(--vv-border-width-sm) solid var(--vv-border-color-light); /* Non-color distinction */
  text-transform: uppercase;
  letter-spacing: 0.025em;
  line-height: 1;
}

/* Action Controls */
button[data-ux-component-kind="ActionControl"] {
  background-color: transparent; /* Subdued by default */
  color: var(--vv-accent-base);
  border: var(--vv-border-width-sm) solid var(--vv-accent-base); /* Primary visual cue */
  padding: var(--vv-spacing-xs) var(--vv-spacing-md);
  font-size: var(--vv-font-size-sm);
  font-weight: var(--vv-font-weight-medium);
  border-radius: var(--vv-radius-sm);
  cursor: pointer;
  transition: background-color 0.15s ease-in-out, color 0.15s ease-in-out, border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
  display: inline-flex; /* For potential icons/text alignment */
  align-items: center;
  justify-content: center;
  gap: var(--vv-spacing-xs);
  margin-top: var(--vv-spacing-xs); /* Slight margin from text above */
}

button[data-ux-component-kind="ActionControl"]:hover {
  background-color: var(--vv-accent-light); /* Gains prominence on hover */
  border-color: var(--vv-accent-hover);
  color: var(--vv-accent-hover);
}

button[data-ux-component-kind="ActionControl"]:focus-visible {
  outline: var(--vv-focus-ring-width) solid var(--vv-focus-ring-color);
  outline-offset: var(--vv-focus-ring-offset);
  border-color: var(--vv-accent-focus);
}

/* Selected Exploration Panel: Heading */
div[data-ux-component-kind="PanelFrame"] > h3[data-ux-content-role="exploration-title"] {
  font-size: var(--vv-font-size-lg);
  font-weight: var(--vv-font-weight-bold);
  color: var(--vv-ink-base);
  margin-bottom: var(--vv-spacing-lg);
  padding-bottom: var(--vv-spacing-sm);
  border-bottom: var(--vv-border-width-sm) solid var(--vv-border-color-light);
}

/* Components within 'Selected exploration' panel */
div[data-ux-component-kind="ReferentBridge"],
div[data-ux-component-kind="EvidencePanel"],
div[data-ux-component-kind="Disclosure"] {
  background-color: var(--vv-canvas-subtle);
  border: var(--vv-border-width-sm) solid var(--vv-border-color-light);
  border-radius: var(--vv-radius-sm);
  padding: var(--vv-spacing-md);
  margin-bottom: var(--vv-spacing-sm);
  font-size: var(--vv-font-size-sm);
  color: var(--vv-ink-secondary);
}

div[data-ux-component-kind="ReferentBridge"] {
    font-weight: var(--vv-font-weight-medium); /* Emphasize its bridging role */
    color: var(--vv-ink-base);
}

/* Provenance Information (Digests) */
[data-ux-acia-digest],
[data-ux-token-digest] {
  font-family: monospace, var(--vv-font-family); /* Distinct monospace font */
  font-size: var(--vv-font-size-xs); /* Smallest text size */
  color: var(--vv-ink-tertiary); /* Muted color */
  display: block;
  margin-top: var(--vv-spacing-xs);
  white-space: nowrap; /* Prevent line breaks within the hash */
  overflow: hidden;
  text-overflow: ellipsis;
  padding-top: var(--vv-spacing-xs);
  border-top: var(--vv-border-width-sm) dashed var(--vv-border-color-light); /* Subtle visual separator */
  margin-bottom: var(--vv-spacing-xs);
}

/* Refusal Notice */
div[data-ux-component-kind="RefusalNotice"] {
  background-color: var(--vv-status-error-light); /* Soft background */
  color: var(--vv-status-error-dark); /* Darker text */
  border: var(--vv-border-width-sm) solid var(--vv-status-error-border); /* Distinct border */
  border-radius: var(--vv-radius-sm);
  padding: var(--vv-spacing-md);
  margin-top: var(--vv-spacing-md);
  margin-bottom: var(--vv-spacing-md);
  font-size: var(--vv-font-size-sm);
  font-weight: var(--vv-font-weight-medium);
  position: relative;
}

/* Non-color distinction for RefusalNotice with a unicode symbol */
div[data-ux-component-kind="RefusalNotice"]::before {
  content: "⛔"; /* Unicode "No Entry" symbol */
  font-size: var(--vv-font-size-md);
  line-height: 1; /* Ensures vertical alignment */
  color: var(--vv-status-error-dark);
  position: absolute;
  left: var(--vv-spacing-md);
  top: 50%;
  transform: translateY(-50%);
  opacity: 0.8;
  padding-right: var(--vv-spacing-sm); /* Space between icon and text */
}

/* Adjust padding-left for RefusalNotice content due to pseudo-element icon */
div[data-ux-component-kind="RefusalNotice"] {
  padding-left: calc(var(--vv-spacing-md) + var(--vv-font-size-md) + var(--vv-spacing-sm));
}


/* Responsive Behavior for Board Projection (below 48rem breakpoint) */
@media (max-width: 48rem) {
  .vv-grid.board-5 {
    gap: var(--vv-spacing-md); /* More vertical gap between stacked column blocks */
    padding: var(--vv-spacing-md);
  }

  /* Each logical "column" (including its header and content) becomes a distinct card */
  .vv-grid.board-5 > div {
    background-color: var(--vv-canvas-surface);
    border: var(--vv-border-width-sm) solid var(--vv-border-color-default);
    border-radius: var(--vv-radius-md); /* Full radius for each stacked column block */
    padding: var(--vv-spacing-md);
    margin-bottom: var(--vv-spacing-lg); /* Space between stacked column blocks */
  }

  /* Styling for the header within its stacked column block */
  .vv-grid.board-5 > div[data-ux-content-role="column-header"] {
      background-color: var(--vv-canvas-raised);
      font-size: var(--vv-font-size-md); /* Slightly smaller header font */
      border-bottom: var(--vv-border-width-sm) solid var(--vv-border-color-light); /* Separator from its content */
      margin-bottom: var(--vv-spacing-md); /* Space between header and its content */
      border-radius: var(--vv-radius-md) var(--vv-radius-md) 0 0; /* Rounded top only */
      padding-top: var(--vv-spacing-md); /* Ensure internal padding */
      padding-left: var(--vv-spacing-md);
      padding-right: var(--vv-spacing-md);
  }

  /* Reset margin on the last stacked column block */
  .vv-grid.board-5 > div:last-of-type {
      margin-bottom: 0;
  }
}
```

### 5. Distinction Explanation

This CSS patch makes evidence, canonical referent/provenance, derived eligibility, inline refusals, and action controls distinguishable without relying on color, and supports responsive behavior as follows:

1.  **Canonical Referent & Provenance:**
    *   **ReferentBridge (`div[data-ux-component-kind="ReferentBridge"]`):** Elevated with `var(--vv-canvas-subtle)` background, a border, and `var(--vv-font-weight-medium)` with `var(--vv-ink-base)` color, making it visually distinct as a key identifier.
    *   **Provenance Digests (`[data-ux-acia-digest]`, `[data-ux-token-digest]`):** Rendered with a `monospace` font family, `var(--vv-font-size-xs)` (smallest size), `var(--vv-ink-tertiary)` (muted color), and a `var(--vv-border-width-sm) dashed var(--vv-border-color-light)` top border. This creates a subtle, machine-readable visual signature that clearly separates it as metadata without making it primary content. `display: block`, `white-space: nowrap`, and `text-overflow: ellipsis` ensure it's legible while handling long hashes gracefully.

2.  **Evidence & Derived Eligibility:**
    *   **Panel Frames (`div[data-ux-component-kind="PanelFrame"]`):** Both "Board projection" and "Selected exploration" are encased in panels with `var(--vv-canvas-surface)` background, `var(--vv-border-width-sm) solid var(--vv-border-color-default)` border, and `var(--vv-shadow-sm)` for subtle depth, signifying them as primary document sections.
    *   **DataList Items (`div[data-ux-component-kind="DataList"] > div`):** Individual items (e.g., "Email — Harbour alert...") within the board columns and the `MetricStrip` are treated as distinct "cards" with `var(--vv-canvas-surface)` background, a `var(--vv-border-width-sm) solid var(--vv-border-color-light)` border, and internal padding. This makes each piece of information (representing known facts, disputes, or derived eligibility) a discernible unit.
    *   **Status Badge (`span[data-ux-component-kind="StatusBadge"]`):** Uses `var(--vv-canvas-subtle)` background, `var(--vv-ink-secondary)` text, and a `var(--vv-border-width-sm) solid var(--vv-border-color-light)` border, along with `text-transform: uppercase` and `letter-spacing`. This provides a clear, non-color visual signal of status or state.
    *   **EvidencePanel & Disclosure (`div[data-ux-component-kind="EvidencePanel"]`, `div[data-ux-component-kind="Disclosure"]`):** Also receive `var(--vv-canvas-subtle)` backgrounds and borders, visually grouping them as supporting evidence and additional information.

3.  **Inline Refusals:**
    *   **RefusalNotice (`div[data-ux-component-kind="RefusalNotice"]`):** Styled with `var(--vv-status-error-light)` (soft peach) background, `var(--vv-status-error-dark)` (dark reddish-brown) text, and a `var(--vv-border-width-sm) solid var(--vv-status-error-border)` border. Crucially, a `::before` pseudo-element adds a `⛔` (No Entry) unicode symbol. This combination provides strong, non-color-reliant visual distinction as normal, unexecutable content, clearly communicating a block without implying an "error state."

4.  **Action Controls (Subordinate to Evidence):**
    *   **ActionControl (`button[data-ux-component-kind="ActionControl"]`):** By default, buttons have a `transparent` background and are outlined by `var(--vv-border-width-sm) solid var(--vv-accent-base)`. Their color is `var(--vv-accent-base)`. This makes them present but visually lighter than the surrounding content, reinforcing that review is primary.
    *   **Interaction States:** On `hover`, the background fills with `var(--vv-accent-light)`, and the border/text darken to `var(--vv-accent-hover)`. On `focus-visible`, a distinct `outline` with `var(--vv-focus-ring-color)` is applied. This progressive enhancement ensures buttons become more prominent only when a user actively engages with them, visually subordinating them to the review process.

5.  **Responsive Behavior (48rem stacking breakpoint):**
    *   The host's `p9.r1.grid.board-5` recipe for stacking is entirely preserved. My CSS focuses on making the *stacked content* more readable.
    *   **Stacked Column Blocks:** When columns stack, each original "column" (including its header and `DataList` content) is treated as a self-contained card. This is achieved by applying `background-color: var(--vv-canvas-surface)`, `border`, and `border-radius` to `.vv-grid.board-5 > div` within the `@media (max-width: 48rem)` block. This ensures clear separation and readability for each block of information.
    *   **Stacked Column Headers:** Headers (`div[data-ux-content-role="column-header"]`) within these stacked blocks maintain their distinct background (`var(--vv-canvas-raised)`) and gain a `border-bottom` to visually separate them from their immediate content, further enhancing internal organization. Spacing (`margin-bottom`, `gap`) is adjusted for improved vertical flow on smaller screens.
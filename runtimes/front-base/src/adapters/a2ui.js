/* Copy of BACK Ui::A2ui::KIND_MAP. FRONT can speak A2UI 0.9.1 without
 * asking Rails to emit. BACK emit stays the grant for ui.surface.get?as=a2ui.
 * Disclosure / FilterBar stay unmapped (counted, Text placeholders).
 */
(function (g) {
  "use strict";
  g.FrontA2ui = {
    VERSION: "v0.9.1",
    KIND_MAP: {
      PageShell: "Column",
      PanelFrame: "Card",
      SemanticText: "Text",
      StatusBadge: "Text",
      MetricStrip: "Text",
      ContextBanner: "Card",
      DrillDownCard: "Card",
      DataList: "List",
      Timeline: "List",
      EvidencePanel: "Card",
      DecisionForm: "Card",
      ActionControl: "Button",
      TabSet: "Tabs",
      EmptyState: "Text",
      RefusalNotice: "Card",
      ScopeTrail: "Text",
      ReferentBridge: "Text",
      DateInput: "DateTimeInput",
      Input: "TextField"
    }
  };
})(typeof globalThis !== "undefined" ? globalThis : window);

/* Copy of BACK Ui::AdaptiveCards::KIND_MAP. Date is Input.Date, never Input.Text. */
(function (g) {
  "use strict";
  g.FrontAdaptiveCards = {
    VERSION: "1.5",
    KIND_MAP: {
      PageShell: "AdaptiveCard",
      PanelFrame: "Container",
      SemanticText: "TextBlock",
      StatusBadge: "TextBlock",
      MetricStrip: "FactSet",
      ContextBanner: "Container",
      DrillDownCard: "Container",
      DataList: "Container",
      Timeline: "Container",
      EvidencePanel: "Container",
      DecisionForm: "Container",
      ActionControl: "Action.Submit",
      TabSet: "ActionSet",
      EmptyState: "TextBlock",
      RefusalNotice: "TextBlock",
      ScopeTrail: "FactSet",
      ReferentBridge: "TextBlock",
      DateInput: "Input.Date",
      Input: "Input.Text"
    }
  };
})(typeof globalThis !== "undefined" ? globalThis : window);

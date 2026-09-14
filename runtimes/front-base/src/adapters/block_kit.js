/* Copy of BACK Ui::BlockKit::KIND_MAP. Date is datepicker, never plain_text_input. */
(function (g) {
  "use strict";
  g.FrontBlockKit = {
    VERSION: "block-kit-1",
    KIND_MAP: {
      PageShell: "modal",
      PanelFrame: "section",
      SemanticText: "section",
      StatusBadge: "context",
      MetricStrip: "section",
      ContextBanner: "header",
      DrillDownCard: "section",
      DataList: "section",
      Timeline: "section",
      EvidencePanel: "section",
      DecisionForm: "input",
      ActionControl: "button",
      TabSet: "overflow",
      EmptyState: "section",
      RefusalNotice: "section",
      ScopeTrail: "context",
      ReferentBridge: "section",
      DateInput: "datepicker",
      Input: "plain_text_input"
    }
  };
})(typeof globalThis !== "undefined" ? globalThis : window);

# frozen_string_literal: true

require "json"
require "digest"

CORR = "corr-demo-nineteen"
DIGEST = "sha256:#{'a' * 64}"

def node(id, kind, value, children = [])
  {
    "nodeId" => id,
    "componentKind" => kind,
    "props" => { "propsSchemaCid" => "cid:schema:#{kind.downcase}", "valueJson" => value },
    "children" => children
  }
end

root = node("demo-pageshell-1", "PageShell", {
  "title" => "Harbor District heat-alert review",
  "heading" => "Governed review",
  "body" => "Whether the public Cooling Access Site map may be activated during a heat alert.",
  "conclusion" => "Not effect-eligible in the current evidence state."
}, [
  node("demo-contextbanner-1", "ContextBanner", {
    "heading" => "You are oriented before you decide",
    "body" => "This view distinguishes what is settled, contested, and not yet actable.",
    "tone" => "quiet",
    "availability" => "live"
  }),
  node("demo-scopetrail-1", "ScopeTrail", {
    "heading" => "Effective scope",
    "ordered-scope" => ["City of Rivulet", "Harbor District", "2026 Heat Safety Programme"],
    "conclusion" => "Harbor District programme is the decision scope."
  }),
  node("demo-metricstrip-1", "MetricStrip", {
    "label" => "Effect-eligible operations",
    "conclusion" => "0 of 1 requested"
  }),
  node("demo-statusbadge-1", "StatusBadge", {
    "label" => "Actability",
    "tone" => "warning",
    "body" => "Explorable, not effect-eligible"
  }),
  node("demo-panelframe-1", "PanelFrame", {
    "heading" => "Settled enough to inspect",
    "body" => "Read-only orientation. No activation control is offered."
  }, [
    node("demo-semantictext-1", "SemanticText", {
      "heading" => "Cooling Access Site",
      "body" => "A designated public place that remains available during a declared heat alert.",
      "references" => ["cid:concept:cooling-access-site"]
    }),
    node("demo-datalist-1", "DataList", {
      "heading" => "Known / contested",
      "body" => "Known records versus open dispute.",
      "references" => ["cid:dispute:after-hours"]
    }, [
      node("demo-drilldowncard-1", "DrillDownCard", {
        "heading" => "After-hours public availability",
        "body" => "A SemanticDispute remains open: whether a site remains a Cooling Access Site when access is restricted after 18:00.",
        "tone" => "warning",
        "conclusion" => "Open dispute"
      })
    ])
  ]),
  node("demo-timeline-1", "Timeline", {
    "heading" => "Evidence sequence",
    "body" => "Request-time evaluation, not a cached readiness result.",
    "trigger" => "Heat-alert map activation requested"
  }),
  node("demo-evidencepanel-1", "EvidencePanel", {
    "heading" => "Authorization and outcomes",
    "body" => "P6 authorization and P7 outcomes references are not available in this request.",
    "references" => ["cid:p6:missing", "cid:p7:missing"],
    "conclusion" => "Insufficient for effect",
    "tone" => "warning"
  }),
  node("demo-referentbridge-1", "ReferentBridge", {
    "sourceConcept" => "https://ex/concept/cooling-access-site",
    "sourceDefinitionRevision" => "https://ex/revision/dr-042",
    "targetExpression" => "cooling-access-site",
    "mappingArtifact" => "https://ex/map/st-003",
    "mappingProof" => "https://ex/proof/tr-003",
    "sourceToTargetScope" => "https://ex/scope/harbor-to-site",
    "conclusion" => "Referent retained for review, not for effect."
  }),
  node("demo-filterbar-1", "FilterBar", {
    "label" => "Shown records",
    "availability" => "canonical-only",
    "ordered-scope" => ["Harbor District"]
  }),
  node("demo-tabset-1", "TabSet", {
    "label" => "Inspection partitions",
    "body" => "Sources, Transformations, and Related References share this snapshot.",
    "availability" => "read-only"
  }),
  node("demo-emptystate-1", "EmptyState", {
    "heading" => "No effect-eligible operations",
    "body" => "Nothing in this scope currently satisfies effect eligibility.",
    "availability" => "derived-at-request-time"
  }),
  node("demo-disclosure-1", "Disclosure", {
    "heading" => "Why no activation control is offered",
    "body" => "Effect eligibility is derived from evidence and record state. It cannot be granted by a decision maker's request."
  }),
  node("demo-decisionform-1", "DecisionForm", {
    "heading" => "Closed decision",
    "body" => "Approve or deny only after effect eligibility is restored.",
    "label" => "Activation decision",
    "action" => "request-effect",
    "availability" => "denied"
  }, [
    node("demo-actioncontrol-1", "ActionControl", {
      "label" => "Request effect",
      "action" => "request-effect",
      "availability" => "denied",
      "body" => "Bound to the same identifier as the RefusalNotice operation."
    })
  ]),
  node("demo-refusalnotice-1", "RefusalNotice", {
    "operation" => "request-effect",
    "reason" => "meaning.actability-insufficient",
    "failedCriteria" => %w[
      dispute-open
      authorization-reference-missing
      outcomes-reference-missing
      semantic-activation-missing
      actability-receipt-missing
    ],
    "evidenceRefs" => ["cid:page:demo-nineteen", "https://ex/dispute/after-hours"],
    "remediation" => "Clarify the disputed after-hours condition, obtain authorization and outcomes references, then create activation and receipt records.",
    "overridePolicy" => "none",
    "heading" => "Effect refused: Cooling Access Site is not effect-eligible"
  })
])

pkg = {
  "@type" => "ux:AciaDocumentPackage",
  "correlation" => CORR,
  "aciaDigest" => DIGEST,
  "pageCid" => "cid:page:demo-nineteen",
  "document" => {
    "schemaVersion" => "acia/v1",
    "componentRegistryVersion" => "ghis-19@1",
    "rootNode" => root
  }
}

SEMANTIC = {
  "PageShell" => ["main", "landmark", "context"],
  "PanelFrame" => ["article", "article", "context"],
  "SemanticText" => ["h2", "heading", "context"],
  "StatusBadge" => ["div", "status", "observation"],
  "MetricStrip" => ["div", "status", "observation"],
  "ContextBanner" => ["div", "status", "context"],
  "DrillDownCard" => ["article", "article", "evidence"],
  "DataList" => ["ul", "list", "evidence"],
  "Timeline" => ["ol", "timeline", "provenance"],
  "EvidencePanel" => ["article", "article", "evidence"],
  "DecisionForm" => ["form", "form", "authorization"],
  "ActionControl" => ["button", "button", "action"],
  "Disclosure" => ["article", "article", "help"],
  "FilterBar" => ["div", "status", "navigation"],
  "TabSet" => ["div", "navigation", "navigation"],
  "EmptyState" => ["div", "status", "empty"],
  "RefusalNotice" => ["div", "alert", "refusal"],
  "ScopeTrail" => ["ul", "list", "navigation"],
  "ReferentBridge" => ["article", "article", "evidence"]
}

def esc(s)
  s.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
end

def render_html(n)
  kind = n["componentKind"]
  tag, _role, content = SEMANTIC[kind]
  title = n.dig("props", "valueJson", "title") || n.dig("props", "valueJson", "label") || n.dig("props", "valueJson", "heading") || kind
  attrs = [
    %(data-ux-node-cid="cid:node:#{n['nodeId']}"),
    %(data-ux-node-id="#{n['nodeId']}"),
    %(data-ux-component-kind="#{kind}"),
    %(data-ux-acia-digest="#{DIGEST}"),
    %(data-ux-token-digest="sha256:demo-tokens"),
    %(data-ux-content-role="#{content}"),
    %(aria-label="#{esc(title)}")
  ]
  attrs << %(role="alert") if kind == "RefusalNotice"
  attrs << %(role="status") if %w[ContextBanner StatusBadge].include?(kind)
  kids = Array(n["children"]).map { |c| render_html(c) }.join
  %(<#{tag} #{attrs.join(' ')}><span data-ux-label>#{esc(title)}</span>#{kids}</#{tag}>)
end

json = JSON.generate(pkg).gsub("<", "\\u003c")
html = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>vv-html-components demo — Harbor District heat-alert review</title>
  <script src="../dist/vv-html-components.js" defer></script>
</head>
<body>
<p style="font:14px/1.4 system-ui,sans-serif;margin:1rem 2rem;color:#465462">
  Open this file in a browser. No server. The include is
  <code>&lt;script src="../dist/vv-html-components.js" defer&gt;&lt;/script&gt;</code>.
  Nineteen kinds, one conformant ACIA document, matching correlation and digest.
</p>
<script type="application/ld+json" data-ux-acia-document>#{json}</script>
<div class="ux-render-root" data-ux-correlation="#{CORR}" data-ux-acia-digest="#{DIGEST}" data-ux-token-digest="sha256:demo-tokens">
#{render_html(root)}
</div>
</body>
</html>
HTML

out = File.expand_path("index.html", __dir__)
File.write(out, html)
kinds = []
walk = lambda { |n|
  kinds << n["componentKind"]
  Array(n["children"]).each { |c| walk.call(c) }
}
walk.call(root)
warn "wrote #{out} kinds=#{kinds.uniq.size} #{kinds.uniq.sort.join(',')}"

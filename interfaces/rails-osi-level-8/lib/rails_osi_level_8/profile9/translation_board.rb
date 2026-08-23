# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    module Acia
      module_function

      # Q9 — StewardshipTranslation Board as a request-time ACIA projection.
      # Populated active-exploration snapshot matching docs/board/ (UC-02 origin
      # plus UC-07/08/09/10 walls). Not a stored board status. Not a fifth journey.
      def translation_board_inspect_document
        doc = Marshal.load(Marshal.dump(translation_board_document))
        doc["projectionKind"] = "inspect"
        doc["predecessorDigest"] = "sha256:board-predecessor"
        doc["predecessorCorrelation"] = "corr-board-pred"
        doc["inspectOriginNodeId"] = "brd-or-evacuate"
        marks = {
          "brd-or-evacuate" => "selected",
          "brd-mn-evac" => "likely-hit",
          "brd-mn-protective" => "related",
          "brd-mn-suggest" => "suggested",
          "brd-or-volunteers" => "out-of-scope"
        }
        stamp = lambda { |n|
          next unless n.is_a?(Hash)
          if n["componentKind"] == "DrillDownCard" && marks[n["nodeId"]]
            n["props"]["valueJson"]["presentationState"] = marks[n["nodeId"]]
          end
          Array(n["children"]).each { |c| stamp.call(c) }
        }
        stamp.call(doc["root"])
        doc
      end

      # The board with the semantic editor OPEN.
      #
      # A <dialog> is display:none until opened, which is what the board itself
      # wants. The open state is a different PROJECTION, not a runtime toggle:
      # the node id names the slot, so a document carrying brd-frame-editor-open
      # is a board whose editor is open -- with its own digests and cids, which
      # keeps what was edited exactly as traceable as what was read.
      def translation_board_editor_document
        doc = Marshal.load(Marshal.dump(translation_board_document))
        rename = lambda { |n|
          next unless n.is_a?(Hash)
          n["nodeId"] = "brd-frame-editor-open" if n["nodeId"] == "brd-frame-editor"
          Array(n["children"]).each { |c| rename.call(c) }
        }
        rename.call(doc["root"])
        doc
      end

      def translation_board_document
        {
          "schemaVersion" => "acia/v1",
          "componentRegistryVersion" => "ghis-19@1",
          "root" => node(
            "brd-pageshell-1", "PageShell",
            slt("landmark", "context", "stack", "many", "static"),
            {
              "title" => "Translation Board",
              "pagePurpose" => "semantic-projection",
              "projectionKind" => "request-time",
              "note" => "Eligibility, highlight, and suggestion presence are request-time display. They are not stored board status. Green/red is a Profile-11 band view, never MEANING_BAND."
            },
            children: [
              node("brd-scopetrail-1", "ScopeTrail",
                slt("list", "context", "inline", "many", "static"),
                {
                  "effectiveScope" => "https://ex/scope/harbour-resilience/translation-board",
                  "segment" => [
                    { "scope" => "https://ex/scope/workbench", "relation" => "contains" },
                    { "scope" => "https://ex/scope/harbour-resilience", "relation" => "narrows" },
                    { "scope" => "https://ex/scope/harbour-resilience/translation-board", "relation" => "contains" }
                  ]
                }),
              node("brd-title-1", "SemanticText",
                slt("heading", "context", "stack", "one", "static"),
                { "text" => "Translation Board", "level" => "page" }),
              node("brd-banner-1", "ContextBanner",
                slt("status", "context", "inline", "one", "static"),
                {
                  "freshness" => "live",
                  "policy" => "canonical-only",
                  "shown" => "Eligibility is derived at request time — board position does not change it.",
                  "heading" => "Live, canonical only",
                  "body" => "Eligibility is derived at request time — board position does not change it."
                }),
              node("brd-filterbar-1", "FilterBar",
                slt("form", "navigation", "inline", "many", "filter"),
                { "filters" => "source,referent,evidence,suggestions" }),
              node("brd-board-1", "PanelFrame",
                slt("landmark", "context", "grid", "three", "static", responsive: "p9.r1.grid.board-3"),
                { "title" => "Board projection", "panelKey" => "translation-board" },
                children: [
                  column_input,
                  column_frame,
                  column_translation
                ]),
              selected_exploration,
              frame_editor_dialog
            ]
          )
        }
      end


      # --------------------------------------------------------- three columns
      # Input is frame-independent. Frame is the apparatus it is read through.
      # Translation is what applying the one to the other produces.
      #
      # The previous five columns are not gone -- they are the hierarchy BENEATH
      # these three. Meaning and Clarification belong to the Frame (Y1:M1,
      # Y1:M1:C1). Reference and Stewardship are produced (X1:Y1:R1, X1:Y1:Z1).

      def column_input
        column_inputs
      end
      private_class_method :column_input

      def column_frame
        node("brd-col-frame", "PanelFrame",
          slt("article", "context", "stack", "three", "static"),
          { "title" => "Frame", "panelKey" => "frame",
            "purpose" => "The way of seeing this input is read through." },
          children: [
            frame_bar,
            column_meaning,
            column_clarification
          ])
      end
      private_class_method :column_frame

      # The operative Frame, chosen. behaviorKind is `navigate` rather than
      # `filter`: choosing a Frame does not narrow a set, it re-roots the whole
      # Translation -- different spans, References, Meanings and carries.
      #
      # A bar of buttons, not a pulldown. A pulldown hides the alternatives
      # behind a click, and the alternatives are the point: the reason to look
      # at this board is that the SAME input reasons differently under a
      # different frame. They should all be on screen, with the operative one
      # unmistakable.
      #
      # The operative frame is named by NODE ID (brd-frame-operative), not by
      # which frame it happens to be. This is a request-time projection: change
      # the frame and the whole document is re-derived, so whichever frame is
      # operative occupies that slot.
      def frame_bar
        node("brd-frame-bar", "PanelFrame",
          slt("input", "navigation", "stack", "two", "static"),
          { "title" => "Operative frame", "panelKey" => "frame-bar",
            "purpose" => "Changing the frame re-derives the Translation. Nothing is settled by looking." },
          children: [frame_choices, frame_tools])
      end
      private_class_method :frame_bar

      def frame_choices
        node("brd-frame-choices", "PanelFrame",
          slt("input", "navigation", "inline", "three", "static"),
          { "title" => "Frames", "panelKey" => "frame-choices" },
          children: [
            frame_choice("brd-frame-operative", "Y1 — Harbour operations", operative: true),
            frame_choice("brd-frame-alt-1", "Y2 — Community liaison"),
            frame_choice("brd-frame-alt-2", "Y3 — Regulatory duty")
          ])
      end
      private_class_method :frame_choices

      # The check is CONTENT, not decoration. A background colour alone leaves a
      # colour-blind reader guessing which frame their Translation came from,
      # and that is exactly the thing they must not have to guess.
      def frame_choice(node_id, label, operative: false)
        node(node_id, "ActionControl",
          slt("button", "navigation", "inline", "one", "navigate"),
          { "title" => operative ? "Operative frame: #{label}" : "Read this input through #{label}",
            "label" => operative ? "✓ #{label}" : label,
            "availability" => operative ? "operative" : "available",
            "action" => "select-frame",
            "body" => operative ? "This frame is in force." : "Read this input through it instead." })
      end
      private_class_method :frame_choice

      # Frames are the user's own. They are constructed, kept, and retired by
      # the person reasoning -- so add and remove sit beside the frames
      # themselves, not in a settings screen somewhere else.
      def frame_tools
        node("brd-frame-tools", "PanelFrame",
          slt("input", "action", "inline", "three", "static"),
          { "title" => "Frame tools", "panelKey" => "frame-tools" },
          children: [
            node("brd-frame-add", "ActionControl",
              slt("button", "action", "inline", "one", "collect_effect"),
              { "title" => "Add a frame",
                "label" => "+ Frame",
                "action" => "create-frame",
                "body" => "Start a new way of seeing.",
                "availability" => "always" }),
            node("brd-frame-remove", "ActionControl",
              slt("button", "action", "inline", "one", "confirm"),
              { "title" => "Retire the operative frame",
                "label" => "− Frame",
                "action" => "retire-frame",
                "body" => "Retire this way of seeing.",
                "availability" => "Confirmed first — Translations derived under it stop being derivable." }),
            node("brd-frame-prose", "ActionControl",
              slt("button", "action", "inline", "one", "disclose"),
              { "title" => "Write this frame in prose",
                "label" => "Write in prose",
                "action" => "open-frame-prose",
                "body" => "Open the editor.",
                "availability" => "Meanings and clarifications are editable in the same text." })
          ])
      end
      private_class_method :frame_tools


      # ------------------------------------------------- the semantic editor
      # Prose mode, mounted as a modal over the board. The editor itself lives
      # in mmg-semantic-editor and is headless: it knows about ACIA trees,
      # canonical ids, disclosure tiers and prose, and nothing about this board.
      #
      # Why prose. A Frame is easier to think about as a paragraph than as a
      # form. A person writing that paragraph is editing a frame record, two
      # meaning records and their clarifications at once; the canonical ids at
      # the head of each block are what let the editor put each line back where
      # it came from, so the person never has to hold those boundaries.
      #
      # The dialog is part of the projection rather than a runtime overlay
      # bolted on: it carries the same digests and cids as everything else, so
      # what was edited is as traceable as what was read.
      def frame_editor_dialog
        node("brd-frame-editor", "PanelFrame",
          slt("dialog", "action", "overlay", "three", "collect_effect"),
          { "title" => "Y1 — Harbour operations, in prose",
            "panelKey" => "frame-editor",
            "purpose" => "Edit the frame and everything it carries as one text." },
          children: [
            node("brd-editor-note", "ContextBanner",
              slt("status", "help", "inline", "one", "static"),
              { "freshness" => "live",
                "policy" => "canonical-only",
                "shown" => "Each block is headed by its canonical id. Keep the id and you are editing that record; remove it and you are writing a new one.",
                "heading" => "Ids are how one text becomes several edits",
                "body" => "Each block is headed by its canonical id. Keep the id and you are editing that record; remove it and you are writing a new one." }),
            node("brd-editor-prose", "DecisionForm",
              slt("form", "action", "stack", "one", "collect_effect"),
              { "title" => "Frame prose",
                "heading" => "Y1 — Harbour operations",
                "label" => "Frame, meanings and clarifications",
                "body" => frame_prose,
                "availability" => "Editable. Clarifications are included even though they sit in the sidebar tier on the board.",
                "action" => "apply-frame-edits",
                "conclusion" => "Applied whole or not at all. A plan whose parts landed separately could leave a Meaning its Clarifications no longer explain." }),
            node("brd-editor-scope", "Disclosure",
              slt("list", "provenance", "stack", "one", "disclose"),
              { "title" => "What this edit would touch",
                "heading" => "What this edit would touch",
                "body" => "One text, four records.",
                "references" => [
                  "Y1 — frames",
                  "Y1:M1 — meanings",
                  "Y1:M2 — meanings",
                  "Y1:M1:C1 — clarifications (sidebar tier, not shown on the board)"
                ],
                "conclusion" => "X1:Y1 is derived per request and is not written by this edit." })
          ])
      end
      private_class_method :frame_editor_dialog

      # The prose format is deliberately plain -- not markdown, not YAML. It is
      # the smallest thing that survives a person retyping it by hand.
      def frame_prose
        [
          "[Y1] Harbour operations",
          "Frames what we are here to look after, and what counts as looking after it.",
          "",
          "  [Y1:M1] Berth allocation is a duty of care",
          "  A berth is not a slot on a chart. Who gets one, and when, decides whose",
          "  livelihood is interrupted.",
          "",
          "    [Y1:M1:C1] A vessel already alongside is not thereby entitled to stay.",
          "",
          "  [Y1:M2] Tide windows bind everyone equally",
          "  No vessel is owed a window another loses."
        ].join("\n")
      end
      private_class_method :frame_prose

      def column_translation
        node("brd-col-translation", "PanelFrame",
          slt("article", "context", "stack", "two", "static"),
          { "title" => "Translation", "panelKey" => "translation",
            "purpose" => "This input, seen through this frame." },
          children: [
            column_orientation,
            column_stewardship
          ])
      end
      private_class_method :column_translation

      def column_inputs
        node("brd-col-inputs", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Inputs", "panelKey" => "inputs", "purpose" => "Stuff that happens." },
          children: [
            node("brd-in-metric", "MetricStrip",
              slt("status", "observation", "inline", "many", "static"),
              { "received" => 3, "inActiveExploration" => 0 }),
            node("brd-in-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "inputs" },
              children: [
                input_card("brd-in-email", "Email — Harbour alert wording concerns",
                  "Email gateway", "2025-05-08 08:23"),
                input_card("brd-in-research", "Research — Hazard terminology review",
                  "Research portal", "2025-05-07 16:41"),
                input_card("brd-in-chat", "Chat — Duty officer feedback",
                  "Ops chat log", "2025-05-08 09:02")
              ])
          ])
      end
      private_class_method :column_inputs

      def column_orientation
        node("brd-col-orientation", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Reference", "panelKey" => "orientation",
            "purpose" => "What have we settled this part of the input means?" },
          children: [
            ctrl("brd-or-add", "Add reference point", "add-orientation-point", "collect_effect"),
            node("brd-or-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "orientation" },
              children: [
                node("brd-or-evacuate", "DrillDownCard",
                  slt("listitem", "observation", "stack", "one", "inspect"),
                  {
                    "title" => "Residents hear 'evacuate' as immediate removal",
                    "excerpt" => "Interview 04 · Community liaison",
                    "provenance" => "cid:interview:04"
                  },
                  variant: "emphasis",
                  children: [
                    badge("brd-or-evacuate-badge", "Selected — active exploration"),
                    ctrl("brd-or-evacuate-explore", "Explore", "explore", "inspect")
                  ]),
                node("brd-or-volunteers", "DrillDownCard",
                  slt("listitem", "observation", "stack", "one", "inspect"),
                  {
                    "title" => "Volunteer translators need local context",
                    "excerpt" => "Interview 05 · Volunteer coord.",
                    "provenance" => "cid:interview:05"
                  },
                  children: [
                    ctrl("brd-or-volunteers-explore", "Explore", "explore", "inspect")
                  ])
              ])
          ])
      end
      private_class_method :column_orientation

      def column_meaning
        node("brd-col-meaning", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Meaning", "panelKey" => "meaning", "purpose" => "What am I making of this?" },
          children: [
            node("brd-mn-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "meaning-accepted" },
              children: [
                node("brd-mn-evac", "DrillDownCard",
                  slt("listitem", "observation", "stack", "one", "inspect"),
                  {
                    "title" => "Evacuation notice is an immediate direction to leave",
                    "excerpt" => "Accepted working account. Display band is a request-time derivation, not a stored field.",
                    "displayBandLabel" => "Effect-eligible"
                  },
                  children: [
                    badge("brd-mn-evac-badge", "Eligibility: effect-eligible"),
                    ctrl("brd-mn-evac-inspect", "Inspect eligibility", "inspect-eligibility", "inspect"),
                    ctrl("brd-mn-evac-explore", "Explore", "explore", "inspect")
                  ]),
                node("brd-mn-protective", "DrillDownCard",
                  slt("listitem", "observation", "stack", "one", "inspect"),
                  {
                    "title" => "Protective action may mean staying or leaving",
                    "excerpt" => "Agreement and binding not met. Explorable is the honest rendering of not adequate for planning or effect — not 'rejected'.",
                    "displayBandLabel" => "Explorable",
                    "disputeOpen" => true
                  },
                  children: [
                    badge("brd-mn-protective-badge", "Eligibility: not eligible — clarification incomplete", tone: "warning"),
                    ctrl("brd-mn-protective-inspect", "Inspect eligibility", "inspect-eligibility", "inspect"),
                    ctrl("brd-mn-protective-continue", "Continue clarification", "continue-clarification", "navigate"),
                    ctrl("brd-mn-protective-wall", "Enter productive-refusal wall", "enter-productive-refusal-wall", "navigate")
                  ])
              ]),
            node("brd-mn-suggest-banner", "ContextBanner",
              slt("status", "context", "inline", "one", "static"),
              {
                "freshness" => "live",
                "policy" => "canonical-only",
                "shown" => "Machine suggestions — unaccepted. These are proposals for review. They are not established meanings and are not eligible as accepted Board content."
              }),
            node("brd-mn-suggest-heading", "SemanticText",
              slt("heading", "context", "stack", "one", "static"),
              { "text" => "Machine suggestions — unaccepted", "level" => "region" }),
            node("brd-mn-suggest-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "meaning-suggestions" },
              children: [
                node("brd-mn-suggest", "DrillDownCard",
                  slt("listitem", "observation", "stack", "one", "inspect"),
                  {
                    "title" => "Candidate: protective action as locally specified response",
                    "excerpt" => "Machine-proposed, unaccepted. No eligibility band is claimed.",
                    "suggestion" => true
                  },
                  children: [
                    ctrl("brd-mn-suggest-consider", "Consider", "consider-suggestion", "navigate"),
                    ctrl("brd-mn-suggest-decline", "Decline", "decline-suggestion", "acknowledge")
                  ])
              ])
          ])
      end
      private_class_method :column_meaning

      def column_clarification
        node("brd-col-clarification", "PanelFrame",
          slt("article", "evidence", "stack", "many", "static"),
          { "title" => "Clarification", "panelKey" => "clarification",
            "purpose" => "What clarification do I need?" },
          children: [
            node("brd-cl-list", "DataList",
              slt("list", "evidence", "stack", "many", "static"),
              { "listKey" => "clarification" },
              children: [
                node("brd-cl-duty", "DrillDownCard",
                  slt("listitem", "evidence", "stack", "one", "inspect"),
                  {
                    "title" => "Duty officer wording agreement signed",
                    "excerpt" => "Source: Doc · 2025-05-07 14:12. Evidence cue is not a Meaning band."
                  },
                  variant: "emphasis",
                  children: [
                    badge("brd-cl-duty-badge", "Evidence complete"),
                    ctrl("brd-cl-duty-view", "View evidence", "view-evidence", "inspect")
                  ]),
                node("brd-cl-families", "DrillDownCard",
                  slt("listitem", "evidence", "stack", "one", "inspect"),
                  {
                    "title" => "Test families' interpretation of protective action",
                    "excerpt" => "Missing evidence. Completing this card does not itself change a Meaning band."
                  },
                  variant: "emphasis",
                  children: [
                    badge("brd-cl-families-badge", "Evidence missing", tone: "danger"),
                    ctrl("brd-cl-families-continue", "Continue clarification", "continue-clarification", "navigate")
                  ]),
                node("brd-cl-formalize", "DrillDownCard",
                  slt("listitem", "evidence", "stack", "one", "inspect"),
                  {
                    "title" => "Formalize local terminology reference",
                    "excerpt" => "Source: Terminology register · 2025-05-06 11:33"
                  },
                  children: [
                    ctrl("brd-cl-formalize-view", "View evidence", "view-evidence", "inspect")
                  ])
              ])
          ])
      end
      private_class_method :column_clarification

      def column_stewardship
        node("brd-col-stewardship", "PanelFrame",
          slt("article", "authorization", "stack", "many", "static"),
          { "title" => "Stewardship", "panelKey" => "stewardship",
            "purpose" => "What is required to carry the meaning forward into action?" },
          children: [
            node("brd-st-suggest-banner", "ContextBanner",
              slt("status", "context", "inline", "one", "static"),
              {
                "freshness" => "live",
                "policy" => "canonical-only",
                "shown" => "Machine suggestions — unaccepted. These are proposals for review. They are not established meanings and are not eligible as accepted Board content."
              }),
            node("brd-st-suggest-heading", "SemanticText",
              slt("heading", "context", "stack", "one", "static"),
              { "text" => "Machine suggestions — unaccepted", "level" => "region" }),
            node("brd-st-suggest-list", "DataList",
              slt("list", "authorization", "stack", "many", "static"),
              { "listKey" => "stewardship-suggestions" },
              children: [
                node("brd-st-draft", "DrillDownCard",
                  slt("listitem", "authorization", "stack", "one", "inspect"),
                  {
                    "title" => "Draft bilingual alert guidance",
                    "excerpt" => "Suggested — contingent. Only after effect-eligible meaning and authority review. Display is not authorization.",
                    "suggestion" => true
                  },
                  children: [
                    ctrl("brd-st-draft-view", "View proposal", "view-proposal", "inspect")
                  ])
              ]),
            node("brd-st-list", "DataList",
              slt("list", "authorization", "stack", "many", "static"),
              { "listKey" => "stewardship-accepted" },
              children: [
                node("brd-st-authority", "DrillDownCard",
                  slt("listitem", "authorization", "stack", "one", "inspect"),
                  {
                    "title" => "Authority sign-off required",
                    "excerpt" => "Authority: Harbour Master. Status: Pending."
                  },
                  children: [
                    ctrl("brd-st-authority-view", "View authority", "view-authority", "inspect")
                  ]),
                node("brd-st-refusal", "DrillDownCard",
                  slt("listitem", "refusal", "stack", "one", "acknowledge"),
                  { "title" => "Refused stewardship carry", "excerpt" => "The proposed carry remains inspectable. Meaning eligibility does not override this refusal." },
                  variant: "warning",
                  children: [
                    node("brd-st-refusal-notice", "RefusalNotice",
                      slt("alert", "refusal", "stack", "one", "acknowledge"),
                      {
                        "operation" => "issue-unverified-action-language",
                        "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
                        "failedCriteria" => %w[authorization-reference-missing],
                        "evidenceRefs" => ["cid:page:board-stewardship", "https://ex/authority/harbour-master"],
                        "remediation" => "Obtain Harbour Master sign-off, then re-enter the stewardship flow. Do not treat this card as Done.",
                        "overridePolicy" => "none",
                        "heading" => "Refusal: Do not issue unverified action language"
                      },
                      variant: "warning"),
                    ctrl("brd-st-refusal-inspect", "Inspect refusal", "inspect-refusal", "inspect")
                  ])
              ])
          ])
      end
      private_class_method :column_stewardship

      def selected_exploration
        node("brd-explore-1", "PanelFrame",
          slt("article", "evidence", "stack", "many", "inspect"),
          { "title" => "Selected exploration: evidence and eligibility", "panelKey" => "selected-exploration" },
          children: [
            node("brd-rb-selected", "ReferentBridge",
              slt("article", "evidence", "stack", "one", "static"),
              {
                "sourceConcept" => "https://ex/concept/evacuate-immediate-removal",
                "sourceDefinitionRevision" => "https://ex/revision/interview-04",
                "targetExpression" => "Evacuation notice is an immediate direction to leave",
                "mappingArtifact" => "https://ex/map/orientation-to-meaning",
                "mappingProof" => "https://ex/proof/orientation-to-meaning",
                "sourceToTargetScope" => "https://ex/scope/harbour-resilience/orientation-to-meaning"
              }),
            node("brd-ev-panel", "EvidencePanel",
              slt("article", "evidence", "stack", "one", "inspect"),
              {
                "source" => "p11:eligibility-explanation",
                "evidenceCid" => "cid:projection:eligibility:protective-action",
                "criteria" => [
                  { "criterion" => "referent-identifiable", "result" => "passing", "ref" => "https://ex/crit/referent" },
                  { "criterion" => "core-meaning-clear", "result" => "passing", "ref" => "https://ex/crit/core-meaning" },
                  { "criterion" => "agreement-evidence", "result" => "failing", "ref" => "https://ex/crit/agreement" },
                  { "criterion" => "binding-intention", "result" => "failing", "ref" => "https://ex/crit/binding" },
                  { "criterion" => "dispute-open", "result" => "failing", "ref" => "https://ex/dispute/evacuate" }
                ]
              }),
            node("brd-disclosure-1", "Disclosure",
              slt("article", "provenance", "stack", "one", "disclose"),
              { "label" => "Show all criteria and provenance", "policy" => "canonical-only" }),
            ctrl("brd-enter-wall", "Enter productive-refusal wall", "enter-productive-refusal-wall", "navigate"),
            ctrl("brd-inspect-dispute", "Inspect dispute", "inspect-dispute", "inspect"),
            node("brd-uc07-refusal", "RefusalNotice",
              slt("alert", "refusal", "stack", "one", "acknowledge"),
              {
                "operation" => "claim-plan-eligible",
                "reason" => "meaning.actability-insufficient",
                "failedCriteria" => %w[agreement-not-evidenced-for-planning binding-not-verified dispute-open],
                "evidenceRefs" => ["cid:projection:eligibility:protective-action", "https://ex/dispute/evacuate"],
                "remediation" => "Enter the productive-refusal wall with this meaning, eligibility explanation, and dispute material. Do not drag the card into Clarification or Stewardship.",
                "overridePolicy" => "none",
                "heading" => "Accountable planning or effect cannot be claimed now"
              },
              variant: "warning"),
            node("brd-uc10-refusal", "RefusalNotice",
              slt("alert", "refusal", "stack", "one", "acknowledge"),
              {
                "operation" => "drag-card-to-column",
                "reason" => "MEANING_BAND_FORBIDDEN",
                "failedCriteria" => %w[board-position-not-eligibility],
                "evidenceRefs" => ["cid:page:translation-board"],
                "remediation" => "Inspect eligibility, then continue clarification. Eligibility is derived from evidence and criteria; board position cannot change it.",
                "overridePolicy" => "none",
                "heading" => "Eligibility is derived from evidence and criteria; board position cannot change it."
              },
              variant: "warning")
          ])
      end
      private_class_method :selected_exploration

      def input_card(id, title, source, received)
        node(id, "DrillDownCard",
          slt("listitem", "observation", "stack", "one", "inspect"),
          { "title" => title, "excerpt" => "Source: #{source}. #{received}. An input is not an interpretation." },
          children: [ctrl("#{id}-explore", "Explore", "explore", "inspect")])
      end
      private_class_method :input_card

      def ctrl(id, label, action, behavior)
        node(id, "ActionControl",
          slt("button", "action", "inline", "one", behavior),
          { "label" => label, "action" => action })
      end
      private_class_method :ctrl

      # tone is a declared StatusBadge field. The component runtime honours
      # only "warning" and "danger" (applyState), which is exactly the
      # granularity a steward needs: is this fine, does it need attention, or
      # is it blocked. Absent tone means neutral.
      #
      # This is request-time PROJECTION, not stored status. The PageShell note
      # already states that eligibility and highlight are request-time display
      # and never board state. A band view may be coloured; the ICON carries
      # the meaning so colour never carries it alone.
      def badge(id, label, tone: nil)
        props = { "label" => label, "sourceCid" => "cid:projection:translation-board" }
        props["tone"] = tone if tone
        node(id, "StatusBadge",
          slt("status", "observation", "inline", "one", "static"),
          props)
      end
      private_class_method :badge
    end
  end
end

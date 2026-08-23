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
        open_computation(doc, COMPUTATION_EXPLORE, mapping_prose)
      end

      # The board with the semantic editor OPEN.
      #
      # A <dialog> is display:none until opened, which is what the board itself
      # wants. The open state is a different PROJECTION, not a runtime toggle:
      # the node id names the slot, so a document carrying brd-frame-editor-open
      # is a board whose editor is open -- with its own digests and cids, which
      # keeps what was edited exactly as traceable as what was read.
      # A modal is OPEN in a projection, not by a runtime toggle. A <dialog>
      # without `open` is display:none, so the board itself carries both dialogs
      # closed; these two documents are the same board with one of them showing.
      # Each gets its own digest, which is what keeps an edit or a distinction
      # exactly as traceable as a read.
      #
      # Exactly one may be open. A modal carries EITHER a distinction or prose.
      def translation_board_editor_document
        open_dialog("brd-frame-editor")
      end

      def translation_board_distinction_document
        open_dialog("brd-distinction")
      end

      # THE TRACE, from pressing ! on an input.
      #
      # X1 is the origin and reads FULL. Everything the frame reaches from it
      # reads HALF: the references its spans map to, the meanings those
      # references carry, and the clarifications of those meanings. Nothing else
      # is marked, which is the third state and the reason the affordance is a
      # three-way one.
      #
      # The chain is the model's proposal, not a stored edge. That is why the
      # computation modal opens with it: what arrives is a derivation, and a
      # derivation that arrives silently gets read as a finding.
      TRACE_ORIGIN = "brd-in-email"

      TRACE_IMPLICATED = %w[
        brd-or-evacuate brd-or-volunteers
        brd-mn-evac brd-mn-protective
        brd-cl-duty brd-cl-families brd-cl-formalize
      ].freeze

      def translation_board_trace_document
        doc = Marshal.load(Marshal.dump(translation_board_document))
        doc["projectionKind"] = "inspect"
        doc["predecessorDigest"] = "sha256:board-predecessor"
        doc["predecessorCorrelation"] = "corr-board-pred"
        doc["inspectOriginNodeId"] = TRACE_ORIGIN
        stamp_trace(doc)
        open_computation(doc, COMPUTATION_TRACE)
      end

      # Both ! and ? open the SAME modal. Only the sentence differs, and only ?
      # appends the reading -- because it is the same derivation either way, and
      # pretending otherwise would suggest two computations where there is one.
      def open_computation(doc, sentence, extra = [])
        walk = lambda { |n|
          next unless n.is_a?(Hash)
          if n["nodeId"] == "brd-computation"
            n["nodeId"] = "brd-computation-open"
            n["children"] = Array(n["children"]) + extra
          end
          if n["nodeId"] == "brd-computation-sentence"
            n["props"]["valueJson"]["title"] = sentence
            n["props"]["valueJson"]["text"] = sentence
          end
          Array(n["children"]).each { |c| walk.call(c) }
        }
        walk.call(doc["root"])
        doc
      end
      private_class_method :open_computation

      def stamp_trace(doc)
        marks = { TRACE_ORIGIN => "selected" }
        TRACE_IMPLICATED.each { |id| marks[id] = "related" }
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
      private_class_method :stamp_trace

      # ? MAPS THE SAME WAY AND SAYS WHY.
      #
      # The difference between ! and ? is not what they compute -- it is the
      # same derivation -- but what they hand back. ! shows you the shape of the
      # mapping. ? shows the shape AND the reading behind it, span by span,
      # because the question "what does this touch" and the question "why does
      # it touch that" are answered by the same work and wanted at different
      # moments.
      def mapping_prose
        [
          ["brd-map-1", "The phrase 'clear the area' was read as a direction rather than advice, " \
                        "which is what maps it to X1:Y1:R1 rather than leaving it unreferenced."],
          ["brd-map-2", "'As soon as practical' was left unmapped. Under Harbour operations it " \
                        "qualifies a duty without naming one, and a span that qualifies nothing " \
                        "settles nothing."],
          ["brd-map-3", "Y1:M2 is implicated but not supported: the reference reaches it, and the " \
                        "clarifications it needs are the two below it."]
        ].map do |id, text|
          node(id, "SemanticText",
            slt("article", "observation", "stack", "one", "static"),
            { "title" => text, "text" => text, "level" => "block" })
        end
      end
      private_class_method :mapping_prose

      def translation_board_context_document
        open_dialog("brd-context-dialog")
      end

      def open_dialog(node_id)
        doc = Marshal.load(Marshal.dump(translation_board_document))
        rename = lambda { |n|
          next unless n.is_a?(Hash)
          n["nodeId"] = "#{node_id}-open" if n["nodeId"] == node_id
          Array(n["children"]).each { |c| rename.call(c) }
        }
        rename.call(doc["root"])
        doc
      end
      private_class_method :open_dialog

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
                slt("heading", "context", "inline", "one", "static"),
                { "text" => "Translation Board", "title" => "Translation Board", "level" => "page" },
                children: [
                  ctrl("brd-context", "?", "about-board", "navigate",
                    navigates_to: "board-context.html",
                    title: "About this board")
                ]),
              node("brd-filterbar-1", "FilterBar",
                slt("form", "navigation", "inline", "many", "filter"),
                { "filters" => "source,referent,evidence,suggestions" }),
              node("brd-board-1", "PanelFrame",
                slt("landmark", "context", "grid", "three", "static", responsive: "p9.r1.grid.board-3"),
                { "title" => "Frame projection", "panelKey" => "translation-board" },
                children: [
                  column_input,
                  column_frame,
                  column_translation
                ]),
              selected_exploration,
              frame_editor_dialog,
              distinction_dialog,
              context_dialog,
              computation_dialog
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
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Frame", "panelKey" => "frame" },
          children: [
            plus("brd-frame", "frame"),
            frame_choices,
            column_meaning,
            column_clarification
          ])
      end
      private_class_method :column_frame

      # The operative Frame, chosen. behaviorKind is `navigate` rather than
      # `filter`: choosing a Frame does not narrow a set, it re-roots the whole
      # Translation -- different spans, References, Meanings and carries.
      #
      # A bar of frames, not a pulldown. A pulldown hides the alternatives
      # behind a click, and the alternatives are the point: the reason to look
      # at this board is that the SAME input reasons differently under a
      # different frame.
      def frame_choices
        node("brd-frame-choices", "PanelFrame",
          slt("input", "navigation", "stack", "three", "static"),
          { "title" => "Frames", "panelKey" => "frame-choices" },
          children: [
            frame_choice("brd-frame-operative", "Y1", "Y1 — Harbour operations", operative: true),
            frame_choice("brd-frame-alt-1", "Y2", "Y2 — Community liaison"),
            frame_choice("brd-frame-alt-2", "Y3", "Y3 — Regulatory duty")
          ])
      end
      private_class_method :frame_choices

      # A frame is a card like any other: it is chosen, and it can be removed.
      # The operative one is named by NODE ID rather than by which frame it
      # happens to be -- this is a request-time projection, so change the frame
      # and whichever one is in force occupies that slot.
      #
      # The check is CONTENT, not decoration. A fill alone leaves a colour-blind
      # reader guessing which frame their Translation came from, and that is
      # exactly the thing they must not have to guess.
      def frame_choice(node_id, canonical_id, label, operative: false)
        node(node_id, "PanelFrame",
          slt("input", "navigation", "inline", "many", "static"),
          { "title" => label, "canonicalId" => canonical_id, "panelKey" => "frame-choice" },
          children: [
            ctrl("#{node_id}-select",
              operative ? "✓ #{label}" : label,
              "select-frame", "navigate",
              title: operative ? "Operative frame: #{label}" : "Read this input through #{label}")
          ] + rail(node_id, canonical_id))
      end
      private_class_method :frame_choice

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


      # The check is CONTENT, not decoration. A background colour alone leaves a
      # colour-blind reader guessing which frame their Translation came from,
      # and that is exactly the thing they must not have to guess.

      # Frames are the user's own. They are constructed, kept, and retired by
      # the person reasoning -- so add and remove sit beside the frames
      # themselves, not in a settings screen somewhere else.


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
      # ------------------------------------------------- the semantic editor
      # Prose mode. The editor itself lives in mmg-semantic-editor and is
      # headless: it knows canonical ids, disclosure tiers and prose, and
      # nothing about this board.
      #
      # Each block is one record. Its heading is a LINK carrying the canonical
      # id, so the id never has to appear as [Y1:M1] clutter in front of a
      # sentence a person is trying to read -- and following it lands exactly
      # where Explore on the matching card lands. The id is in the href, which
      # is where a machine can read it and a reader does not have to.
      # ------------------------------------------------- the semantic editor
      # Prose mode. The editor itself lives in mmg-semantic-editor and is
      # headless: it knows canonical ids, disclosure tiers and prose, and
      # nothing about this board.
      #
      # TWO VIEWS, DIFF BY DEFAULT. + and - already mean add and remove on this
      # board; here they are the record of the same acts, already performed. The
      # alternative -- showing the resulting text and trusting the reader to
      # notice what moved -- hides exactly the thing that matters when one
      # paragraph is about to land as several simultaneous writes.
      #
      # Both views are in the projection and one is shown. Which one is a
      # consumer setting; the seam is here and no surface offers the switch yet.
      def frame_editor_dialog
        node("brd-frame-editor", "PanelFrame",
          slt("dialog", "action", "overlay", "three", "collect_effect"),
          { "title" => "Y1 — Harbour operations", "panelKey" => "frame-editor" },
          children: [
            editor_diff_view,
            editor_prose_view,
            ctrl("brd-editor-apply", "Apply", "apply-frame-edits", "confirm")
          ])
      end
      private_class_method :frame_editor_dialog

      def editor_diff_view
        node("brd-editor-diff", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "1 added, 1 changed, 1 removed", "panelKey" => "editor-diff" },
          children: [
            diff_line("brd-diff-1", " ", "Harbour operations"),
            diff_line("brd-diff-2", " ", "Frames what we are here to look after."),
            diff_line("brd-diff-3", " ", "  Berth allocation is a duty of care"),
            diff_line("brd-diff-4", "-", "  A berth is not a slot on a chart."),
            diff_line("brd-diff-5", "+", "  A berth decides whose livelihood is interrupted."),
            diff_line("brd-diff-6", " ", "    Already alongside is not thereby entitled to stay."),
            diff_line("brd-diff-7", "-", "  Tide windows bind everyone equally"),
            diff_line("brd-diff-8", "-", "  No vessel is owed a window another loses."),
            diff_line("brd-diff-9", "+", "  Weather is not a party to the agreement"),
            diff_line("brd-diff-10", "+", "  A closed harbour binds the harbour, not the skipper.")
          ])
      end
      private_class_method :editor_diff_view

      # The marker is the signal and the colour is the enhancement -- the same
      # rule the eligibility bands follow: colour never carries meaning alone.
      # `outcome` and `drift` are the closest members of the closed contentRole
      # vocabulary -- something that now is, and something that moved away --
      # chosen so the marker survives into the DOM without inventing an
      # attribute for it.
      def diff_line(node_id, marker, text)
        role = case marker
               when "+" then "outcome"
               when "-" then "drift"
               else "context"
               end
        node(node_id, "SemanticText",
          slt("listitem", role, "stack", "one", "static"),
          { "title" => "#{marker}#{text}", "text" => "#{marker}#{text}", "level" => "block" })
      end
      private_class_method :diff_line

      # The other view: the text as it will read once applied. Each heading is a
      # LINK carrying the canonical id, so the id never appears as [Y1:M1]
      # clutter in front of a sentence -- and following it lands exactly where
      # Explore on the matching card lands.
      def editor_prose_view
        node("brd-editor-prose", "PanelFrame",
          slt("article", "context", "stack", "many", "collect_effect"),
          { "title" => "As it will read", "panelKey" => "frame-prose" },
          children: frame_prose_blocks)
      end
      private_class_method :editor_prose_view

      def frame_prose_blocks
        [
          prose_block("brd-prose-y1", "Y1", "Harbour operations",
            "Frames what we are here to look after, and what counts as looking after it."),
          prose_block("brd-prose-y1m1", "Y1:M1", "Berth allocation is a duty of care",
            "A berth is not a slot on a chart. Who gets one, and when, decides whose livelihood is interrupted."),
          prose_block("brd-prose-y1m1c1", "Y1:M1:C1",
            "A vessel already alongside is not thereby entitled to stay.", nil, tier: "sidebar"),
          prose_block("brd-prose-y1m2", "Y1:M2", "Tide windows bind everyone equally",
            "No vessel is owed a window another loses.")
        ]
      end
      private_class_method :frame_prose_blocks

      # A block is a heading and, where there is one, a paragraph. The heading
      # orients the paragraph; nothing else is said about what the block is or
      # how to edit it, because a person writing prose does not need a caption
      # explaining that they are writing prose.
      #
      # `disclosureTier` travels with the block. A clarification is held in the
      # sidebar on the board, but it is here in the text, because the text is
      # the whole record and a tier is about where something is SHOWN.
      def prose_block(node_id, canonical_id, heading, body, tier: "immediate")
        kids = [
          ctrl("#{node_id}-link", heading, "explore", "navigate",
            navigates_to: explore_href(canonical_id))
        ]
        if body
          kids << node("#{node_id}-body", "SemanticText",
            slt("article", "context", "stack", "one", "static"),
            { "title" => body, "text" => body, "level" => "block" })
        end

        node(node_id, "PanelFrame",
          slt("article", "context", "stack", body ? "two" : "one", "static"),
          { "title" => heading, "canonicalId" => canonical_id, "disclosureTier" => tier },
          children: kids)
      end
      private_class_method :prose_block

      # What the board is, behind the ? on its title.
      #
      # This was a ContextBanner saying the same sentence to every reader on
      # every visit. It is explanation ABOUT the board rather than content OF
      # it -- the same class of text as the build note -- and a sentence a
      # reader has already understood is a sentence they scroll past every time
      # after.
      #
      # A modal rather than an inline disclosure, because this belongs to the
      # same family as the editor and the distinction: open is a PROJECTION with
      # its own digest, not a runtime toggle.
      def context_dialog
        node("brd-context-dialog", "PanelFrame",
          slt("dialog", "context", "overlay", "two", "inspect"),
          { "title" => "About this board",
            "panelKey" => "context",
            "freshness" => "live",
            "policy" => "canonical-only" },
          children: [
            node("brd-context-derived", "SemanticText",
              slt("article", "context", "stack", "one", "static"),
              { "title" => "Eligibility is derived at request time. Board position does not change it.",
                "text" => "Eligibility is derived at request time. Board position does not change it.",
                "level" => "block" }),
            node("brd-context-policy", "SemanticText",
              slt("article", "provenance", "stack", "one", "static"),
              { "title" => "Live, canonical only. Highlight and suggestion presence are request-time display, never stored board status.",
                "text" => "Live, canonical only. Highlight and suggestion presence are request-time display, never stored board status.",
                "level" => "block" })
          ])
      end
      private_class_method :context_dialog

      # ---------------------------------------------------------- distinction
      # The other thing a modal can carry.
      #
      # Explore is the only affordance on a card, which means the card face no
      # longer says which act is available. That was the point: you cannot
      # choose between Continue clarification and Enter the productive-refusal
      # wall until you have seen WHY the meaning is not eligible. So the grounds
      # come first, and the acts follow them.
      #
      # A modal carries EITHER a distinction or prose, never both. They are
      # different kinds of act -- one settles what this is, the other rewrites
      # what the frame says -- and offering them together would invite the
      # reader to do the second while thinking about the first.
      def distinction_dialog
        node("brd-distinction", "PanelFrame",
          slt("dialog", "evidence", "overlay", "three", "inspect"),
          { "title" => "Protective action may mean staying or leaving",
            "panelKey" => "distinction",
            "canonicalId" => "Y1:M2" },
          children: [
            node("brd-dist-evidence", "EvidencePanel",
              slt("article", "evidence", "stack", "one", "inspect"),
              {
                "title" => "Why this is not eligible",
                "heading" => "Why this is not eligible",
                "body" => "Two criteria fail and a dispute is open, so eligibility is not derivable now.",
                "references" => [
                  "passing - referent identifiable",
                  "passing - core meaning clear",
                  "failing - agreement evidence",
                  "failing - binding intention",
                  "failing - dispute open"
                ],
                "conclusion" => "Eligibility is derived from evidence and criteria. Board position cannot change it.",
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
            node("brd-dist-acts", "PanelFrame",
              slt("input", "action", "inline", "three", "static"),
              { "title" => "What can be done from here", "panelKey" => "distinction-acts" },
              children: [
                ctrl("brd-dist-inspect", "Inspect eligibility", "inspect-eligibility", "inspect"),
                ctrl("brd-dist-continue", "Continue clarification", "continue-clarification", "navigate"),
                ctrl("brd-dist-wall", "Enter productive-refusal wall", "enter-productive-refusal-wall", "navigate")
              ]),
            node("brd-dist-refusal", "RefusalNotice",
              slt("alert", "refusal", "stack", "one", "acknowledge"),
              {
                "operation" => "claim-plan-eligible",
                "reason" => "meaning.actability-insufficient",
                "failedCriteria" => %w[agreement-not-evidenced-for-planning binding-not-verified dispute-open],
                "evidenceRefs" => ["cid:projection:eligibility:protective-action", "https://ex/dispute/evacuate"],
                "remediation" => "Enter the productive-refusal wall with this meaning, eligibility explanation, and dispute material. Do not drag the card into Clarification or Stewardship.",
                "overridePolicy" => "none",
                "heading" => "Accountable planning or effect cannot be claimed now",
                "title" => "Accountable planning or effect cannot be claimed now"
              },
              variant: "warning")
          ])
      end
      private_class_method :distinction_dialog

      # The prose format is deliberately plain -- not markdown, not YAML. It is
      # the smallest thing that survives a person retyping it by hand.

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

      # Canonical ids make the board addressable by the same vocabulary the
      # semantic editor edits: Xn inputs, Yn:Mn meanings, Yn:Mn:Cn
      # clarifications, Xn:Yn:Rn references, Xn:Yn:Zn stewardship carries. A
      # card and a line of prose that name the same id are the same thing seen
      # twice, and Explore takes you to the same place from either.

      def column_inputs
        node("brd-col-inputs", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Inputs", "panelKey" => "inputs" },
          children: [
            plus("brd-in", "input"),
            node("brd-in-metric", "MetricStrip",
              slt("status", "observation", "inline", "many", "static"),
              { "received" => 3, "inActiveExploration" => 0 }),
            node("brd-in-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "inputs" },
              children: [
                input_card("brd-in-email", "X1", "Email — Harbour alert wording concerns"),
                input_card("brd-in-research", "X2", "Research — Hazard terminology review"),
                input_card("brd-in-chat", "X3", "Chat — Duty officer feedback")
              ])
          ])
      end
      private_class_method :column_inputs

      def column_orientation
        node("brd-col-orientation", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Reference", "panelKey" => "orientation" },
          children: [
            plus("brd-or", "reference"),
            node("brd-or-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "orientation" },
              children: [
                card("brd-or-evacuate", "X1:Y1:R1",
                  "Residents hear 'evacuate' as immediate removal",
                  variant: "emphasis",
                  extra: { "provenance" => "cid:interview:04" },
                  before: [badge("brd-or-evacuate-badge", "Selected — active exploration")]),
                card("brd-or-volunteers", "X1:Y1:R2",
                  "Volunteer translators need local context",
                  extra: { "provenance" => "cid:interview:05" })
              ])
          ])
      end
      private_class_method :column_orientation

      def column_meaning
        node("brd-col-meaning", "PanelFrame",
          slt("article", "context", "stack", "many", "static"),
          { "title" => "Meaning", "panelKey" => "meaning" },
          children: [
            plus("brd-mn", "meaning"),
            node("brd-mn-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "meaning-accepted" },
              children: [
                card("brd-mn-evac", "Y1:M1",
                  "Evacuation notice is an immediate direction to leave",
                  extra: { "displayBandLabel" => "Effect-eligible" },
                  before: [badge("brd-mn-evac-badge", "Eligibility: effect-eligible")]),
                card("brd-mn-protective", "Y1:M2",
                  "Protective action may mean staying or leaving",
                  extra: { "displayBandLabel" => "Explorable", "disputeOpen" => true },
                  before: [badge("brd-mn-protective-badge",
                                 "Eligibility: not eligible — clarification incomplete", tone: "warning")])
              ]),
            node("brd-mn-suggest-heading", "SemanticText",
              slt("heading", "context", "stack", "one", "static"),
              { "title" => "Machine suggestions — unaccepted",
                "text" => "Machine suggestions — unaccepted", "level" => "region" }),
            node("brd-mn-suggest-list", "DataList",
              slt("list", "observation", "stack", "many", "static"),
              { "listKey" => "meaning-suggestions" },
              children: [
                card("brd-mn-suggest", "Y1:M3",
                  "Candidate: protective action as locally specified response",
                  extra: { "suggestion" => true })
              ])
          ])
      end
      private_class_method :column_meaning

      def column_clarification
        node("brd-col-clarification", "PanelFrame",
          slt("article", "evidence", "stack", "many", "static"),
          { "title" => "Clarification", "panelKey" => "clarification" },
          children: [
            plus("brd-cl", "clarification"),
            node("brd-cl-list", "DataList",
              slt("list", "evidence", "stack", "many", "static"),
              { "listKey" => "clarification" },
              children: [
                card("brd-cl-duty", "Y1:M1:C1",
                  "Duty officer wording agreement signed",
                  kind: "evidence",
                  before: [badge("brd-cl-duty-badge", "Evidence complete")]),
                card("brd-cl-families", "Y1:M2:C1",
                  "Test families' interpretation of protective action",
                  kind: "evidence",
                  before: [badge("brd-cl-families-badge", "Evidence missing", tone: "danger")]),
                card("brd-cl-formalize", "Y1:M2:C2",
                  "Formalize local terminology reference",
                  kind: "evidence")
              ])
          ])
      end
      private_class_method :column_clarification

      def column_stewardship
        node("brd-col-stewardship", "PanelFrame",
          slt("article", "authorization", "stack", "many", "static"),
          { "title" => "Stewardship", "panelKey" => "stewardship" },
          children: [
            plus("brd-st", "carry"),
            node("brd-st-suggest-heading", "SemanticText",
              slt("heading", "context", "stack", "one", "static"),
              { "title" => "Machine suggestions — unaccepted",
                "text" => "Machine suggestions — unaccepted", "level" => "region" }),
            node("brd-st-suggest-list", "DataList",
              slt("list", "authorization", "stack", "many", "static"),
              { "listKey" => "stewardship-suggestions" },
              children: [
                card("brd-st-draft", "X1:Y1:Z1",
                  "Draft bilingual alert guidance",
                  kind: "authorization", extra: { "suggestion" => true })
              ]),
            node("brd-st-list", "DataList",
              slt("list", "authorization", "stack", "many", "static"),
              { "listKey" => "stewardship-accepted" },
              children: [
                card("brd-st-authority", "X1:Y1:Z2",
                  "Authority sign-off required",
                  kind: "authorization"),
                card("brd-st-refusal", "X1:Y1:Z3",
                  "Refused stewardship carry",
                  kind: "refusal", variant: "warning",
                  before: [
                    node("brd-st-refusal-notice", "RefusalNotice",
                      slt("alert", "refusal", "stack", "one", "acknowledge"),
                      {
                        "operation" => "issue-unverified-action-language",
                        "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
                        "failedCriteria" => %w[authorization-reference-missing],
                        "evidenceRefs" => ["cid:page:board-stewardship", "https://ex/authority/harbour-master"],
                        "remediation" => "Obtain Harbour Master sign-off, then re-enter the stewardship flow. Do not treat this card as Done.",
                        "overridePolicy" => "none",
                        "heading" => "Refusal: Do not issue unverified action language",
                        "title" => "Refusal: Do not issue unverified action language"
                      },
                      variant: "warning")
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
            node("brd-uc07-refusal", "RefusalNotice",
              slt("alert", "refusal", "stack", "one", "acknowledge"),
              {
                "operation" => "claim-plan-eligible",
                "reason" => "meaning.actability-insufficient",
                "failedCriteria" => %w[agreement-not-evidenced-for-planning binding-not-verified dispute-open],
                "evidenceRefs" => ["cid:projection:eligibility:protective-action", "https://ex/dispute/evacuate"],
                "remediation" => "Enter the productive-refusal wall with this meaning, eligibility explanation, and dispute material. Do not drag the card into Clarification or Stewardship.",
                "overridePolicy" => "none",
                "heading" => "Accountable planning or effect cannot be claimed now",
                "title" => "Accountable planning or effect cannot be claimed now"
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
                "heading" => "Eligibility is derived from evidence and criteria; board position cannot change it.",
                "title" => "Eligibility is derived from evidence and criteria; board position cannot change it."
              },
              variant: "warning")
          ])
      end
      private_class_method :selected_exploration


      # EXPLORE IS THE ONLY THING A CARD OFFERS.
      #
      # Cards used to advertise their own verbs -- Inspect eligibility, Continue
      # clarification, Consider, Decline, View proposal, Inspect refusal. Seven
      # different words for "look at this", each one a small decision the reader
      # had to make before they had seen anything. The card face is the wrong
      # place for that: you cannot sensibly choose between acts you have not yet
      # been shown the grounds for.
      #
      # So every card offers Explore and nothing else, and the DISTINCTION --
      # which act is actually available here, and why -- is made in the modal,
      # after the grounds are on screen.

      # Where Explore goes. The inspect projection IS the exploration result --
      # a new attested ACIA with its own digest, not an annotation of the board.
      # The canonical id travels in the query so the destination knows what was
      # explored, and so the link is copyable and bookmarkable like any other.

      # + AND - ARE ONE CONVENTION.
      #
      # + brings something into being, - takes it away, at every level and in
      # every column: a frame, a reference, a meaning, a clarification, a carry.
      # The same pair is what the semantic editor uses to show an edit, so a
      # person who has learned the buttons has already learned the diff.
      #
      # + sits beside the heading of the thing it adds to, because that is what
      # says WHAT it adds. - sits on the card, because that is what says WHICH.
      # There is no tools row: a row of verbs away from the things they act on
      # is how "+ Frame" and "Write in prose" ended up as two buttons for one
      # act.
      def plus(id, noun)
        ctrl("#{id}-add", "+", "add-#{noun}", "navigate",
          navigates_to: compose_href(noun),
          title: "Add a #{noun}")
      end
      private_class_method :plus

      def minus(id, noun)
        ctrl("#{id}-remove", "−", "remove-#{noun}", "confirm",
          title: "Remove this #{noun}")
      end
      private_class_method :minus

      # + opens the editor with nothing written yet. "Write in prose" was a
      # second button for the same act -- there is no way to add a frame that is
      # not writing one, so the affordance that adds it is the affordance that
      # opens the place you write it.
      def compose_href(noun)
        "board-editor.html?compose=#{noun}"
      end
      private_class_method :compose_href

      # Explore is a ? now, not a word.
      #
      # It joins + and - as the third mark of the same family: + brings
      # something into being, - takes it away, ? asks what this is. That is what
      # Explore has always meant -- go and look -- and a glyph says it in the
      # space a word was taking on every card.
      #
      # The word survives where it does the work: `title` becomes the aria
      # label, so a screen reader hears "Explore this meaning" rather than a
      # question mark.
      def explore(id, canonical_id)
        ctrl("#{id}-explore", "?", "explore", "navigate",
          navigates_to: explore_href(canonical_id),
          title: "Explore this #{noun_for(canonical_id)}")
      end
      private_class_method :explore

      # Where Explore goes. The inspect projection IS the exploration result --
      # a new attested ACIA with its own digest, not an annotation of the board.
      # The canonical id travels in the query so the destination knows what was
      # explored, and so the link is copyable and bookmarkable like any other.
      def explore_href(canonical_id)
        "board-inspect.html?explore=#{canonical_id.to_s.gsub(':', '%3A')}"
      end
      private_class_method :explore_href

      def ctrl(id, label, action, behavior, navigates_to: nil, title: nil)
        props = { "label" => label, "action" => action, "title" => title || label }
        props["navigatesTo"] = navigates_to if navigates_to
        node(id, "ActionControl",
          slt("button", "action", "inline", "one", behavior),
          props)
      end
      private_class_method :ctrl

      # ! IS AN ASSERTION, AND A THREE-WAY ONE.
      #
      # + adds, - removes, ? asks, ! says THIS ONE -- and then shows everything
      # it touches. Three states, because a trace has three kinds of
      # participant:
      #
      #   off    not in the trace at all
      #   full   the thing you pressed -- the origin
      #   half   reached THROUGH the origin: the references its spans map to,
      #          the meanings those references carry, and the clarifications of
      #          those meanings
      #
      # Half is the whole point. A two-state highlight would say "these are all
      # involved" and flatten the difference between what you CHOSE and what
      # FOLLOWED from it -- which is exactly the difference a person needs when
      # they are deciding whether a mapping is one they will stand behind.
      #
      # It reuses presentationState, which already means request-time display
      # and is refused on a stored document. A trace is a derivation, never
      # board state: the same rule that keeps eligibility out of board position
      # keeps a highlight out of the record.
      def trace(id, canonical_id)
        noun = noun_for(canonical_id)
        ctrl("#{id}-trace", "!", "trace-#{noun}", "inspect",
          navigates_to: trace_href(canonical_id),
          title: "Trace what this #{noun} touches")
      end
      private_class_method :trace

      def trace_href(canonical_id)
        "board-trace.html?trace=#{canonical_id.to_s.gsub(':', '%3A')}"
      end
      private_class_method :trace_href

      # The rail, top to bottom: assert, ask, remove. The two that only look
      # come first and the one that destroys comes last, so the destructive
      # control is never the thing your hand lands on by momentum.
      def rail(id, canonical_id)
        [trace(id, canonical_id), explore(id, canonical_id), minus(id, noun_for(canonical_id))]
      end
      private_class_method :rail

      def card(id, canonical_id, title, kind: "observation", variant: "default", extra: {}, before: [])
        props = { "title" => title, "canonicalId" => canonical_id }.merge(extra)
        node(id, "DrillDownCard",
          slt("listitem", kind, "stack", "one", "inspect"),
          props,
          variant: variant,
          children: before + rail(id, canonical_id))
      end
      private_class_method :card

      # WHAT THE MACHINE IS ABOUT TO DO, IN ONE SENTENCE.
      #
      # Both ! and ? hand the work to a model: it reads the input under the
      # frame and proposes which spans map to which references, and what those
      # references implicate. That is a DERIVATION, not a lookup, and a person
      # should be told what was asked on their behalf before they read the
      # answer -- otherwise a proposal arrives looking like a finding.
      #
      # One sentence, naming the input and the frame. Anything longer becomes
      # the kind of preamble people learn to dismiss, and then the one thing it
      # had to say goes unread.
      def computation_dialog
        node("brd-computation", "PanelFrame",
          slt("dialog", "observation", "overlay", "many", "inspect"),
          { "title" => "Deriving", "panelKey" => "computation" },
          children: [
            node("brd-computation-sentence", "SemanticText",
              slt("article", "observation", "stack", "one", "static"),
              { "title" => COMPUTATION_TRACE, "text" => COMPUTATION_TRACE, "level" => "block" })
          ])
      end
      private_class_method :computation_dialog

      COMPUTATION_TRACE =
        "Reading Input X1 under Frame Y1 to propose which spans map to which references, " \
        "and which meanings and clarifications those references implicate."

      COMPUTATION_EXPLORE =
        "Reading Input X1 under Frame Y1 to propose that mapping, and to say in prose why " \
        "each span was read the way it was."

      def input_card(id, canonical_id, title)
        card(id, canonical_id, title)
      end
      private_class_method :input_card

      # What a minus removes follows from the id, so the two cannot drift apart.
      # A card whose id says Y1:M1:C1 removes a clarification whatever column it
      # is drawn in.
      def noun_for(canonical_id)
        case canonical_id.to_s
        when /\AX\d+\z/ then "input"
        when /\AY\d+\z/ then "frame"
        when /:M\d+:C\d+\z/ then "clarification"
        when /:M\d+\z/ then "meaning"
        when /:R\d+\z/ then "reference"
        when /:Z\d+\z/ then "carry"
        else "card"
        end
      end
      private_class_method :noun_for

      # A card: a heading, whatever badge the projection derived, Explore, and
      # the minus that removes it. Explore is still the only way to LOOK at a
      # card; minus is not another way of looking, it is the structural half of
      # the pair whose other half sits beside the heading above.


      # A card: a heading, whatever badge the projection derived, and Explore.
      # Nothing else. The excerpt that used to sit here was explanation, and
      # explanation belongs where the reader asked for it.

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

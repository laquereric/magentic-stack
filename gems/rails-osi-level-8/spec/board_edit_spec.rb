# frozen_string_literal: true

require "spec_helper"

# ✎ OPENS THE SEMANTIC EDITOR ON A CARD.
#
# The editor dialog was in this document from the day the board was built and
# nothing opened it: a modal with no opener. These hold the wiring, and one
# property matters more than the rest -- the box opens with the text already in
# it. An empty box called an edit invites a person to retype from memory what
# the board is showing three inches away, and whatever they do not retype reads
# as a deletion.
RSpec.describe "Profile 9 board — edit projection" do
  P9E = RailsOsiLevel8::Profile9::Acia

  def each_node(node, &blk)
    return unless node.is_a?(Hash)

    blk.call(node)
    Array(node["children"]).each { |c| each_node(c, &blk) }
  end

  def find_node(doc, id)
    hit = nil
    each_node(doc["root"]) { |n| hit ||= n if n["nodeId"] == id }
    hit
  end

  # Scoped to the open editor ON PURPOSE. Several dialogs on this board carry a
  # frame_prose field -- the computation modal has one too -- so a document-wide
  # search finds the last one written rather than the one just opened. That is
  # not hypothetical: it produced a round-trip failure against a document that
  # was in fact correct.
  def prose_in(node)
    hit = nil
    each_node(node) { |n| hit ||= n if n.dig("props", "valueJson", "name") == "frame_prose" }
    hit&.dig("props", "valueJson", "text")
  end

  describe "the pencil" do
    it "links to the editor projection for the card's own id" do
      doc = P9E.translation_board_document
      pencils = []
      each_node(doc["root"]) do |n|
        next unless n.dig("props", "valueJson", "action").to_s.start_with?("edit-")

        pencils << [n["nodeId"], n.dig("props", "valueJson", "navigatesTo")]
      end

      expect(pencils).not_to be_empty
      pencils.each do |node_id, href|
        expect(href).to match(%r{\Aboard-editor\.html\?edit=}), node_id
      end
      # The id travels escaped, so a meaning's colons survive the URL.
      expect(pencils.map(&:last)).to include("board-editor.html?edit=Y1%3AM1")
    end

    it "is absent where an edit has nowhere to land" do
      # A Translation is derived per request and never stored. Asked of
      # CanonicalId rather than asserted here, because that is where the rule
      # lives -- this checks the board honours it.
      expect(Mmg::SemanticEditor::CanonicalId.target("X1:Y1")[:ok]).to be false

      doc = P9E.translation_board_document
      each_node(doc["root"]) do |n|
        cid = n.dig("props", "valueJson", "canonicalId").to_s
        next if cid.empty?
        next if Mmg::SemanticEditor::CanonicalId.target(cid)[:ok]

        offered = Array(n["children"]).filter_map { |k| k.dig("props", "valueJson", "action") }
        expect(offered).not_to include(a_string_starting_with("edit-")), "#{cid} offered #{offered.inspect}"
      end
    end
  end

  describe "the editor projection" do
    it "opens on the card that was pressed, not on Y1" do
      # The defect ?compose= had: the parameter went nowhere and the same page
      # came back regardless, so pressing + on one thing handed you an edit to
      # another. Being handed someone else's card is worse than a dead link,
      # because it looks like it worked.
      open = find_node(P9E.translation_board_editor_document(edit: "Y1:M2"), "brd-frame-editor-open")

      expect(open.dig("props", "valueJson", "title")).to start_with("Y1:M2 — ")
      expect(open.dig("props", "valueJson", "panelKey")).to eq("edit-meaning")
    end

    it "opens the box with the frame's prose already in it" do
      open = find_node(P9E.translation_board_editor_document(edit: "Y1"), "brd-frame-editor-open")
      text = prose_in(open)

      expect(text).to include("[Y1] Harbour operations")
      expect(text).to include("[Y1:M1] ")
      expect(text).to include("[Y1:M1:C1] ")
    end

    it "does not stutter the id when the card's title already carries one" do
      # The frame card reads "Y1 — Harbour operations" and a meaning card does
      # not carry its id at all, so using titles raw produced "Y1 — Y1 —
      # Harbour operations" and prose opening "[Y1] Y1 — Harbour operations".
      open = find_node(P9E.translation_board_editor_document(edit: "Y1"), "brd-frame-editor-open")

      expect(open.dig("props", "valueJson", "title")).to eq("Y1 — Harbour operations")
      expect(prose_in(open)).to start_with("[Y1] Harbour operations")
    end

    it "gives a meaning the WHOLE frame's prose, not one orphaned line" do
      # Prose mode renders a Frame, its Meanings and their Clarifications as one
      # editable text: a person writing about a Frame is editing several records
      # at once and should not have to hold those boundaries in their head.
      text = prose_in(find_node(P9E.translation_board_editor_document(edit: "Y1:M1"), "brd-frame-editor-open"))

      expect(text).to eq(
        prose_in(find_node(P9E.translation_board_editor_document(edit: "Y1"), "brd-frame-editor-open"))
      )
    end

    it "opens a box whose contents parse back to the ids they came from" do
      # The round trip is the whole reason the format is what it is. If what the
      # box opens with cannot be read back, every edit is a new record.
      text = prose_in(find_node(P9E.translation_board_editor_document(edit: "Y1"), "brd-frame-editor-open"))
      back = Mmg::SemanticEditor::Prose.parse(text)

      expect(back[:ok]).to be(true), "#{back[:reason]}: #{back[:because]}"
      expect(back[:blocks].map { |b| b[:id] }).to include("Y1", "Y1:M1", "Y1:M1:C1", "Y1:M2")
    end

    it "runs Edit then Submit, and not the four steps that never happened" do
      open = find_node(P9E.translation_board_editor_document(edit: "Y1"), "brd-frame-editor-open")
      stages = []
      each_node(open) { |n| stages << n.dig("props", "valueJson", "title") if n["nodeId"].to_s.include?("-lc-") }

      # A person rewriting a frame by hand captures nothing and asks no model.
      # Showing those four greyed would promise steps that are never coming.
      expect(stages.compact).to eq(["1. Edit", "2. Submit"])
    end

    it "leaves the box empty when no card was named" do
      # board-editor.html with no ?edit= and no ?compose= still OPENS the editor
      # -- that is what this projection has always been, and the dialog is
      # renamed to -open whether or not anything filled it. What must not happen
      # is prefilling: a reader arriving without naming a card would find
      # someone else's text waiting and read it as their own draft.
      open = find_node(P9E.translation_board_editor_document, "brd-frame-editor-open")

      expect(open).not_to be_nil
      expect(prose_in(open).to_s).to eq("")
    end
  end

  describe "the rendered page" do
    it "prints a prefilled field's text ONCE, in the box" do
      # `text` on a field is its VALUE. The renderer also emits `text` as body
      # copy when a node has no title, so a prefilled textarea printed the whole
      # prose twice -- grey caps above the box and again inside it. Invisible
      # while every input carried text: "", which is why it survived until ✎
      # opened a box with something in it.
      doc  = P9E.translation_board_editor_document(edit: "Y1")
      res  = RailsOsiLevel8::Profile9::Renderer.render(
        acia: doc, token_set: { "tokens" => { "setRef" => "tokens:ghis@1" } },
        correlation: "cid:page:spec"
      )
      expect(res["ok"]).to be true

      html = res["html"]
      marker = "[Y1:M1:C1] Duty officer wording agreement signed"
      expect(html.scan(marker).length).to eq(1), "prose appears #{html.scan(marker).length} times"
      expect(html).to match(%r{<textarea[^>]*>[^<]*#{Regexp.escape(marker)}}m)
    end
  end

  describe "which ids the projection accepts" do
    it "accepts a card that is on the board and writable" do
      expect(P9E.editable_board_id?("Y1")).to be true
      expect(P9E.editable_board_id?("Y1:M1")).to be true
    end

    it "refuses a derived id and one that is simply not here, differently" do
      # Two ways to fail, and a caller that collapsed them would tell somebody
      # their Translation was missing rather than that it is not a write target.
      expect(Mmg::SemanticEditor::CanonicalId.target("X1:Y1")[:reason]).to eq(:derived_not_writable)
      expect(P9E.editable_board_id?("X1:Y1")).to be false

      expect(Mmg::SemanticEditor::CanonicalId.target("Y99")[:ok]).to be true
      expect(P9E.editable_board_id?("Y99")).to be false
    end

    it "refuses a string that is no canonical id at all" do
      expect(P9E.editable_board_id?("W1788658612807")).to be false
      expect(P9E.editable_board_id?("")).to be false
    end
  end
end

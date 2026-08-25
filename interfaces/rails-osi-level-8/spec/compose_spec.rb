# frozen_string_literal: true

require "spec_helper"

# WHAT THESE COVER THAT THE OTHERS DO NOT.
#
# Every existing spec asserts what a DOCUMENT contains. A renderer that invents
# an element passes all of them -- which is how five textareas nobody declared
# reached a live page: the two that were asked for were present, and nothing
# counted the rest. These assert the RENDERED HTML, and they count.
RSpec.describe "board editor compose" do
  ACIA = RailsOsiLevel8::Profile9::Acia
  RND  = RailsOsiLevel8::Profile9::Renderer
  TOKS = { "tokens" => { "setRef" => "tokens:ghis@1" } }.freeze

  def html_for(compose: nil)
    doc = ACIA.translation_board_editor_document(compose: compose)
    res = RND.render(acia: doc, token_set: TOKS, correlation: "cid:page:spec")
    expect(res["ok"]).to be(true)
    res["html"]
  end

  def dialog(compose: nil)
    doc = ACIA.translation_board_editor_document(compose: compose)
    walk = lambda do |n|
      return n if n.is_a?(Hash) && n["nodeId"] == "brd-frame-editor-open"
      Array(n.is_a?(Hash) ? n["children"] : nil).each do |c|
        hit = walk.call(c)
        return hit if hit
      end
      nil
    end
    walk.call(doc["root"])
  end

  describe "the plain editor" do
    it "renders exactly two textareas -- one per Edit stage, and no others" do
      ids = html_for.scan(/<textarea[^>]*data-ux-node-id="([^"]+)"/).flatten
      expect(ids).to contain_exactly(
        "brd-frame-editor-lc-edit-input-field",
        "brd-computation-lc-edit-input-field"
      )
    end

    it "gives a container that merely PLAYS an input role no field" do
      # brd-frame-choices and each frame card declare semanticRole "input",
      # because choosing a frame is an input. None of them NAMES a field.
      html = html_for
      %w[brd-frame-choices brd-frame-operative brd-frame-alt-1].each do |id|
        expect(html).not_to include(%(data-ux-node-id="#{id}-field"))
      end
    end

    it "runs the full six-stage lifecycle, none of it forced open" do
      html = html_for
      stages = html.scan(/data-ux-node-id="brd-frame-editor-lc-([a-z]+)"/).flatten.uniq
      expect(stages).to eq(%w[capture package send render edit submit])
      expect(html).not_to include(%( open>))
    end

    it "still shows the diff and the prose, and posts to plain apply" do
      kids = Array(dialog["children"]).map { |k| k["nodeId"] }
      expect(kids).to include("brd-editor-diff", "brd-editor-prose")
      expect(html_for).to include(%(action="apply"))
    end
  end

  describe "composing" do
    it "names every noun a + can add" do
      expect(ACIA::COMPOSE_NOUNS)
        .to eq(%w[frame input reference meaning clarification carry])
    end

    it "titles the dialog for the thing being made" do
      expect(dialog(compose: "meaning")["props"]["valueJson"]["title"])
        .to eq("New meaning")
    end

    it "drops the diff and the prose, which describe Y1 and not this" do
      kids = Array(dialog(compose: "frame")["children"]).map { |k| k["nodeId"] }
      expect(kids).not_to include("brd-editor-diff", "brd-editor-prose")
    end

    it "runs two stages, because nothing was captured, sent or derived" do
      html = html_for(compose: "frame")
      stages = html.scan(/data-ux-node-id="brd-frame-editor-lc-([a-z]+)"/).flatten.uniq
      expect(stages).to eq(%w[edit submit])
    end

    it "keeps the bar a bar: closed pills on top, the box below them" do
      html = html_for(compose: "frame")
      expect(html).not_to include(%( open>))
      kids = Array(dialog(compose: "frame")["children"]).map { |k| k["nodeId"] }
      expect(kids).to eq(%w[
        brd-frame-editor-close
        brd-frame-editor-lifecycle
        brd-compose-frame-prose-form
      ])
    end

    it "puts the box outside the lifecycle, so there is exactly one of it" do
      doc = ACIA.translation_board_editor_document(compose: "frame")
      json = doc.to_s
      expect(json.scan(/brd-compose-frame-prose-input/).size).to eq(1)
      # ...and the Edit stage discloses the guarantee rather than a second box.
      expect(html_for(compose: "frame")).to include("Nothing is stored until Submit")
    end

    it "carries the noun in the form action, known before the body is read" do
      expect(html_for(compose: "carry")).to include(%(action="apply?compose=carry"))
      expect(html_for(compose: "carry")).to include(%(data-ux-node-id="brd-compose-carry-prose-input-field"))
    end

    it "is a distinct projection: one digest per noun" do
      digests = ([nil] + ACIA::COMPOSE_NOUNS).map do |n|
        ACIA.validate(ACIA.translation_board_editor_document(compose: n)).digest
      end
      expect(digests.uniq.size).to eq(digests.size)
    end

    it "adds no textarea beyond the two Edit stages already declare" do
      ids = html_for(compose: "frame")
        .scan(/<textarea[^>]*data-ux-node-id="([^"]+)"/).flatten
      expect(ids.size).to eq(2)
    end
  end
end

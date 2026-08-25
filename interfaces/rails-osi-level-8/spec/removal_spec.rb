# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the minus" do
  AR = RailsOsiLevel8::Profile9::Acia
  RR = RailsOsiLevel8::Profile9::Renderer
  TT = { "tokens" => { "setRef" => "tokens:ghis@1" } }.freeze
  NEW = [{ "canonicalId" => "Y4", "title" => "Tidal",
           "label" => "Y4 — Tidal", "body" => "" }].freeze

  def html(doc)
    r = RR.render(acia: doc, token_set: TT, correlation: "cid:page:spec")
    expect(r["ok"]).to be(true)
    r["html"]
  end

  it "LINKS SOMEWHERE. It declared confirm and did nothing at all" do
    board = html(AR.translation_board_document)
    expect(board).to include("board-remove.html?remove=Y1%3AM2")
    expect(board).to include("board-remove.html?remove=X1")
  end

  it "shows the card it is about to destroy, not a description of it" do
    doc = AR.translation_board_remove_document(remove: "Y1:M2")
    h = html(doc)
    expect(h).to include(%(data-ux-node-id="brd-remove-subject"))
    expect(h).to include("Protective action may mean staying or leaving")
  end

  it "strips the rail off that copy: it is evidence, not an affordance" do
    doc = AR.translation_board_remove_document(remove: "Y1:M2")
    subject = nil
    walk = lambda { |n|
      next unless n.is_a?(Hash)
      subject = n if n["nodeId"] == "brd-remove-subject"
      Array(n["children"]).each { |c| walk.call(c) }
    }
    walk.call(doc["root"])
    kinds = Array(subject["children"]).map { |c| c["componentKind"] }
    expect(kinds).not_to include("ActionControl")
  end

  it "says what else reads through it BEFORE the click" do
    doc = AR.translation_board_remove_document(remove: "Y1:M2")
    text = doc.to_s
    expect(text).to include("2 cards read through it: Y1:M2:C1, Y1:M2:C2")
  end

  it "says so plainly when nothing reads through it" do
    doc = AR.translation_board_remove_document(remove: "Y4", composed: NEW)
    expect(doc.to_s).to include("Nothing else reaches through it")
  end

  it "CANCEL IS A LINK AND REMOVE IS A FORM" do
    # Backing out costs a GET that changes nothing. Destroying is a POST, so it
    # cannot happen by following, crawling or prefetching a link.
    h = html(AR.translation_board_remove_document(remove: "Y1:M2"))
    expect(h).to match(%r{<a[^>]*data-ux-node-id="brd-remove-cancel"})
    expect(h).to include(%(action="remove?id=Y1%3AM2"))
    expect(h).to include(%(method="post"))
  end

  it "conforms for every card on the board" do
    AR.board_canonical_ids.each do |cid|
      r = AR.validate(AR.translation_board_remove_document(remove: cid))
      expect(r.conforms?).to be(true), "remove=#{cid}: #{r.because.inspect[0, 200]}"
    end
  end

  it "is the board itself when asked to remove something that is not there" do
    doc = AR.translation_board_remove_document(remove: "Y9")
    expect(doc.to_s).not_to include("brd-remove-open")
    expect(AR.validate(doc).conforms?).to be(true)
  end
end

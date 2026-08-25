# frozen_string_literal: true

require "spec_helper"

RSpec.describe "board reach" do
  BR = RailsOsiLevel8::Profile9::BoardReach
  AC = RailsOsiLevel8::Profile9::Acia

  IDS = AC.board_canonical_ids.freeze

  # The hand-written list this replaced, kept here as the thing to match.
  DECLARED_X1 = %w[
    X1:Y1:R1 X1:Y1:R2 Y1:M1 Y1:M2 Y1:M1:C1 Y1:M2:C1 Y1:M2:C2
    X1:Y1:Z1 X1:Y1:Z2 X1:Y1:Z3
  ].freeze

  it "derives what the hand-written trace said, off the ids alone" do
    derived = BR.reaches("X1", IDS)
    expect(derived).to include(*DECLARED_X1)
  end

  it "adds only Y1:M3 -- the suggestion the list omitted while keeping X1:Y1:Z1" do
    expect(BR.reaches("X1", IDS) - DECLARED_X1).to eq(["Y1:M3"])
  end

  it "walks input -> reference -> meaning -> clarification, three hops out" do
    d = BR.from("X1", IDS)
    expect(d["X1:Y1:R1"]).to eq(1)
    expect(d["Y1:M1"]).to eq(2)
    expect(d["Y1:M1:C1"]).to eq(3)
  end

  it "reaches nothing from an input nothing has been read from" do
    # X2 is on the board and no reference names it. Saying so is the answer.
    expect(BR.reaches("X2", IDS)).to be_empty
  end

  it "reaches nothing from a frame nothing is read under" do
    expect(BR.reaches("Y2", IDS)).to be_empty
    expect(BR.reaches("Y1", IDS)).not_to be_empty
  end

  it "stops at the leaves" do
    expect(BR.reaches("Y1:M1:C1", IDS)).to be_empty
    expect(BR.reaches("X1:Y1:Z2", IDS)).to be_empty
  end

  it "names what each id is, which is what the sentence needs" do
    expect(BR.noun("X1")).to eq("Input")
    expect(BR.noun("Y2")).to eq("Frame")
    expect(BR.noun("X1:Y1:R1")).to eq("Reference")
    expect(BR.noun("Y1:M1")).to eq("Meaning")
    expect(BR.noun("Y1:M1:C1")).to eq("Clarification")
    expect(BR.noun("X1:Y1:Z1")).to eq("Carry")
  end

  it "reads an id under the frame it names, or the operative one" do
    expect(BR.frame_of("Y3:M1")).to eq("Y3")
    expect(BR.frame_of("X2")).to eq("Y1")
  end

  it "lists every id the rails actually link to" do
    expect(IDS).to include("X1", "X2", "X3", "Y1", "Y2", "Y3",
                           "X1:Y1:R1", "Y1:M1", "Y1:M1:C1", "X1:Y1:Z1")
  end

  it "lists a composed frame too, so a new card is traceable at once" do
    ids = AC.board_canonical_ids(
      composed: [{ "canonicalId" => "Y4", "title" => "Tidal", "label" => "Y4 — Tidal" }]
    )
    expect(ids).to include("Y4")
  end
end

RSpec.describe "trace and explore as projections" do
  AC2 = RailsOsiLevel8::Profile9::Acia

  def marks(doc)
    out = {}
    walk = lambda { |n|
      next unless n.is_a?(Hash)
      st = n.dig("props", "valueJson", "presentationState")
      out[n.dig("props", "valueJson", "canonicalId")] = st if st
      Array(n["children"]).each { |c| walk.call(c) }
    }
    walk.call(doc["root"])
    out
  end

  def node_by(doc, id)
    found = nil
    walk = lambda { |x|
      next unless x.is_a?(Hash)
      found = x if x["nodeId"] == id
      Array(x["children"]).each { |c| walk.call(c) }
    }
    walk.call(doc["root"])
    found
  end

  def sentence(doc) = node_by(doc, "brd-computation-sentence").dig("props", "valueJson", "title")

  def capture(doc)
    JSON.parse(node_by(doc, "brd-computation-lc-capture-jsonld").dig("props", "valueJson", "text"))
  end

  it "defaults to X1, which is what it always showed" do
    d = AC2.translation_board_trace_document
    expect(d["inspectOriginNodeId"]).to eq("brd-in-email")
    expect(marks(d)["X1"]).to eq("selected")
  end

  it "TRACES THE CARD THAT WAS PRESSED, not the one it always traced" do
    d = AC2.translation_board_trace_document(trace: "Y1:M2")
    expect(d["inspectOriginNodeId"]).to eq("brd-mn-protective")
    expect(marks(d)["Y1:M2"]).to eq("selected")
    expect(marks(d)["Y1:M2:C1"]).to eq("related")
    # ...and does not drag X1's trace along with it
    expect(marks(d)["X1:Y1:R1"]).to be_nil
  end

  it "says in the dialog what it is actually reading" do
    expect(sentence(AC2.translation_board_trace_document(trace: "X2")))
      .to start_with("Reading Input X2 under Frame Y1")
    expect(sentence(AC2.translation_board_trace_document(trace: "Y1:M2")))
      .to start_with("Reading Meaning Y1:M2 under Frame Y1")
    # a frame is not read under itself
    expect(sentence(AC2.translation_board_trace_document(trace: "Y2")))
      .to start_with("Reading Frame Y2 to propose")
  end

  it "CAPTURES THE CARD THAT WAS PRESSED" do
    # Stage 1 embedded X1 whatever you pressed, which made the event log a
    # fixture. It comes out of this document now.
    e = capture(AC2.translation_board_trace_document(trace: "X1:Y1:R1"))
    expect(e["canonicalId"]).to eq("X1:Y1:R1")
    expect(e["component"]).to eq("brd-or-evacuate")
    expect(e.dig("shownContext", "props", "valueJson", "title"))
      .to include("Residents hear")
  end

  it "captures the card as it was SHOWN, without this projection's own marks" do
    e = capture(AC2.translation_board_trace_document(trace: "X1"))
    expect(e.dig("shownContext", "props", "valueJson", "presentationState")).to be_nil
  end

  it "keeps the declared exploration for the board's worked example" do
    d = AC2.translation_board_inspect_document(explore: "X1:Y1:R1")
    expect(marks(d)).to eq(AC2.translation_board_inspect_document.then { |x| marks(x) })
    expect(marks(d)["Y1:M1"]).to eq("likely-hit")
    expect(marks(d)["Y1:M2"]).to eq("related")
  end

  it "derives an exploration anywhere else, by distance" do
    m = marks(AC2.translation_board_inspect_document(explore: "Y1:M2"))
    expect(m["Y1:M2"]).to eq("selected")
    expect(m["Y1:M2:C1"]).to eq("likely-hit")
    expect(m["Y1:M1"]).to eq("out-of-scope")
  end

  it "every origin still conforms to the closed shape" do
    AC2.board_canonical_ids.each do |cid|
      t = AC2.validate(AC2.translation_board_trace_document(trace: cid))
      e = AC2.validate(AC2.translation_board_inspect_document(explore: cid))
      expect(t.conforms?).to be(true), "trace=#{cid}: #{t.because.inspect[0, 200]}"
      expect(e.conforms?).to be(true), "explore=#{cid}: #{e.because.inspect[0, 200]}"
    end
  end

  it "gives each origin its own digest -- a different question, a different page" do
    digests = AC2.board_canonical_ids.map do |cid|
      AC2.validate(AC2.translation_board_trace_document(trace: cid)).digest
    end
    expect(digests.uniq.size).to eq(digests.size)
  end
end

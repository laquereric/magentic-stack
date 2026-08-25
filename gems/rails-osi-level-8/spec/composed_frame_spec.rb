# frozen_string_literal: true

require "spec_helper"

RSpec.describe "composed frames" do
  CF = RailsOsiLevel8::Profile9::ComposedFrame

  describe "parsing" do
    it "takes the canonical id from a heading that supplies one" do
      r = CF.parse("Y4 — Tidal access\n\nFrames the tide as a commons.", fallback_id: "Y9")
      expect(r[:ok]).to be(true)
      expect(r[:frame]["canonicalId"]).to eq("Y4")
      expect(r[:frame]["title"]).to eq("Tidal access")
      expect(r[:frame]["label"]).to eq("Y4 — Tidal access")
      expect(r[:frame]["body"]).to eq("Frames the tide as a commons.")
    end

    it "accepts the separators people actually type" do
      ["Y4 — T", "Y4 - T", "Y4: T", "Y4 -- T"].each do |head|
        expect(CF.parse(head, fallback_id: "Y9")[:frame]["canonicalId"]).to eq("Y4")
      end
    end

    it "mints the next free id when the heading does not name one" do
      r = CF.parse("Tidal access", fallback_id: "Y7")
      expect(r[:frame]["canonicalId"]).to eq("Y7")
      expect(r[:frame]["title"]).to eq("Tidal access")
    end

    it "splits a run-on paragraph at the first sentence" do
      # What people actually type. Without this the whole paragraph becomes the
      # card title.
      prose = "Y4 — Tidal access as shared infrastructure. Frames the harbour's " \
              "tide windows as a commons rather than a queue, so what is allocated " \
              "is access to a cycle and not a place in a line."
      r = CF.parse(prose, fallback_id: "Y9")
      expect(r[:frame]["title"]).to eq("Tidal access as shared infrastructure.")
      expect(r[:frame]["body"]).to start_with("Frames the harbour")
    end

    it "leaves a short heading whole even when it has sentence punctuation" do
      r = CF.parse("Y4 — Tide, wind, and berth.", fallback_id: "Y9")
      expect(r[:frame]["title"]).to eq("Tide, wind, and berth.")
      expect(r[:frame]["body"]).to eq("")
    end

    it "refuses empty prose rather than inventing a frame" do
      ["", "   ", "\n\n"].each do |empty|
        r = CF.parse(empty, fallback_id: "Y9")
        expect(r[:ok]).to be(false)
        expect(r[:reason]).to eq(:empty_prose)
      end
    end

    it "never raises: an envelope, whatever it is handed" do
      [nil, 42, {}].each do |junk|
        expect { CF.parse(junk, fallback_id: "Y9") }.not_to raise_error
      end
    end
  end
end

RSpec.describe "a composed frame on the board" do
  A2 = RailsOsiLevel8::Profile9::Acia
  R2 = RailsOsiLevel8::Profile9::Renderer
  T2 = { "tokens" => { "setRef" => "tokens:ghis@1" } }.freeze
  FRAME = { "canonicalId" => "Y4", "title" => "Tidal access",
            "label" => "Y4 — Tidal access", "body" => "" }.freeze

  def render(doc)
    res = R2.render(acia: doc, token_set: T2, correlation: "cid:page:spec")
    expect(res["ok"]).to be(true)
    res["html"]
  end

  it "renders nothing extra when nothing has been composed" do
    html = render(A2.translation_board_document)
    expect(html).not_to include("brd-frame-composed-1")
  end

  it "appears as a fourth frame card" do
    html = render(A2.translation_board_document(composed: [FRAME]))
    expect(html).to include(%(data-ux-node-id="brd-frame-composed-1"))
    expect(html).to include("Y4 — Tidal access")
  end

  it "CARRIES THE SAME AFFORDANCES as the frames that were always there" do
    # The whole point. A card that looks like the others and answers to none of
    # them is worse than no card.
    html = render(A2.translation_board_document(composed: [FRAME]))
    %w[trace explore remove].each do |verb|
      expect(html).to include(%(data-ux-node-id="brd-frame-composed-1-#{verb}"))
    end
    expect(html).to include("board-trace.html?trace=Y4")
    expect(html).to include("board-inspect.html?explore=Y4")
  end

  it "reaches every projection derived from the board" do
    %i[translation_board_inspect_document translation_board_trace_document
       translation_board_editor_document translation_board_distinction_document
       translation_board_context_document].each do |m|
      html = render(A2.public_send(m, composed: [FRAME]))
      expect(html).to include("brd-frame-composed-1"), "#{m} dropped the composed frame"
    end
  end

  it "numbers them in order, and each keeps its own id" do
    two = [FRAME, { "canonicalId" => "Y5", "title" => "Berth rotation",
                    "label" => "Y5 — Berth rotation", "body" => "" }]
    html = render(A2.translation_board_document(composed: two))
    expect(html).to include("brd-frame-composed-1", "brd-frame-composed-2")
    expect(html).to include("board-trace.html?trace=Y5")
  end

  it "is a different document, so it carries a different digest" do
    a = A2.validate(A2.translation_board_document).digest
    b = A2.validate(A2.translation_board_document(composed: [FRAME])).digest
    expect(a).not_to eq(b)
  end
end

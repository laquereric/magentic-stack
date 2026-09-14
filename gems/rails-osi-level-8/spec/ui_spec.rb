# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOsiLevel8::Ui do
  before { RailsOsiLevel8::Ui::Surface.reset! }

  it "catalog.get serves ghis-19 and S2+S3 task kinds" do
    cat = RailsOsiLevel8::Ui::Catalog.get
    expect(cat.dig("presentation", "version")).to eq("ghis-19@1")
    expect(cat.dig("presentation", "kinds")).to include("DecisionForm", "EmptyState")
    kinds = cat.dig("task", "kinds").map { |k| k["kind"] }
    expect(kinds).to eq(%w[
      task.form task.confirm task.error task.empty task.approval task.preview task.date
      task.table task.status task.choice task.progress_steps task.citation
    ])
    expect(cat.dig("presentation", "versions", "ghis-20@1")).to include("DateInput")
    expect(cat.dig("presentation", "versions", "ghis-19@1")).not_to include("DateInput")
    expect(cat.dig("presentation", "versions", "ghis-21@1")).to include("Input", "DateInput")
    expect(cat.dig("presentation", "versions", "ghis-20@1")).not_to include("Input")
  end

  it "refuses task.form without an information model" do
    expect {
      RailsOsiLevel8::Ui::Surface.put("taskKind" => "task.form", "title" => "X")
    }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
      expect(e.reason).to eq("information_model_required")
    }
  end

  it "puts a task.form compiled from F2 fields and round-trips get" do
    put = RailsOsiLevel8::Ui::Surface.put(
      "taskKind" => "task.form",
      "title" => "Authorization review",
      "stepKind" => "decide",
      "fields" => RailsOsiLevel8::Profile9::Compile::J1_FIELDS
    )
    expect(put["ok"]).to eq(true)
    expect(put["digest"]).to start_with("sha256:")
    got = RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"])
    expect(got["digest"]).to eq(put["digest"])
    expect(got.dig("document", "root", "componentKind")).to eq("PageShell")
  end

  it "html in a document prop is html_forbidden" do
    bad = RailsOsiLevel8::Profile9::Acia.authorization_review_fixture
    bad["root"]["props"]["valueJson"]["html"] = "<b>x</b>"
    expect {
      RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.form",
        "fields" => RailsOsiLevel8::Profile9::Compile::J1_FIELDS,
        "document" => bad
      )
    }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
      expect(e.reason).to eq("html_forbidden")
    }
  end

  it "puts confirm / error / empty without a model" do
    %w[task.confirm task.error task.empty].each do |kind|
      RailsOsiLevel8::Ui::Surface.reset!
      rec = RailsOsiLevel8::Ui::Surface.put("taskKind" => kind, "title" => kind)
      expect(rec["ok"]).to eq(true), kind
    end
  end

  describe "S3 ui.action + task.approval" do
    it "journals submit and never writes machineEffectCid" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.form",
        "stepKind" => "decide",
        "fields" => RailsOsiLevel8::Profile9::Compile::J1_FIELDS
      )
      rec = RailsOsiLevel8::Ui::Action.call(
        "surfaceCid" => put["cid"], "action" => "submit", "actorCid" => "cid:actor:op"
      )
      expect(rec["ok"]).to eq(true)
      expect(rec).not_to have_key("machineEffectCid")
      expect(RailsOsiLevel8::Ui::Action.journal.map { |j| j["cid"] }).to include(rec["cid"])
    end

    it "refuses an agent closing Effect through ui.action" do
      put = RailsOsiLevel8::Ui::Surface.put("taskKind" => "task.confirm", "title" => "C")
      expect {
        RailsOsiLevel8::Ui::Action.call(
          "surfaceCid" => put["cid"], "action" => "accept", "machineEffectCid" => "cid:effect:sneak"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("agent_closes_effect")
      }
    end

    it "cannot accept task.approval without a claimed HumanReview" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.approval",
        "title" => "Review draft",
        "reviewedDigest" => "sha256:abc"
      )
      expect {
        RailsOsiLevel8::Ui::Action.call(
          "surfaceCid" => put["cid"], "action" => "accept", "actorCid" => "actor-1", "jobId" => "99"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("claim_required")
      }
    end

    it "accepts task.approval after the Actor claims HumanReview" do
      put = RailsOsiLevel8::Ui::Surface.put("taskKind" => "task.approval", "title" => "Review")
      RailsOsiLevel8::Ui::Claims.register!(job_id: "7", actor_id: "actor-1")
      rec = RailsOsiLevel8::Ui::Action.call(
        "surfaceCid" => put["cid"], "action" => "accept",
        "actorCid" => "actor-1", "jobId" => "7"
      )
      expect(rec["ok"]).to eq(true)
      expect(rec.dig("job", "elementId")).to eq("HumanReview")
      expect(rec).not_to have_key("machineEffectCid")
    end
  end

  describe "S4 canvas blob + task.preview" do
    it "blob.put names the bytes by digest and refuses graph IRIs" do
      rec = RailsOsiLevel8::Ui::Blob.put("bytes" => "fabric-json-v1")
      expect(rec["ok"]).to eq(true)
      expect(rec["digest"]).to match(/\Asha256:[0-9a-f]{64}\z/)
      expect(rec).not_to have_key("spec_iri")
      expect(rec).not_to have_key("graph_iri")
      expect {
        RailsOsiLevel8::Ui::Blob.put("bytes" => "x", "graph_iri" => "urn:mm:graph:canvas")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("graph_iri_refused")
      }
    end

    it "task.preview cites the blob digest and refuses a graph IRI" do
      blob = RailsOsiLevel8::Ui::Blob.put("bytes" => "png-bytes")
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.preview",
        "title" => "Poster",
        "blobDigest" => blob["digest"]
      )
      expect(put["ok"]).to eq(true)
      expect(put["blobDigest"]).to eq(blob["digest"])
      text = put.dig("document", "root", "children").find { |n|
        n.dig("props", "valueJson", "blobDigest")
      }
      expect(text.dig("props", "valueJson", "blobDigest")).to eq(blob["digest"])
      expect {
        RailsOsiLevel8::Ui::Surface.put(
          "taskKind" => "task.preview",
          "blobDigest" => blob["digest"],
          "spec_iri" => "urn:mm:bpmn:canvas"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("graph_iri_refused")
      }
    end

    it "task.preview without a digest refuses" do
      expect {
        RailsOsiLevel8::Ui::Surface.put("taskKind" => "task.preview", "title" => "X")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("blob_digest_required")
      }
    end
  end

  describe "S6 task.date" do
    it "puts a DateInput on ghis-20@1" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.date",
        "title" => "Due",
        "fields" => [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }]
      )
      expect(put["ok"]).to eq(true)
      expect(put.dig("document", "componentRegistryVersion")).to eq("ghis-20@1")
      kinds = put.dig("document", "root", "children").map { |n| n["componentKind"] }
      expect(kinds).to include("DateInput")
      expect(kinds).not_to include("SemanticText")
    end

    it "puts string fields as Input on ghis-21@1" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.form",
        "catalogVersion" => "ghis-21@1",
        "title" => "Note",
        "fields" => [{ "name" => "note", "datatype" => "string", "ordinal" => 1 }]
      )
      expect(put["ok"]).to eq(true)
      expect(put.dig("document", "componentRegistryVersion")).to eq("ghis-21@1")
      kinds = put.dig("document", "root", "children").map { |n| n["componentKind"] }
      expect(kinds).to include("Input")
      expect(kinds).not_to include("SemanticText")
      a2 = RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"], "as" => "a2ui")["a2ui"]
      expect(a2.dig("updateComponents", "components").map { |c| c["component"] }).to include("TextField")
    end

    it "still refuses date on ghis-19@1" do
      expect {
        RailsOsiLevel8::Ui::Surface.put(
          "taskKind" => "task.date",
          "catalogVersion" => "ghis-19@1",
          "fields" => [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }]
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("date_kind_missing")
      }
    end
  end

  describe "S5 A2UI 0.9.1 emit" do
    it "maps every ghis kind except Disclosure and FilterBar" do
      mapped = RailsOsiLevel8::Ui::A2ui::KIND_MAP.keys
      ghis = RailsOsiLevel8::Profile9::Vocabulary::GHIS_21_KINDS
      expect(ghis - mapped).to contain_exactly("Disclosure", "FilterBar")
    end

    it "pins 0.9.1 and draws the four S2 kinds" do
      expect(RailsOsiLevel8::Ui::A2ui::VERSION).to eq("v0.9.1")
      expect(RailsOsiLevel8::Ui::A2ui.spec_digest).to start_with("sha256:")
      %w[task.confirm task.error task.empty].each do |kind|
        RailsOsiLevel8::Ui::Surface.reset!
        put = RailsOsiLevel8::Ui::Surface.put("taskKind" => kind, "title" => kind)
        got = RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"], "as" => "a2ui")
        a2 = got["a2ui"]
        expect(a2["version"]).to eq("v0.9.1")
        expect(a2["specDigest"]).to eq(RailsOsiLevel8::Ui::A2ui.spec_digest)
        expect(a2.dig("createSurface", "catalogId")).to include("v0_9_1")
        ids = a2.dig("updateComponents", "components").map { |c| c["id"] }
        expect(ids).to include("root")
        types = a2.dig("updateComponents", "components").map { |c| c["component"] }
        expect(types).to include("Column")
      end
    end

    it "counts unknown ghis kinds instead of dropping them" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.form",
        "stepKind" => "decide",
        "title" => "Authorization review",
        "fields" => RailsOsiLevel8::Profile9::Compile::J1_FIELDS
      )
      # J1 still carries Disclosure (no Basic kind). EvidencePanel maps to Card.
      j1 = RailsOsiLevel8::Profile9::Compile.j1_document
      emit = RailsOsiLevel8::Ui::A2ui.emit(j1["document"])
      expect(emit["unknownKindCount"]).to be >= 1
      kinds = emit["unknownKinds"].map { |u| u["componentKind"] }
      expect(kinds).to include("Disclosure")
      expect(kinds).not_to include("EvidencePanel")
      texts = emit.dig("updateComponents", "components").map { |c| c["text"] }
      expect(texts.compact.grep(/unmapped:Disclosure/)).not_to be_empty
    end

    it "maps DateInput to A2UI DateTimeInput" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.date",
        "title" => "Due",
        "fields" => [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }]
      )
      a2 = RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"], "as" => "a2ui")["a2ui"]
      types = a2.dig("updateComponents", "components").map { |c| c["component"] }
      expect(types).to include("DateTimeInput")
      expect(a2["unknownKindCount"]).to eq(0)
    end

    it "does not treat as=a2ui-1 as the 0.9.1 adapter" do
      put = RailsOsiLevel8::Ui::Surface.put("taskKind" => "task.empty", "title" => "E")
      expect {
        RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"], "as" => "a2ui-1")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("as_not_supported")
        expect(e.because["allowed"]).to eq(%w[acia html a2ui adaptive-cards block-kit])
      }
    end
  end

  describe "twelve task kinds" do
    {
      "task.table" => "DataList",
      "task.status" => "StatusBadge",
      "task.choice" => "TabSet",
      "task.progress_steps" => "Timeline",
      "task.citation" => "ReferentBridge"
    }.each do |kind, ghis|
      it "puts #{kind} composed of #{ghis}" do
        put = RailsOsiLevel8::Ui::Surface.put("taskKind" => kind, "title" => kind)
        expect(put["ok"]).to eq(true)
        kinds = put.dig("document", "root", "children").map { |n| n["componentKind"] }
        expect(kinds).to include(ghis)
      end
    end
  end

  describe "Adaptive Cards 1.5 and Block Kit emit" do
    it "emits Input.Date for DateInput, never Input.Text" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.date",
        "title" => "Due",
        "fields" => [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }]
      )
      ac = RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"], "as" => "adaptive-cards")["adaptiveCards"]
      expect(ac["version"]).to eq("1.5")
      expect(ac["specDigest"]).to start_with("sha256:")
      types = ac["body"].map { |b| b["type"] }
      expect(types).to include("Input.Date")
      expect(types).not_to include("Input.Text")
    end

    it "emits Block Kit datepicker for DateInput" do
      put = RailsOsiLevel8::Ui::Surface.put(
        "taskKind" => "task.date",
        "title" => "Due",
        "fields" => [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }]
      )
      bk = RailsOsiLevel8::Ui::Surface.get("aciaCid" => put["cid"], "as" => "block-kit")["blockKit"]
      expect(bk["specDigest"]).to start_with("sha256:")
      elements = bk["blocks"].flat_map { |b| [b["type"], b.dig("element", "type")] }
      expect(elements).to include("datepicker")
      expect(elements).not_to include("plain_text_input")
    end
  end
end

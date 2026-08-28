# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Base::Session do
  def build_session(**attrs)
    described_class.create!({ actor_kind: "human", opened_at: Time.now.utc }.merge(attrs))
  end

  it "accepts either actor kind through ONE entity -- that is the cyborg pairing" do
    expect(build_session(actor_kind: "human")).to be_persisted
    expect(build_session(actor_kind: "agent")).to be_persisted
  end

  it "refuses an actor kind outside the closed set" do
    expect { build_session(actor_kind: "daemon") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "opens without an actor, because the pod cannot prove one" do
    expect(build_session(actor_id: nil)).to be_persisted
  end

  describe "#session_iri" do
    it "derives the graph name from the primary key" do
      s = build_session
      expect(s.session_iri).to eq("urn:mm:session:#{s.id}")
    end

    # The invariant Mmg::Graph::Entry#graph_name states: a caller that could name
    # its own graph could write into someone else's. An unsaved session has no
    # key, so it must refuse rather than invent one.
    it "refuses to name a graph before the row exists" do
      expect { described_class.new.session_iri }.to raise_error(/unsaved session/)
    end

    it "gives two sessions two different graphs" do
      expect(build_session.session_iri).not_to eq(build_session.session_iri)
    end
  end

  describe "#bump_generation!" do
    it "advances monotonically so a reading can name the state it read" do
      s = build_session
      expect(s.generation).to eq(0)
      expect(s.bump_generation!).to eq(1)
      expect(s.bump_generation!).to eq(2)
    end
  end

  describe "#close!" do
    it "seals the session and stamps closed_at" do
      s = build_session
      expect(s).to be_open
      s.close!
      expect(s).to be_closed
      expect(s.closed_at).not_to be_nil
    end

    it "is idempotent -- closing twice does not move closed_at" do
      s = build_session
      first = s.close!.closed_at
      expect(s.close!.closed_at).to eq(first)
    end
  end
end

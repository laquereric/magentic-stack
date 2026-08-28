# frozen_string_literal: true

require "spec_helper"

# A session-scoped entry writes into the session's graph instead of its own, so
# one session accumulates in ONE named graph. The invariant that must survive is
# the one Entry#graph_name states: the name is derived from a primary key and
# resolves to a row -- never handed in by the caller.
RSpec.describe "session-scoped graph entries" do
  # Stand-in for Vv::Base::Session. mmg-graph does not depend on vv-base, so the
  # real class is absent here; what matters is that the lookup is a REAL existence
  # check against a table, not a trusted parameter.
  before do
    stub_const("Vv::Base::Session", Class.new do
      def self.rows = @rows ||= {}
      def self.exists?(id:) = rows.key?(id.to_i)
      def self.find_by(id:) = rows[id.to_i]
    end)
    Vv::Base::Session.rows.clear
  end

  def entry(session_id: nil)
    Mmg::Graph::Entry.create!(date: "2026-08-28", name: "n", description: "d",
                             session_id: session_id)
  end

  it "keeps the private graph when no session is named" do
    e = entry
    expect(e.graph_name).to eq("urn:mmg:graph:entry:#{e.id}")
  end

  it "writes into the session graph when one is named" do
    expect(entry(session_id: 7).graph_name).to eq("urn:mm:session:7")
  end

  it "puts TWO entries of one session in the SAME graph -- the point of the change" do
    expect(entry(session_id: 7).graph_name).to eq(entry(session_id: 7).graph_name)
  end

  it "keeps different sessions in different graphs" do
    expect(entry(session_id: 7).graph_name).not_to eq(entry(session_id: 8).graph_name)
  end

  it "still grounds each write in its OWN entry -- shared destination, not shared account" do
    a = entry(session_id: 7)
    b = entry(session_id: 7)
    expect(a.id).not_to eq(b.id)
    expect([a.date, a.name, a.description]).to all(be_present)
  end

  describe "publish" do
    let(:triples) { [%w[<urn:s> <urn:p> "o"]] }

    def publish(session_id)
      Mmg::Graph::Cpcp.publish("date" => "2026-08-28", "name" => "n",
                               "description" => "d", "triples" => triples,
                               "session_id" => session_id)
    end

    it "REFUSES a session that does not exist, rather than minting a dangling name" do
      r = publish(999)
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:unknown_session)
    end

    it "refuses when the session class is absent -- unvalidated FK is a caller-supplied name" do
      hide_const("Vv::Base::Session")
      expect(publish(7)[:reason]).to eq(:unknown_session)
    end

    it "gets PAST the session check for a real session (store is closed, so it fails later)" do
      Vv::Base::Session.rows[7] = :present
      expect(publish(7)[:reason]).not_to eq(:unknown_session)
    end
  end
end

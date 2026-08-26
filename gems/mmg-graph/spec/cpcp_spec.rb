# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Graph::Cpcp do
  let(:params) do
    { "date" => "2026-08-26", "name" => "seed", "description" => "why these exist",
      "triples" => ['<urn:a> <urn:b> "c" .'] }
  end

  describe "register!" do
    it "refuses rather than raising when rails-cpcp is absent" do
      out = described_class.register!

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:cpcp_absent)
    end
  end

  # Supplying the account and grounding the node are THE SAME ACT. There is no
  # path here that asserts triples without saying when, what and why.
  describe "publish" do
    it "creates the entry and asserts the triples together" do
      allow(Mmg::Graph::Execute).to receive(:publish).and_return({ ok: true })

      expect { described_class.publish(params) }.to change(Mmg::Graph::Entry, :count).by(1)
      entry = Mmg::Graph::Entry.order(:id).last
      expect(entry.name).to eq("seed")
      expect(entry.description).to eq("why these exist")
    end

    it "refuses an entry that cannot say why it exists, and writes nothing" do
      expect(Mmg::Graph::Execute).not_to receive(:publish)

      out = nil
      expect { out = described_class.publish(params.merge("description" => nil)) }
        .not_to change(Mmg::Graph::Entry, :count)

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:entry_incomplete)
      expect(out[:because]).to match(/never why it is here/)
    end

    it "refuses an empty triple list" do
      out = described_class.publish(params.merge("triples" => []))

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:triples_required)
    end

    # THE TRANSACTIONAL PROPERTY.
    #
    # Saving the entry and publishing after would leave a record saying "this is
    # what we stored and why" pointing at an empty named graph. That is worse
    # than no record, because it reads as evidence.
    it "rolls the entry back when the store refuses the write" do
      allow(Mmg::Graph::Execute).to receive(:publish)
        .and_return({ ok: false, reason: :update_failed, because: "HTTP 500" })

      out = nil
      expect { out = described_class.publish(params) }.not_to change(Mmg::Graph::Entry, :count)

      expect(out[:ok]).to be(false)
      expect(out[:entry_rolled_back]).to be(true)
      expect(out[:because]).to match(/rolled back rather than left accounting/)
    end

    it "rolls back on an unreachable store too, not just a refusal" do
      # No stub: Execute.publish really runs and the endpoint is a closed port.
      expect { described_class.publish(params) }.not_to change(Mmg::Graph::Entry, :count)
    end

    # THE NESTED CASE, PINNED.
    #
    # Every example here already runs inside an outer transaction (see
    # spec_helper), so these rollback specs ARE the nested case -- which is how
    # the bug showed up. A plain `transaction` block nested in an outer one joins
    # it, and ActiveRecord::Rollback in a joined block is swallowed: the entry
    # would COMMIT while the assertion never happened. cpcp.rb uses
    # requires_new: true so it rolls back on its own terms. This spec fails if
    # that word is ever removed.
    it "rolls back even when a caller has wrapped it in a transaction of their own" do
      allow(Mmg::Graph::Execute).to receive(:publish).and_return({ ok: false, reason: :update_failed, because: "HTTP 500" })

      expect {
        ::ActiveRecord::Base.transaction { described_class.publish(params) }
      }.not_to change(Mmg::Graph::Entry, :count)
    end

    it "never raises, even when the model layer blows up" do
      allow(Mmg::Graph::Entry).to receive(:new).and_raise(RuntimeError, "boom")
      out = described_class.publish(params)

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:publish_failed)
      expect(out[:because]).to include("boom")
    end
  end

  describe "entries" do
    it "reports what was asserted and why, newest first" do
      %w[one two].each do |n|
        Mmg::Graph::Entry.create!(date: "2026-08-26", name: n, description: "d-#{n}")
      end
      out = described_class.entries

      expect(out[:ok]).to be(true)
      expect(out[:rows].first[:name]).to eq("two")
      expect(out[:rows].first).to include(:ref, :graph, :date, :description)
    end
  end
end

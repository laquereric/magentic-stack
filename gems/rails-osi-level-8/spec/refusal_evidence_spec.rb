# frozen_string_literal: true

require "spec_helper"

# A REFUSAL IS AN ADMISSION DECISION AND MUST LEAVE EVIDENCE (ADR 0052).
#
# Found on a live seam, 2026-09-04: acia.latest was refused for stamping a
# server-authoritative digest -- correctly -- and afterwards there was no record
# of it anywhere. No journal row (the journal hangs off an OperationRequest that
# only push creates) and no admission attempt either, because record_refusal!
# was guarded `if @direction == :push`. The identical refusal of acia.publish
# WAS recorded. Direction decided whether a decision was remembered.
#
# These specs run without ActiveRecord -- the gem's specs never load it -- so
# they assert the adapter's decision to record rather than the row it writes.
# That is the layer the defect was in: not a broken write, a write never reached.
RSpec.describe "refusals leave evidence" do
  before do
    RailsOsiLevel8.configure do |c|
      c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default
    end
  end

  def adapter(direction:, request_shape:, response_shape:, profiles: %w[test/profile@1], &handler)
    RailsOsiLevel8::CpcpAdapter.new(
      operation: "test.op",
      direction: direction,
      profiles: profiles,
      request_shape: request_shape,
      response_shape: response_shape,
      handler: handler || ->(_p, _c) { { "ok" => true } }
    )
  end

  # "title" is not a declared filter on this shape, so a request carrying it is
  # refused at the inbound gate -- the same class of refusal acia.latest hit.
  let(:refused_params) { { "title" => "x" } }

  describe "an inbound refusal" do
    it "is recorded for a PULL -- the regression: this recorded nothing" do
      a = adapter(direction: :pull, request_shape: "P1::NoteListPullShape",
                  response_shape: "P1::NoteListPullShape")
      expect(a).to receive(:record_admission!).with(
        anything, anything, anything, hash_including(conforms: false)
      )

      expect { a.call(refused_params, nil) }.to raise_error(RailsOsiLevel8::KnownRefusal)
    end

    it "is still recorded for a PUSH -- the fix must not trade one gap for another" do
      a = adapter(direction: :push, request_shape: "P1::NoteListPullShape",
                  response_shape: "P1::NoteListPullShape")
      expect(a).to receive(:record_admission!).with(
        anything, anything, anything, hash_including(conforms: false)
      )

      expect { a.call(refused_params, nil) }.to raise_error(RailsOsiLevel8::KnownRefusal)
    end

    it "reports the refusal to the caller even when the evidence write fails" do
      a = adapter(direction: :pull, request_shape: "P1::NoteListPullShape",
                  response_shape: "P1::NoteListPullShape")
      allow(a).to receive(:record_admission!).and_raise(StandardError, "no database")

      # grounding_refused, NOT processing_failed: a bookkeeping failure must not
      # rewrite the answer the caller gets.
      expect { a.call(refused_params, nil) }
        .to raise_error(RailsOsiLevel8::KnownRefusal) { |e| expect(e.reason).to eq("grounding_refused") }
    end
  end

  describe "a response refusal on a PULL" do
    let(:refusing_response) do
      adapter(direction: :pull, request_shape: "P1::NoteListPullShape",
              response_shape: "P1::NoteListPullShape") { |_p, _c| { "title" => "x" } }
    end

    # Request conforms; the ANSWER does not match the shape this seam publishes.
    # push! journals "response_refused" here; a pull has no OperationRequest to
    # hang an entry on, so the admission attempt is the only place it can land.
    it "is recorded under its own reason" do
      a = refusing_response
      expect(a).to receive(:record_admission!).with(
        anything, anything, anything, hash_including(reason: "response_refused")
      )

      expect { a.call({}, nil) }.to raise_error(RailsOsiLevel8::KnownRefusal)
    end

    # ADR 0052: "response_refused is not refused. One is a refused response, the
    # other a refused admission. Conflating them would reintroduce the same class
    # of error this ADR exists to remove." The first version of this fix recorded
    # conforms: false here, which files a bad ANSWER as a bad REQUEST -- in the
    # one table whose job is to say which of those happened.
    it "does not blame the caller: conforms stays true because the request DID conform" do
      a = refusing_response
      expect(a).to receive(:record_admission!).with(
        anything, anything, anything, hash_including(conforms: true)
      )

      expect { a.call({}, nil) }.to raise_error(RailsOsiLevel8::KnownRefusal)
    end

    it "still records conforms: false when the REQUEST is the thing at fault" do
      a = adapter(direction: :pull, request_shape: "P1::NoteListPullShape",
                  response_shape: "P1::NoteListPullShape")
      expect(a).to receive(:record_admission!).with(
        anything, anything, anything, hash_including(conforms: false, reason: "grounding_refused")
      )

      expect { a.call(refused_params, nil) }.to raise_error(RailsOsiLevel8::KnownRefusal)
    end
  end

  # THE JOURNAL MUST NAME THE PROFILE THAT DECIDED.
  #
  # Every entry hardcoded "osi-l8/p4-durable-execution@1" -- the substrate's own
  # profile -- while create_operation_request! resolved @profiles.first. Read
  # back on a live seam the journal could say that SOME profile admitted an
  # operation but not WHICH, and with applications registering their own shapes
  # (ADR 0063) that is the only part worth knowing.
  describe "journal entries" do
    let(:op_req) do
      instance_double("OperationRequest", cid: "cid:sha256:op").tap do |d|
        allow(d).to receive(:journal_entries).and_return(
          instance_double("Relation", maximum: 0)
        )
      end
    end

    def written_attributes(profiles)
      captured = nil
      klass = Class.new
      # Captured through a closure rather than a message expectation: the
      # assertion is about the VALUE written, not that a write happened.
      klass.define_singleton_method(:create!) { |attrs| captured = attrs }
      stub_const("RailsOsiLevel8::OperationJournalEntry", klass)

      adapter(direction: :push, request_shape: "P1::NoteListPullShape",
              response_shape: "P1::NoteListPullShape", profiles: profiles)
        .send(:append_journal!, op_req, "received")
      captured
    end

    it "names the profile that held the shape, not the substrate's" do
      expect(written_attributes(%w[cpcp/tb/board@1])[:profile_id]).to eq("cpcp/tb/board@1")
    end

    it "falls back to the substrate profile when an operation declares none" do
      expect(written_attributes([])[:profile_id]).to eq("osi-l8/p4-durable-execution@1")
    end
  end
end

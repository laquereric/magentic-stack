# frozen_string_literal: true

require "spec_helper"
require "pathname"

# The RUNTIME twin of session-operations.shacl.ttl.
#
# The TTL is the specification and CI runs pyshacl over it with fixtures, but the
# TTL is not executed in-process (see Grounding's module comment). These specs
# cover what actually refuses a live request, so the two stay in step.
RSpec.describe "session operation shapes" do
  def validate(shape, params)
    RailsOsiLevel8::Grounding.validate(params, profile: shape)
  end

  def paths(result) = result.violations.map { |v| v[:path] }

  describe "P1::SessionOpenEffectShape" do
    let(:shape) { "P1::SessionOpenEffectShape" }

    it "accepts a named intent and a known actor kind" do
      expect(validate(shape, "operationId" => "op-1", "actor_kind" => "human")).to be_conforms
    end

    it "accepts an agent session -- one entity, either actor" do
      expect(validate(shape, "operationId" => "op-1", "actor_kind" => "agent")).to be_conforms
    end

    it "refuses a PUSH that does not name its intent" do
      r = validate(shape, "actor_kind" => "human")
      expect(r).not_to be_conforms
      expect(paths(r)).to include("cpcp:idempotencyKey")
    end

    it "refuses an actor kind outside the closed set" do
      r = validate(shape, "operationId" => "op-1", "actor_kind" => "daemon")
      expect(paths(r)).to include("actor_kind")
    end

    # The invariant Entry#graph_name and Session#session_iri both protect.
    it "refuses a caller-named session graph" do
      r = validate(shape, "operationId" => "op-1", "session_iri" => "urn:mm:session:999")
      expect(paths(r)).to include("session_iri")
    end

    it "refuses a caller claiming its actor is proven" do
      r = validate(shape, "operationId" => "op-1", "actor_proven" => true)
      expect(paths(r)).to include("actor_proven")
    end
  end

  describe "P1::SessionObserveEffectShape" do
    let(:shape) { "P1::SessionObserveEffectShape" }
    let(:valid) { { "operationId" => "op-1", "session_id" => 1, "title" => "a reading" } }

    it "accepts a grounded proposal" do
      expect(validate(shape, valid)).to be_conforms
    end

    it "refuses an observation with no session" do
      expect(paths(validate(shape, valid.merge("session_id" => nil)))).to include("session_id")
    end

    it "refuses a whitespace-only title" do
      expect(paths(validate(shape, valid.merge("title" => "   ")))).to include("title")
    end

    # MIND proposes; BACK commits. Committing makes a proposal durable, not true.
    it "refuses a proposal that stamps its own status" do
      expect(paths(validate(shape, valid.merge("status" => "accepted")))).to include("status")
    end

    it "refuses a proposal that supplies its own grounding generation" do
      expect(paths(validate(shape, valid.merge("groundedIn" => 99)))).to include("groundedIn")
    end
  end

  describe "P1::SessionContextPullShape" do
    let(:shape) { "P1::SessionContextPullShape" }

    it "accepts a scoped, bounded read" do
      expect(validate(shape, "session_id" => 1, "limit" => 60)).to be_conforms
    end

    it "accepts an absent limit -- BACK supplies the bound" do
      expect(validate(shape, "session_id" => 1)).to be_conforms
    end

    it "refuses an unscoped read" do
      expect(paths(validate(shape, "limit" => 10))).to include("session_id")
    end

    it "refuses an unbounded read" do
      expect(paths(validate(shape, "session_id" => 1, "limit" => 100_000))).to include("limit")
    end

    it "refuses a caller-supplied query -- scoping is BACK's to decide" do
      expect(paths(validate(shape, "session_id" => 1, "sparql" => "SELECT * WHERE {?s ?p ?o}")))
        .to include("sparql")
    end
  end

  describe "P1::SessionCloseEffectShape" do
    it "accepts a named close and refuses an unnamed one" do
      expect(validate("P1::SessionCloseEffectShape", "operationId" => "op", "session_id" => 1)).to be_conforms
      expect(paths(validate("P1::SessionCloseEffectShape", "operationId" => "op"))).to include("session_id")
    end
  end

  describe "the unimplemented-shape default" do
    # THE CASE THAT MATTERS is a shape REGISTERED IN THE CATALOG with no runtime
    # case. An unknown name already failed closed down the KeyError path, so the
    # fail-open default was invisible there; it bit exactly where a name had been
    # added to the catalog and the operation therefore looked gated.
    around do |ex|
      previous = RailsOsiLevel8.config.profile_catalog
      entry = RailsOsiLevel8::ProfileCatalog::Entry.new(
        "osi-l8/p1/cyborg-channel@1", Pathname("unused.ttl"),
        "https://example.org/RegisteredButUnimplementedShape", "deadbeef",
        "P1::RegisteredButUnimplementedShape", "unsigned",
        "test covers"
      )
      RailsOsiLevel8.config.profile_catalog =
        RailsOsiLevel8::ProfileCatalog.new({ "P1::RegisteredButUnimplementedShape" => entry })
      ex.run
      RailsOsiLevel8.config.profile_catalog = previous
    end

    it "REFUSES a registered shape that has no runtime check rather than passing it" do
      r = validate("P1::RegisteredButUnimplementedShape", "anything" => 1)
      expect(r).not_to be_conforms
      expect(r.violations.first[:message]).to match(/no runtime closed-shape check/)
    end

  end

  describe "shapes that DO have checks" do
    it "still admits them" do
      expect(validate("P1::NoteListPullShape", {})).to be_conforms
      expect(validate("P1::SessionLatestPullShape", {})).to be_conforms
    end

    it "refuses session.latest asking for a specific session" do
      expect(paths(validate("P1::SessionLatestPullShape", "session_id" => 1))).to include("session_id")
    end
  end
  # RESPONSE shapes -- what BACK guarantees it answered.
  #
  # pull! validates { "@id", "items" => [result] }, so these are written against
  # the nested document. A response shape written against the top level would
  # read nothing and pass, which is how all five of these used to behave.
  describe "response shapes" do
    def resp(item) = { "@id" => "cid-1", "items" => [item] }

    describe "P1::SessionContextContextShape (ENFORCED -- pull)" do
      let(:shape) { "P1::SessionContextContextShape" }
      let(:good) { { "session_iri" => "urn:mm:session:1", "generation" => 3, "state" => "open", "rows" => [] } }

      it "accepts what SessionCycle.context actually returns" do
        expect(validate(shape, resp(good))).to be_conforms
      end

      it "refuses a reading that cannot name its ground" do
        expect(paths(validate(shape, resp(good.reject { |k, _| k == "generation" })))).to include("generation")
      end

      it "refuses a state outside the closed vocabulary" do
        expect(paths(validate(shape, resp(good.merge("state" => "wat"))))).to include("state")
      end

      it "refuses a document carrying no item at all" do
        expect(paths(validate(shape, { "@id" => "cid-1" }))).to include("items")
      end
    end

    describe "P1::SessionLatestContextShape (ENFORCED -- pull)" do
      let(:shape) { "P1::SessionLatestContextShape" }
      let(:good) { { "session_iri" => "urn:mm:session:1", "actor_kind" => "agent", "generation" => 0, "state" => "open" } }

      it "accepts what SessionCycle.latest actually returns" do
        expect(validate(shape, resp(good))).to be_conforms
      end

      it "accepts generation zero -- a session opens at 0, which is not blank" do
        expect(validate(shape, resp(good.merge("generation" => 0)))).to be_conforms
      end

      it "refuses an actor kind nothing downstream can read" do
        expect(paths(validate(shape, resp(good.merge("actor_kind" => "robot"))))).to include("actor_kind")
      end
    end

    # Live since push! learned to validate its response. Before that these were
    # wired, catalogued and never consulted.
    describe "PUSH response shapes" do
      it "open refuses a response that claims a proof the pod cannot produce" do
        good = { "session_iri" => "urn:mm:session:1", "generation" => 0, "actor_proven" => false }
        expect(validate("P1::SessionOpenContextShape", resp(good))).to be_conforms
        expect(paths(validate("P1::SessionOpenContextShape", resp(good.merge("actor_proven" => true))))).to include("actor_proven")
      end

      it "observe refuses a receipt with no minted subject" do
        good = { "subject" => "urn:mm:session:1:observation:ab", "generation" => 2 }
        expect(validate("P1::SessionObserveContextShape", resp(good))).to be_conforms
        expect(paths(validate("P1::SessionObserveContextShape", resp(good.reject { |k, _| k == "subject" })))).to include("subject")
      end

      it "close refuses a close that did not close" do
        good = { "state" => "closed", "closed_at" => "2026-08-29T00:00:00Z" }
        expect(validate("P1::SessionCloseContextShape", resp(good))).to be_conforms
        expect(paths(validate("P1::SessionCloseContextShape", resp(good.merge("state" => "open"))))).to include("state")
      end
    end
  end

  # Note response shapes. These returned [] until push! learned to validate its
  # response; the TTL said so out loud ("Grounding enforces none -- stated here
  # so the silence is legible"), which made it a documented decision rather than
  # an oversight. It stopped being harmless once the check actually ran.
  describe "note response shapes" do
    def one(item) = { "@id" => "cid-1", "items" => [item] }
    def many(items) = { "@id" => "cid-1", "items" => items }
    def paths(result) = result.violations.map { |v| v[:path] }
    def validate(shape, params) = RailsOsiLevel8::Grounding.validate(params, profile: shape)

    describe "P1::NoteCreateContextShape" do
      let(:shape) { "P1::NoteCreateContextShape" }
      let(:good) { { "@id" => "https://x/note/1", "id" => 1, "title" => "t", "body" => nil } }

      it "accepts what Note#as_api returns" do
        expect(validate(shape, one(good))).to be_conforms
      end

      it "refuses a created note that did not report the title it was stored with" do
        expect(paths(validate(shape, one(good.merge("title" => ""))))).to include("title")
      end

      it "refuses a note with no id" do
        expect(paths(validate(shape, one(good.reject { |k, _| k == "id" })))).to include("id")
      end
    end

    describe "P1::NoteListContextShape" do
      let(:shape) { "P1::NoteListContextShape" }
      let(:note) { { "@id" => "https://x/note/1", "id" => 1, "title" => "t" } }

      # THE CASE THAT MATTERS. note.list is result: :collection and an empty list
      # is what "no notes yet" looks like. A shape that required at least one
      # would refuse a correct response on a fresh pod.
      it "accepts an EMPTY list -- zero notes is a valid answer" do
        expect(validate(shape, many([]))).to be_conforms
      end

      it "accepts many notes" do
        expect(validate(shape, many([note, note.merge("id" => 2)]))).to be_conforms
      end

      it "refuses when any single entry cannot identify itself" do
        expect(paths(validate(shape, many([note, { "title" => "no id" }])))).to include("id")
      end

      it "refuses a response that is not a list at all" do
        expect(paths(validate(shape, { "@id" => "cid-1" }))).to include("id")
      end
    end
  end

end

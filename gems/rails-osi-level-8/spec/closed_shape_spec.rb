# frozen_string_literal: true

require "spec_helper"
require "pathname"

# ADR 0042: where TTL declares sh:closed true, Grounding refuses undeclared keys.
#
# Envelope keys enumerated from profile-1-cyborg-channel.ttl, not from memory:
#   cpcp:operationId, cpcp:idempotencyScope, cpcp:callerIri
# (plus the shape's own paths). Adapter-injected @id must still admit.
# ADR 0042b: the skip is that one key, not every @-prefixed name.
RSpec.describe "ADR 0042 closed-shape allow-lists" do
  before do
    root = Pathname(File.expand_path("../data/osi-level-8", __dir__))
    RailsOsiLevel8.configure do |c|
      c.shape_root = root
      c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(root)
    end
  end

  def validate(shape, params)
    RailsOsiLevel8::Grounding.validate(params, profile: shape)
  end

  def paths(result) = result.violations.map { |v| v[:path] }
  def constraints(result) = result.violations.map { |v| v[:constraint] }

  # Full realistic note.create envelope the seam actually carries.
  # Adapter injects @id only (CpcpAdapter.call). cid is not injected.
  let(:note_create_envelope) do
    {
      "@id" => "cid:sha256:test-request",
      "title" => "hi",
      "body" => "optional body",
      "operationId" => "op-1",
      "idempotencyKey" => "op-1",
      "idempotencyScope" => "default",
      "callerIri" => "https://ex/caller"
    }
  end

  describe "P1::NoteCreateEffectShape" do
    let(:shape) { "P1::NoteCreateEffectShape" }

    it "admits a full realistic envelope (operationId + idempotencyScope + callerIri + body + @id)" do
      r = validate(shape, note_create_envelope)
      expect(r.conforms?).to be(true), r.violations.inspect
    end

    it "admits title+idempotency without optional body" do
      r = validate(shape, note_create_envelope.reject { |k, _| k == "body" })
      expect(r.conforms?).to be(true)
    end

    # REGRESSION (admit -> refuse). Previously Closed-ish: required title/key,
    # refused ledgerPlacement, admitted anything else.
    it "refuses an undeclared key that previously admitted" do
      r = validate(shape, note_create_envelope.merge("smuggled" => "nope"))
      expect(r.conforms?).to be(false)
      expect(paths(r)).to include("smuggled")
      expect(constraints(r)).to include("ClosedConstraintComponent")
    end

    it "still refuses client-supplied ledgerPlacement (declared, maxCount 0)" do
      r = validate(shape, note_create_envelope.merge("ledgerPlacement" => "private_local"))
      expect(r.conforms?).to be(false)
      expect(paths(r)).to include("ledgerPlacement")
    end

    # ADR 0042b. Before: any @-prefixed key admitted (start_with?("@")).
    # After: only the named skip (@id) admits; @evil refuses.
    it "refuses an attacker-chosen @-prefixed key that 0042 admitted" do
      r = validate(shape, note_create_envelope.merge("@evil" => "nope"))
      expect(r.conforms?).to be(false)
      expect(paths(r)).to include("@evil")
      expect(constraints(r)).to include("ClosedConstraintComponent")
    end

    # FINDING: 0042 skipped cid. Adapter does not inject cid. Do not put it back.
    it "refuses client-supplied cid — not adapter-injected, not a TTL path" do
      r = validate(shape, note_create_envelope.merge("cid" => "cid:smuggled"))
      expect(r.conforms?).to be(false)
      expect(paths(r)).to include("cid")
    end
  end

  describe "P4::NoteCreateEffectShape (same allow-list as P1)" do
    it "admits the envelope and refuses an undeclared key" do
      shape = "P4::NoteCreateEffectShape"
      expect(validate(shape, note_create_envelope).conforms?).to be(true)
      r = validate(shape, note_create_envelope.merge("extra" => 1))
      expect(r.conforms?).to be(false)
      expect(paths(r)).to include("extra")
    end
  end

  describe "P1::NoteListPullShape" do
    let(:shape) { "P1::NoteListPullShape" }

    it "admits empty params -- every declared filter is optional" do
      expect(validate(shape, {}).conforms?).to be(true)
    end

    it "admits the declared envelope keys as optional filters" do
      r = validate(shape, {
        "@id" => "cid:list",
        "operationId" => "op-list",
        "idempotencyKey" => "op-list",
        "idempotencyScope" => "default",
        "callerIri" => "https://ex/caller"
      })
      expect(r.conforms?).to be(true), r.violations.inspect
    end

    # REGRESSION (admit -> refuse). "Optional filters" does not mean undeclared
    # keys are welcome. title looks like a list filter; it is not declared.
    it "refuses an undeclared title filter that previously admitted" do
      r = validate(shape, { "title" => "x" })
      expect(r.conforms?).to be(false)
      expect(paths(r)).to include("title")
      expect(constraints(r)).to include("ClosedConstraintComponent")
    end
  end

  describe "P1::SessionObserveEffectShape (NOT sh:closed)" do
    let(:shape) { "P1::SessionObserveEffectShape" }
    let(:valid) { { "operationId" => "op-1", "session_id" => 1, "title" => "a reading" } }

    it "admits optional body" do
      expect(validate(shape, valid.merge("body" => "notes")).conforms?).to be(true)
    end

    it "still admits an undeclared key -- this shape is not closed" do
      expect(validate(shape, valid.merge("smuggled" => "ok")).conforms?).to be(true)
    end
  end
end

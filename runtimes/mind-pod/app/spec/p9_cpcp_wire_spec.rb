# frozen_string_literal: true

require "spec_helper"
require "json"

# P9.7 — JSON-RPC-LD wire contract for every ux.* op over POST /_cpcp/rpc.
# Happy path + one typed refusal per op. HTTP 200 always (never-raise).
RSpec.describe "P9.7 CPCP wire contract (POST /_cpcp/rpc)" do
  include Rack::Test::Methods
  def app = Rails.application

  def g = RailsOsiLevel8::Profile9::Graph

  def wire(method, params = {}, opid: nil, rpc_id: "wire-1")
    body = { "jsonrpc" => "2.0", "id" => rpc_id, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body)
  end

  def expect_ld_ok(env, rpc_id:, collection: false)
    expect(env["jsonrpc"]).to eq("2.0")
    expect(env["@context"]).to be_a(Hash)
    expect(env["@context"]["@vocab"]).to be_present
    expect(env["id"]).to eq(rpc_id)
    expect(env["ok"]).to be(true)
    expect(env).to have_key("result")
    expect(env).not_to have_key("error")
    expect(env["result"]).to have_key("@graph") if collection
  end

  def expect_ld_fail(env, rpc_id:, reason:)
    expect(env["jsonrpc"]).to eq("2.0")
    expect(env["@context"]).to be_a(Hash)
    expect(env["@context"]["@vocab"]).to be_present
    expect(env["id"]).to eq(rpc_id)
    expect(env["ok"]).to be(false)
    expect(env.dig("error", "reason")).to eq(reason)
    expect(env["error"]).to have_key("because")
    expect(env).not_to have_key("result")
  end

  before { g.reset! }

  it "lists every ux.* operation at GET /_cpcp/up" do
    get "/_cpcp/up"
    expect(last_response.status).to eq(200)
    names = JSON.parse(last_response.body)["operations"]
    RailsOsiLevel8::Profile9::Vocabulary.operation_names.each do |name|
      expect(names).to include(name)
    end
  end

  it "ux.profile.describe happy + extra-key refusal" do
    ok = wire("ux.profile.describe", {}, rpc_id: "d-ok")
    expect_ld_ok(ok, rpc_id: "d-ok")
    expect(ok.dig("result", "profile_id")).to eq("osi-level-8/profile-9")

    bad = wire("ux.profile.describe", { "style" => "color:red" }, rpc_id: "d-bad")
    expect_ld_fail(bad, rpc_id: "d-bad", reason: "UX_UNKNOWN_PREDICATE")
  end

  it "ux.contract.check happy + unknown predicate refusal" do
    ok = wire("ux.contract.check", {
      "graph" => { "cid" => "cid:ok", "profileId" => "osi-level-8/profile-9", "componentKind" => "ContextBanner" }
    }, rpc_id: "c-ok")
    expect_ld_ok(ok, rpc_id: "c-ok")
    expect(ok.dig("result", "conforms")).to be(true)

    bad = wire("ux.contract.check", { "graph" => { "cid" => "cid:x", "arbitraryHtml" => "<div/>" } }, rpc_id: "c-bad")
    expect_ld_fail(bad, rpc_id: "c-bad", reason: "UX_UNKNOWN_PREDICATE")
  end

  it "ux.acia.validate happy + HTML prop refusal" do
    good = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
    ok = wire("ux.acia.validate", { "document" => good }, rpc_id: "a-ok")
    expect_ld_ok(ok, rpc_id: "a-ok")
    expect(ok.dig("result", "conforms")).to be(true)

    bad_doc = Marshal.load(Marshal.dump(good))
    bad_doc["root"]["props"]["valueJson"]["html"] = "<div/>"
    bad = wire("ux.acia.validate", { "document" => bad_doc }, rpc_id: "a-bad")
    expect_ld_fail(bad, rpc_id: "a-bad", reason: RailsOsiLevel8::Profile9::Vocabulary::REFUSAL_CODES[:acia_contract_invalid])
  end

  it "ux.render happy + missing acia refusal" do
    doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
    ok = wire("ux.render", {
      "bundle" => {
        "aciaDocument" => doc,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set,
        "correlationId" => "w",
        "receiptSeed" => "w"
      }
    }, rpc_id: "r-ok")
    expect_ld_ok(ok, rpc_id: "r-ok")
    expect(ok.dig("result", "receipt", "receiptKind")).to eq("ux:RenderReceipt")

    bad = wire("ux.render", { "bundle" => {} }, rpc_id: "r-bad")
    expect_ld_fail(bad, rpc_id: "r-bad", reason: "UX_ENVELOPE_INVALID")
  end

  it "ux.journey.list happy collection + unknown actor refusal" do
    ok = wire("ux.journey.list", { "actorCid" => g::ACTOR_CID }, rpc_id: "jl-ok")
    expect_ld_ok(ok, rpc_id: "jl-ok", collection: true)
    expect(ok.dig("result", "@graph").map { |j| j["cid"] }).to include(g::JOURNEY_CID)

    bad = wire("ux.journey.list", { "actorCid" => "cid:actor:missing" }, rpc_id: "jl-bad")
    expect_ld_fail(bad, rpc_id: "jl-bad", reason: "UX_LINEAGE_UNRESOLVED")
  end

  it "ux.journey.get happy + unknown journey refusal" do
    ok = wire("ux.journey.get", { "journeyCid" => g::JOURNEY_CID }, rpc_id: "jg-ok")
    expect_ld_ok(ok, rpc_id: "jg-ok")
    expect(ok.dig("result", "cid")).to eq(g::JOURNEY_CID)

    bad = wire("ux.journey.get", { "journeyCid" => "cid:journey:missing" }, rpc_id: "jg-bad")
    expect_ld_fail(bad, rpc_id: "jg-bad", reason: "UX_LINEAGE_UNRESOLVED")
  end

  it "ux.flow.get happy + unknown request key refusal" do
    ok = wire("ux.flow.get", { "flowCid" => g::FLOW_CID }, rpc_id: "fg-ok")
    expect_ld_ok(ok, rpc_id: "fg-ok")
    expect(ok.dig("result", "cid")).to eq(g::FLOW_CID)

    bad = wire("ux.flow.get", { "flowCid" => g::FLOW_CID, "innerHTML" => "<x/>" }, rpc_id: "fg-bad")
    expect_ld_fail(bad, rpc_id: "fg-bad", reason: "UX_UNKNOWN_PREDICATE")
  end

  it "ux.page.get happy + unknown page refusal" do
    ok = wire("ux.page.get", {
      "pageCid" => g::PAGE_CID, "correlationId" => "w", "receiptSeed" => "w"
    }, rpc_id: "pg-ok")
    expect_ld_ok(ok, rpc_id: "pg-ok")
    expect(ok.dig("result", "@type")).to eq("ux:PageRenderBundle")

    bad = wire("ux.page.get", { "pageCid" => "cid:page:missing" }, rpc_id: "pg-bad")
    expect_ld_fail(bad, rpc_id: "pg-bad", reason: "UX_LINEAGE_UNRESOLVED")
  end

  it "ux.token.get happy + unknown tokenSet refusal" do
    ok = wire("ux.token.get", {}, rpc_id: "tg-ok")
    expect_ld_ok(ok, rpc_id: "tg-ok")
    expect(ok.dig("result", "cid")).to eq(g::TOKEN_SET_CID)

    bad = wire("ux.token.get", { "tokenSetCid" => "cid:tokens:missing" }, rpc_id: "tg-bad")
    expect_ld_fail(bad, rpc_id: "tg-bad", reason: "UX_LINEAGE_UNRESOLVED")
  end

  it "ux.token.set happy successor + contrast refusal (PUSH)" do
    pred = wire("ux.token.get", {}, rpc_id: "ts-pred")
    cid = pred.dig("result", "cid")
    digest = pred.dig("result", "digest")

    bad = wire("ux.token.set", {
      "predecessorCid" => cid,
      "predecessorDigest" => digest,
      "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "#eee" } }
    }, opid: "p97-ts-bad-#{SecureRandom.hex(3)}", rpc_id: "ts-bad")
    expect_ld_fail(bad, rpc_id: "ts-bad", reason: "UX_DESIGN_GROUNDING_FAILED")

    ok = wire("ux.token.set", {
      "predecessorCid" => cid,
      "predecessorDigest" => digest,
      "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "#000000" } }
    }, opid: "p97-ts-ok-#{SecureRandom.hex(3)}", rpc_id: "ts-ok")
    expect_ld_ok(ok, rpc_id: "ts-ok")
    expect(ok.dig("result", "accepted")).to be(true)
  end

  it "ux.acia.mutate.propose happy successor + HTML refusal (PUSH)" do
    page = wire("ux.page.get", {
      "pageCid" => g::PAGE_CID, "correlationId" => "w", "receiptSeed" => "w"
    }, rpc_id: "am-page")
    pred_cid = g.active_acia_cid
    pred = g.acia_doc(pred_cid)

    bad_doc = Marshal.load(Marshal.dump(page.dig("result", "aciaDocument")))
    bad_doc["root"]["props"]["valueJson"]["html"] = "<div/>"
    bad = wire("ux.acia.mutate.propose", {
      "predecessorCid" => pred_cid,
      "predecessorDigest" => pred["digest"],
      "successor" => bad_doc
    }, opid: "p97-am-bad-#{SecureRandom.hex(3)}", rpc_id: "am-bad")
    expect_ld_fail(bad, rpc_id: "am-bad", reason: RailsOsiLevel8::Profile9::Vocabulary::REFUSAL_CODES[:acia_contract_invalid])

    good = Marshal.load(Marshal.dump(page.dig("result", "aciaDocument")))
    good["root"]["props"]["valueJson"]["title"] = "Governance (wire)"
    ok = wire("ux.acia.mutate.propose", {
      "predecessorCid" => pred_cid,
      "predecessorDigest" => pred["digest"],
      "successor" => good
    }, opid: "p97-am-ok-#{SecureRandom.hex(3)}", rpc_id: "am-ok")
    expect_ld_ok(ok, rpc_id: "am-ok")
    expect(ok.dig("result", "accepted")).to be(true)
  end

  it "ux.interaction.record happy context_presented + missing receipt refusal (PUSH)" do
    page = wire("ux.page.get", {
      "pageCid" => g::PAGE_CID, "correlationId" => "corr-p97", "receiptSeed" => "seed-p97"
    }, rpc_id: "ix-page")
    rendered = wire("ux.render", { "bundle" => page["result"] }, rpc_id: "ix-render")
    receipt = rendered.dig("result", "receipt")

    ok = wire("ux.interaction.record", {
      "eventKind" => "context_presented",
      "receipt" => receipt,
      "receiptCid" => receipt["cid"],
      "aciaDocumentDigest" => receipt["aciaDigest"],
      "tokenSetDigest" => receipt["tokenDigest"],
      "pageCid" => g::PAGE_CID
    }, opid: "p97-ix-ok-#{SecureRandom.hex(3)}", rpc_id: "ix-ok")
    expect_ld_ok(ok, rpc_id: "ix-ok")
    expect(ok.dig("result", "eventKind")).to eq("context_presented")

    bad = wire("ux.interaction.record", {
      "eventKind" => "context_presented",
      "aciaDocumentDigest" => "sha256:#{'0' * 64}",
      "tokenSetDigest" => "sha256:#{'0' * 64}"
    }, opid: "p97-ix-bad-#{SecureRandom.hex(3)}", rpc_id: "ix-bad")
    expect_ld_fail(bad, rpc_id: "ix-bad", reason: "UX_ENVELOPE_INVALID")
  end

  it "PUSH ux.token.set without operationId is a JSON-RPC-LD refusal" do
    bad = wire("ux.token.set", {
      "predecessorCid" => g::TOKEN_SET_CID,
      "predecessorDigest" => "sha256:#{'0' * 64}"
    }, rpc_id: "push-noid")
    expect_ld_fail(bad, rpc_id: "push-noid", reason: "operation_id_required")
    expect(bad.dig("error", "because")).to be_a(String)
  end
end

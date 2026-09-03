# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ROLE=persist v1 (row 8)" do
  include Rack::Test::Methods
  def app = Rails.application

  CALLERS = {
    "op" => { "token" => "persist-op-token", "operations" => %w[set get] },
    "ro" => { "token" => "persist-ro-token", "operations" => %w[get] }
  }.freeze

  def with_role(role)
    previous = Rails.application.config.x.role
    Rails.application.config.x.role = role
    Rails.application.reload_routes!
    yield
  ensure
    Rails.application.config.x.role = previous
    Rails.application.reload_routes!
  end

  def with_callers
    previous = ENV["PERSIST_CALLERS"]
    ENV["PERSIST_CALLERS"] = JSON.generate(CALLERS)
    yield
  ensure
    ENV["PERSIST_CALLERS"] = previous
  end

  def rpc(method, params = {}, token: "persist-op-token")
    header = token ? { "HTTP_AUTHORIZATION" => "Bearer #{token}" } : {}
    post "/_cpcp/rpc",
         JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }),
         { "CONTENT_TYPE" => "application/json" }.merge(header)
  end

  it "writes PersistPlacement and not Note" do
    expect(DomainWriters.allowed_class?("PersistPlacement", "persist")).to be(true)
    expect(DomainWriters.allowed_class?("Note", "persist")).to be(false)
    expect(DomainWriters.allowed_class?("PersistPlacement", "backjob")).to be(false)
  end

  it "records a closed-set placement and reads it back, never live" do
    with_role("persist") do
      with_callers do
        rpc("persist.path.set", { "store" => "domain", "path" => "/data/mind_pod.sqlite3" })
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["ok"]).to be(true)
        expect(body["result"]["store"]).to eq("domain")
        expect(body["result"]["live_applied"]).to be(false)
        expect(body["result"]["effective"]).to eq("next_boot")
        expect(PersistPlacement.count).to eq(1)

        rpc("persist.path.get", { "store" => "domain" })
        expect(last_response.status).to eq(200)
        got = JSON.parse(last_response.body)
        expect(got["result"]["recorded"]).to be(true)
        expect(got["result"]["path"]).to eq("/data/mind_pod.sqlite3")

        rpc("persist.path.get", { "store" => "mind" })
        missing = JSON.parse(last_response.body)
        expect(missing["result"]["recorded"]).to be(false)
      end
    end
  end

  it "refuses unknown stores, open-set paths, and bad auth with non-200 plus envelope" do
    with_role("persist") do
      with_callers do
        rpc("persist.path.set", { "store" => "vault", "path" => "/data/mind_pod.sqlite3" })
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["reason"]).to eq("unknown_store")

        rpc("persist.path.set", { "store" => "domain", "path" => "/tmp/evil.sqlite3" })
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["reason"]).to eq("unknown_path")

        rpc("note.create", { "title" => "no" })
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["reason"]).to eq("unknown_operation")

        rpc("persist.path.get", { "store" => "domain" }, token: "persist-ro-token")
        expect(last_response.status).to eq(200)

        rpc("persist.path.set", { "store" => "domain", "path" => "/data/mind_pod.sqlite3" }, token: "persist-ro-token")
        expect(last_response.status).to eq(403)
        expect(JSON.parse(last_response.body)["reason"]).to eq("persist_forbidden")

        rpc("persist.path.get", { "store" => "domain" }, token: nil)
        expect(last_response.status).to eq(401)
        expect(JSON.parse(last_response.body)["reason"]).to eq("persist_unauthenticated")

        rpc("persist.path.get", { "store" => "domain" }, token: "wrong")
        expect(last_response.status).to eq(401)
      end
    end
  end

  it "fails closed without callers configured" do
    with_role("persist") do
      ENV.delete("PERSIST_CALLERS")
      rpc("persist.path.get", { "store" => "domain" }, token: "x")
      expect(last_response.status).to eq(500)
      expect(JSON.parse(last_response.body)["reason"]).to eq("persist_callers_missing")
    end
  end

  it "does not draw BACK's engine catalog" do
    with_role("persist") do
      expect { Rails.application.routes.recognize_path("/_cpcp/up") }
        .to raise_error(ActionController::RoutingError)
    end
  end

  it "keeps persist_placements in the PERSIST sqlite, not the domain sqlite" do
    expect(PersistRecord.connection.data_source_exists?("persist_placements")).to be(true)
    expect(ApplicationRecord.connection.data_source_exists?("persist_placements")).to be(false)
  end
end

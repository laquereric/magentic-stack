# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ROLE=bus v1 (row 18)" do
  include Rack::Test::Methods
  def app = Rails.application

  def with_role(role)
    previous = Rails.application.config.x.role
    Rails.application.config.x.role = role
    Rails.application.reload_routes!
    yield
  ensure
    Rails.application.config.x.role = previous
    Rails.application.reload_routes!
  end

  def rpc(method, params = {})
    post "/_cpcp/rpc",
         JSON.generate({ "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }),
         "CONTENT_TYPE" => "application/json"
  end

  it "writes BusProjection and not Note" do
    expect(DomainWriters.allowed_class?("BusProjection", "bus")).to be(true)
    expect(DomainWriters.allowed_class?("Note", "bus")).to be(false)
    expect(DomainWriters.allowed_class?("BusProjection", "backjob")).to be(false)
  end

  it "serves bus.projection.latest and refuses unknown methods with non-200 plus envelope" do
    with_role("bus") do
      rpc("bus.projection.latest")
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["ok"]).to be(true)
      expect(body["result"]["source"]).to eq("operation_journal")
      expect(body["result"]["contract_version"]).to eq(Bus::Projector::CONTRACT_VERSION)
      expect(body["result"]["derived"]).to have_key("count")
      expect(BusProjection.count).to eq(1)

      rpc("note.create", { "title" => "no" })
      expect(last_response.status).to eq(400)
      refused = JSON.parse(last_response.body)
      expect(refused["ok"]).to be(false)
      expect(refused["reason"]).to eq("unknown_operation")
    end
  end

  it "does not draw BACK's engine catalog" do
    with_role("bus") do
      expect { Rails.application.routes.recognize_path("/_cpcp/up") }
        .to raise_error(ActionController::RoutingError)
    end
  end

  it "keeps bus_projections in the BUS sqlite, not the domain sqlite" do
    expect(BusRecord.connection.data_source_exists?("bus_projections")).to be(true)
    expect(ApplicationRecord.connection.data_source_exists?("bus_projections")).to be(false)
  end
end

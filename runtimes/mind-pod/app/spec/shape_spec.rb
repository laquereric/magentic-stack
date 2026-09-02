# frozen_string_literal: true

require "spec_helper"
require "digest"

RSpec.describe "ROLE=shape v1 (ADR 0049)" do
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

  describe ShapeSurface do
    it "groups ProfileCatalog.default by digest and admits it is incomplete" do
      doc = ShapeSurface.document
      expect(doc["ok"]).to be(true)
      expect(doc["incomplete"]).to be(true)
      expect(doc["unmigrated"]).to eq(52)
      because = doc["incomplete_because"].join(" ")
      expect(because).to include("P2-P8")
      expect(because).to include("P10")
      expect(because).to include("contextframe")
      expect(because).to include("osi-level-8-profiles")
      expect(because).not_to include("shapes-level-8 is not in SHAPE_MAP")
      paths = doc["shapes"].map { |s| "#{s["gem"]}/#{s["path"]}" }
      basenames = doc["shapes"].map { |s| File.basename(s["path"].to_s) }
      expect(basenames).to include(
        "profile-1-cyborg-channel.ttl",
        "profile-4-durable-execution.ttl",
        "session-operations.shacl.ttl",
        "profile-9-ghis.ttl",
        "profile-11-meaning.ttl"
      )
      expect(basenames).not_to include("contextframe.shacl.ttl")
      expect(paths.join).not_to include("contextframe")
      expect(doc["shapes"].map { |s| s["gem"] }).to all(be_present)
      expect(doc["shapes"]).not_to be_empty
      doc["shapes"].each do |s|
        expect(s["digest"]).to match(/\Asha256:[0-9a-f]{64}\z/)
        expect(s["retrieval"]).to eq("/_cpcp/shapes/#{s["digest"]}")
        expect(s["rdf_iri"]).not_to be_empty
        expect(s["shape_names"]).not_to be_empty
      end
    end

    it "EMPTY is ok:false (empty catalog answering ok:true is the failure mode)" do
      expect(ShapeSurface::EMPTY["ok"]).to be(false)
      expect(ShapeSurface::EMPTY["reason"]).to eq("shape_catalog_empty")
      expect(ShapeSurface::EMPTY["because"]["offender"]).to eq("ProfileCatalog.default")
      empty_cat = RailsOsiLevel8::ProfileCatalog.new({})
      doc = ShapeSurface.document(empty_cat)
      expect(doc["ok"]).to be(false)
      expect(doc["reason"]).to eq("shape_catalog_empty")
      expect(doc["shapes"]).to eq([])
    end

    it "returns TTL bytes for a known digest and nil on mismatch" do
      rec = ShapeSurface.new.files.first
      hex = rec["digest"].delete_prefix("sha256:")
      bytes = ShapeSurface.new.turtle(hex)
      expect(bytes).not_to be_nil
      expect(Digest::SHA256.hexdigest(bytes)).to eq(hex)
      expect(ShapeSurface.new.turtle("0" * 64)).to be_nil
      expect(ShapeSurface.new.turtle("not-a-digest")).to be_nil
    end
  end

  describe "ROLE-gated routes" do
    it "SHAPE serves GET retrieval and does not draw note.create or POST rpc" do
      with_role("shape") do
        get "/_cpcp/up"
        expect(last_response.status).to eq(200)
        up = JSON.parse(last_response.body)
        expect(up["ok"]).to be(true)
        expect(up["role"]).to eq("shape")
        expect(up["operations"]).to eq([])
        expect(up["operations"]).not_to include("note.create")
        expect(up["artifacts"]).not_to be_empty

        get "/_cpcp/shapes.json"
        expect(last_response.status).to eq(200)
        cat = JSON.parse(last_response.body)
        expect(cat["ok"]).to be(true)
        expect(cat["incomplete"]).to be(true)
        expect(cat["shapes"]).not_to be_empty

        rec = cat["shapes"].first
        get rec["retrieval"]
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include("text/turtle")
        expect(Digest::SHA256.hexdigest(last_response.body)).to eq(
          rec["digest"].delete_prefix("sha256:")
        )

        get "/_cpcp/shapes/sha256:#{'0' * 64}"
        expect(last_response.status).to eq(404)

        expect { Rails.application.routes.recognize_path("/_cpcp/rpc", method: :post) }
          .to raise_error(ActionController::RoutingError)
        expect { Rails.application.routes.recognize_path("/_cpcp/cid.json") }
          .to raise_error(ActionController::RoutingError)
        expect { Rails.application.routes.recognize_path("/notes", method: :post) }
          .to raise_error(ActionController::RoutingError)
      end
    end

    it "BACK still serves /_cpcp and still does not draw the shape catalog as operations" do
      with_role("back") do
        get "/_cpcp/up"
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["operations"]).to include("note.create")
        get "/_cpcp/shapes.json"
        expect(last_response.status).to eq(404)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe Vv::CodeRepo do
  def sha
    "sha256:" + ("a" * 64)
  end

  describe "the catalog operations" do
    it "declares the procedure.* surface" do
      expect(Vv::CodeRepo::Operations.names).to include(
        "procedure.put", "procedure.serve", "procedure.promote", "procedure.bind"
      )
    end
  end

  describe "land" do
    it "accepts a digest-named bronze revision" do
      r = Vv::CodeRepo::Catalog.land("slug" => "shape.render.ghis-19", "digest" => sha)
      expect(r[:ok]).to be(true)
      expect(r[:tier]).to eq("bronze")
    end

    it "refuses graph_iri" do
      r = Vv::CodeRepo::Catalog.land("digest" => sha, "graph_iri" => "urn:ex:p")
      expect(r[:reason]).to eq("graph_iri_refused")
    end

    it "refuses a non-digest name" do
      r = Vv::CodeRepo::Catalog.land("digest" => "cid:acia:abc")
      expect(r[:reason]).to eq("blob_digest_required")
    end

    it "refuses html as source" do
      r = Vv::CodeRepo::Catalog.land("digest" => sha, "html_as_source" => "true")
      expect(r[:reason]).to eq("html_as_source_refused")
    end

    it "refuses platinum as a tier" do
      r = Vv::CodeRepo::Catalog.land("digest" => sha, "tier" => "platinum")
      expect(r[:reason]).to eq("platinum_not_a_tier")
    end
  end

  describe "bind / serve / promote" do
    it "binds ruby for FRONT" do
      r = Vv::CodeRepo::Catalog.bind("language" => "ruby", "digest" => sha, "role" => "front")
      expect(r[:ok]).to be(true)
    end

    it "refuses python for FRONT" do
      r = Vv::CodeRepo::Catalog.bind("language" => "python", "digest" => sha, "role" => "front")
      expect(r[:reason]).to eq("binding_not_for_role")
    end

    it "serve is Gold only" do
      expect(Vv::CodeRepo::Catalog.serve("tier" => "bronze", "gold_digest" => sha)[:reason])
        .to eq("gold_only")
      expect(Vv::CodeRepo::Catalog.serve("gold_digest" => sha, "slug" => "shape.render.ghis-19")[:ok])
        .to be(true)
    end

    it "promote refuses without the DEV grant" do
      r = Vv::CodeRepo::Catalog.promote(
        "silver_digest" => sha, "contract" => "c", "recommend" => true,
        "linkml_in" => sha, "linkml_out" => sha, "PROCEDURE_WRITE" => "0"
      )
      expect(r[:reason]).to eq("prod_write_refused")
    end

    it "promote accepts with grant, contract, recommend, LinkML" do
      r = Vv::CodeRepo::Catalog.promote(
        "slug" => "shape.render.ghis-19", "silver_digest" => sha,
        "contract" => "c1", "recommend" => true,
        "linkml_in" => sha, "linkml_out" => sha, "PROCEDURE_WRITE" => "1"
      )
      expect(r[:ok]).to be(true)
      expect(r[:gold_digest]).to eq(sha)
    end
  end

  describe "first application slugs" do
    it "names the SHAPE renderers" do
      expect(Vv::CodeRepo::Catalog::FIRST_SLUGS).to include(
        "shape.render.ghis-19", "shape.render.ghis-20", "shape.render.ghis-21",
        "shape.emit.a2ui-0.9.1"
      )
    end
  end

  describe "absence" do
    it "does not grow ActiveRecord or DuckDB" do
      sources = Dir[File.expand_path("../lib/**/*.rb", __dir__)]
      blob = sources.map { |p| File.read(p) }.join
      expect(blob).not_to match(/ActiveRecord::Base/)
      expect(blob).not_to match(/require ["']duckdb["']/)
      expect(blob).not_to match(/class ProcedureEval/)
    end
  end

  describe "CPCP" do
    it "refuses to register without rails-cpcp" do
      r = Vv::CodeRepo::Cpcp.register!
      expect(r[:ok]).to be(false)
      expect(r[:reason].to_s).to eq("cpcp_absent")
    end
  end

  describe "refusal vocabulary" do
    it "is closed" do
      r = Vv::CodeRepo::Refusal.build("vibes", "nope")
      expect(r[:reason]).to eq("audit_rejected")
      expect(r[:because]).to include("unregistered refusal")
    end
  end
end

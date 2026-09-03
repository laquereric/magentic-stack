# frozen_string_literal: true

require "spec_helper"
require "json"

# Gap 5. ROLE=config is vault's first caller. put+list only. A non-200
# body is kept (gap 104).
RSpec.describe ConfigAdmin do
  describe ConfigAdmin::Boot do
    it "fails closed naming every missing required env, including the pod default secret" do
      expect { ConfigAdmin::Boot.required!({}) }.to raise_error(ConfigAdmin::Boot::Error) { |e|
        expect(e.reason).to eq("config_boot_refused")
        expect(e.because["missing"]).to include("VAULT_URL", "VAULT_TOKEN", "PERSIST_URL", "PERSIST_TOKEN", "SWITCH_UI_URL", "SECRET_KEY_BASE")
      }
      env = {
        "VAULT_URL" => "http://vault:3000",
        "VAULT_TOKEN" => "tok-admin",
        "PERSIST_URL" => "http://persist:3000",
        "PERSIST_TOKEN" => "tok-persist",
        "SWITCH_UI_URL" => "http://switch:8790",
        "SECRET_KEY_BASE" => "mind-pod-not-a-secret",
      }
      expect { ConfigAdmin::Boot.required!(env) }.to raise_error(ConfigAdmin::Boot::Error) { |e|
        expect(e.because["missing"]).to eq(["SECRET_KEY_BASE"])
      }
    end

    it "accepts a complete env" do
      env = {
        "VAULT_URL" => "http://vault:3000",
        "VAULT_TOKEN" => "tok-admin",
        "PERSIST_URL" => "http://persist:3000",
        "PERSIST_TOKEN" => "tok-persist",
        "SWITCH_UI_URL" => "http://switch:8790",
        "SECRET_KEY_BASE" => "a-real-secret",
      }
      expect(ConfigAdmin::Boot.required!(env)).to be(true)
    end
  end

  describe ConfigAdmin::VaultClient do
    def stub_http(code, body)
      res = instance_double(Net::HTTPResponse, code: code.to_s, body: JSON.generate(body))
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(res)
      allow(Net::HTTP).to receive(:start).and_yield(http).and_return(res)
      res
    end

    it "lists without issuing get" do
      stub_http(200, { "ok" => true, "result" => { "items" => [{ "name" => "anthropic", "present" => true }] } })
      listed = ConfigAdmin::VaultClient.new(base_url: "http://vault:3000", token: "tok-admin").list
      expect(listed["ok"]).to be(true)
      expect(listed["status"]).to eq(200)
      expect(listed["result"]["items"].first).not_to have_key("value")
    end

    it "keeps reason and because on HTTP 403 (gap 104)" do
      stub_http(403, {
        "ok" => false,
        "reason" => "vault_not_allowlisted",
        "because" => { "caller" => "config-admin", "operation" => "get" },
      })
      listed = ConfigAdmin::VaultClient.new(base_url: "http://vault:3000", token: "tok-admin").list
      expect(listed["status"]).to eq(403)
      expect(listed["ok"]).to be(false)
      expect(listed["reason"]).to eq("vault_not_allowlisted")
      expect(listed["because"]["caller"]).to eq("config-admin")
    end

    it "does not define get as an HTTP method" do
      expect(ConfigAdmin::VaultClient.instance_methods(false)).not_to include(:get)
      expect(ConfigAdmin::VaultClient::ALLOWED.keys).to contain_exactly(
        "vault.secret.put", "vault.secret.list"
      )
    end
  end

  describe ConfigAdmin::PersistClient do
    def stub_http(code, body)
      res = instance_double(Net::HTTPResponse, code: code.to_s, body: JSON.generate(body))
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(res)
      allow(Net::HTTP).to receive(:start).and_yield(http).and_return(res)
      res
    end

    def client
      ConfigAdmin::PersistClient.new(base_url: "http://persist:3000", token: "tok-persist")
    end

    it "gets a placement" do
      stub_http(200, { "ok" => true, "result" => { "store" => "domain", "recorded" => true, "path" => "/data/mind_pod.sqlite3" } })
      got = client.get("domain")
      expect(got["ok"]).to be(true)
      expect(got["status"]).to eq(200)
      expect(got["result"]["path"]).to eq("/data/mind_pod.sqlite3")
    end

    it "sets a placement" do
      stub_http(200, { "ok" => true, "result" => { "store" => "domain", "live_applied" => false } })
      set = client.set("domain", "/data/mind_pod.sqlite3")
      expect(set["ok"]).to be(true)
      expect(set["result"]["live_applied"]).to be(false)
    end

    it "keeps reason and because on HTTP 400 (gap 104)" do
      stub_http(400, {
        "ok" => false,
        "reason" => "unknown_path",
        "because" => { "path" => "/tmp/evil.sqlite3" },
      })
      set = client.set("domain", "/tmp/evil.sqlite3")
      expect(set["status"]).to eq(400)
      expect(set["ok"]).to be(false)
      expect(set["reason"]).to eq("unknown_path")
    end

    it "allowlists exactly set and get" do
      expect(ConfigAdmin::PersistClient::ALLOWED.keys).to contain_exactly(
        "persist.path.set", "persist.path.get"
      )
    end
  end

  describe ConfigAdmin::SwitchClient do
    def stub_http(code, body)
      res = instance_double(Net::HTTPResponse, code: code.to_s, body: JSON.generate(body))
      http = instance_double(Net::HTTP)
      allow(http).to receive(:request).and_return(res)
      allow(Net::HTTP).to receive(:start).and_yield(http).and_return(res)
      res
    end

    def client
      ConfigAdmin::SwitchClient.new(base_url: "http://switch:8790")
    end

    it "reads sources" do
      stub_http(200, { "ok" => true, "result" => { "vendors" => [{ "id" => "openai" }] } })
      got = client.sources
      expect(got["ok"]).to be(true)
      expect(got["status"]).to eq(200)
      expect(got["result"]["vendors"].first["id"]).to eq("openai")
    end

    it "keeps reason and because on HTTP 400 (gap 104)" do
      stub_http(400, { "ok" => false, "reason" => "unknown_model", "because" => {} })
      got = client.test("openai:nope")
      expect(got["status"]).to eq(400)
      expect(got["reason"]).to eq("unknown_model")
    end

    it "allowlists display and trigger paths, never keys" do
      expect(ConfigAdmin::SwitchClient::ALLOWED_PATHS.keys).to contain_exactly(
        "sources", "refresh", "verify-tools", "test"
      )
    end
  end

  describe ConfigAdmin::Catalog do
    let(:catalog) { ConfigAdmin::Catalog.load }

    it "loads the seven vendors from the config-owned JSON" do
      expect(catalog.owned_by).to eq("ROLE=config")
      expect(catalog.vendors.keys).to contain_exactly(
        "ollama", "openai", "anthropic", "fireworks", "openrouter", "nvidia", "meta"
      )
    end

    it "marks the observed tool-call failures false, and leaves OpenRouter prices unknown" do
      ollama = catalog.vendors.fetch("ollama").fetch("models")
      tiny = ollama.find { |m| m["id"] == "llama3.2:1b" }
      small = ollama.find { |m| m["id"] == "qwen2.5:3b" }
      expect(tiny["tools"]).to be(false)
      expect(small["tools"]).to be(false)
      catalog.vendors.fetch("openrouter").fetch("models").each do |m|
        expect(m["id"]).to include("/")
        expect(m["in"]).to be_nil
        expect(m["out"]).to be_nil
      end
    end

    it "does not define get" do
      expect(ConfigAdmin::Catalog.instance_methods(false)).not_to include(:get)
    end
  end

  describe "ROLE-gated routes" do
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

    it "CONFIG serves / and POST /secrets, not /_cpcp and not GET /secrets/:name" do
      ENV["VAULT_URL"] = "http://vault:3000"
      ENV["VAULT_TOKEN"] = "tok-admin"
      with_role("config") do
        expect(Rails.application.routes.recognize_path("/")).to include(controller: "config_admin/secrets")
        expect(Rails.application.routes.recognize_path("/secrets", method: :post)).to include(controller: "config_admin/secrets")
        expect(Rails.application.routes.recognize_path("/catalog")).to include(controller: "config_admin/catalog")
        expect(Rails.application.routes.recognize_path("/placements")).to include(controller: "config_admin/placements")
        expect(Rails.application.routes.recognize_path("/placements", method: :post)).to include(controller: "config_admin/placements")
        expect(Rails.application.routes.recognize_path("/switch")).to include(controller: "config_admin/switch")
        expect(Rails.application.routes.recognize_path("/switch/refresh", method: :post)).to include(controller: "config_admin/switch")
        expect { Rails.application.routes.recognize_path("/_cpcp/up") }.to raise_error(ActionController::RoutingError)
        expect { Rails.application.routes.recognize_path("/secrets/anthropic") }.to raise_error(ActionController::RoutingError)
      end
    ensure
      ENV.delete("VAULT_URL")
      ENV.delete("VAULT_TOKEN")
    end

    it "CONFIG GET /catalog is display-only JSON of the table" do
      ENV["VAULT_URL"] = "http://vault:3000"
      ENV["VAULT_TOKEN"] = "tok-admin"
      with_role("config") do
        get "/catalog.json"
        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["ok"]).to be(true)
        expect(body["owned_by"]).to eq("ROLE=config")
        expect(body["vendors"].keys).to include("ollama", "openrouter")
        expect(body.to_s).not_to match(/state\.keys|vault\.secret\.get/)
      end
    ensure
      ENV.delete("VAULT_URL")
      ENV.delete("VAULT_TOKEN")
    end
  end
end

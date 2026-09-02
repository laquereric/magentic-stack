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
        expect(e.because["missing"]).to include("VAULT_URL", "VAULT_TOKEN", "SECRET_KEY_BASE")
      }
      env = {
        "VAULT_URL" => "http://vault:3000",
        "VAULT_TOKEN" => "tok-admin",
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
        expect { Rails.application.routes.recognize_path("/_cpcp/up") }.to raise_error(ActionController::RoutingError)
        expect { Rails.application.routes.recognize_path("/secrets/anthropic") }.to raise_error(ActionController::RoutingError)
      end
    ensure
      ENV.delete("VAULT_URL")
      ENV.delete("VAULT_TOKEN")
    end
  end
end

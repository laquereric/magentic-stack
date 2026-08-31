# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "vault (ADR 0046)" do
  def callers_json
    JSON.generate({
      "config-admin" => { "token" => "tok-admin", "operations" => %w[put list] },
      "llm-plane" => { "token" => "tok-llm", "operations" => %w[get] }
    })
  end

  def allowlist
    Vault::Allowlist.parse!(callers_json)
  end

  def store_for(dir)
    Vault::Store.new(path: File.join(dir, "secrets.json"), master_key: "master-not-a-secret")
  end

  def api_for(dir)
    Vault::Api.new(allowlist: allowlist, store: store_for(dir))
  end

  describe Vault::Allowlist do
    it "refuses missing, empty, and unparseable VAULT_CALLERS (parse-or-refuse)" do
      expect { Vault::Allowlist.parse!(nil) }.to raise_error(Vault::Allowlist::Unparseable) { |e|
        expect(e.reason).to eq("vault_callers_missing")
        expect(e.because["offender"]).to eq("VAULT_CALLERS")
      }
      expect { Vault::Allowlist.parse!("") }.to raise_error(Vault::Allowlist::Unparseable)
      expect { Vault::Allowlist.parse!("{") }.to raise_error(Vault::Allowlist::Unparseable) { |e|
        expect(e.reason).to eq("vault_callers_unparseable")
        expect(e.because["offender"]).to eq("VAULT_CALLERS")
      }
    end

    it "refuses a caller with no token and names the caller" do
      raw = JSON.generate({ "config-admin" => { "token" => "", "operations" => %w[put] } })
      expect { Vault::Allowlist.parse!(raw) }.to raise_error(Vault::Allowlist::Unparseable) { |e|
        expect(e.reason).to eq("vault_callers_token_missing")
        expect(e.because["offender"]).to eq("config-admin")
      }
    end

    it "allowlists by caller AND operation" do
      al = allowlist
      expect(al.authenticate!("tok-admin", "put").id).to eq("config-admin")
      expect { al.authenticate!("tok-admin", "get") }.to raise_error(Vault::Allowlist::Forbidden) { |e|
        expect(e.because["caller"]).to eq("config-admin")
        expect(e.because["operation"]).to eq("get")
      }
      expect { al.authenticate!("", "get") }.to raise_error(Vault::Allowlist::Unauthenticated)
      expect { al.authenticate!("nope", "get") }.to raise_error(Vault::Allowlist::Unauthenticated)
    end
  end

  describe Vault::Boot do
    it "fails closed naming every missing required env, including the pod default secret" do
      expect { Vault::Boot.required!({}) }.to raise_error(Vault::Boot::Error) { |e|
        expect(e.reason).to eq("vault_boot_refused")
        expect(e.because["missing"]).to include("VAULT_CALLERS", "VAULT_MASTER_KEY", "VAULT_STORE_PATH", "SECRET_KEY_BASE")
      }
      env = {
        "VAULT_CALLERS" => callers_json,
        "VAULT_MASTER_KEY" => "k",
        "VAULT_STORE_PATH" => "/tmp/x",
        "SECRET_KEY_BASE" => "mind-pod-not-a-secret"
      }
      expect { Vault::Boot.required!(env) }.to raise_error(Vault::Boot::Error) { |e|
        expect(e.because["missing"]).to eq(["SECRET_KEY_BASE"])
      }
    end

    it "accepts a complete env" do
      env = {
        "VAULT_CALLERS" => callers_json,
        "VAULT_MASTER_KEY" => "k",
        "VAULT_STORE_PATH" => "/tmp/x",
        "SECRET_KEY_BASE" => "a-real-secret"
      }
      expect(Vault::Boot.required!(env)).to be(true)
    end
  end

  describe Vault::Store do
    it "round-trips a secret without writing plaintext to disk" do
      Dir.mktmpdir do |dir|
        st = store_for(dir)
        meta = st.put("anthropic", "TEST_ONLY_NOT_A_KEY_disk")
        expect(meta["present"]).to be(true)
        expect(meta).not_to have_key("value")
        disk = File.binread(File.join(dir, "secrets.json"))
        expect(disk).not_to include("TEST_ONLY_NOT_A_KEY_disk")
        expect(st.list).to eq([{ "name" => "anthropic", "present" => true, "updated_at" => meta["updated_at"] }])
        expect(st.get("anthropic")["value"]).to eq("TEST_ONLY_NOT_A_KEY_disk")
      end
    end
  end

  describe Vault::Api do
    it "enforces read-back asymmetry: config-admin writes, llm-plane reads, admin cannot get" do
      Dir.mktmpdir do |dir|
        api = api_for(dir)
        put = api.put("tok-admin", "fireworks", "fw-secret")
        expect(put[:json]["ok"]).to be(true)
        expect(put[:json]["result"]).not_to have_key("value")

        listed = api.list("tok-admin")
        expect(listed[:json]["result"]["items"].first["name"]).to eq("fireworks")
        expect(listed[:json]["result"]["items"].first).not_to have_key("value")

        denied = api.get("tok-admin", "fireworks")
        expect(denied[:status]).to eq(403)
        expect(denied[:json]["ok"]).to be(false)
        expect(denied[:json]["reason"]).to eq("vault_not_allowlisted")
        expect(denied[:json]["because"]["caller"]).to eq("config-admin")
        expect(denied[:json]["because"]["operation"]).to eq("get")

        got = api.get("tok-llm", "fireworks")
        expect(got[:json]["ok"]).to be(true)
        expect(got[:json]["result"]["value"]).to eq("fw-secret")

        llm_put = api.put("tok-llm", "fireworks", "other")
        expect(llm_put[:status]).to eq(403)
        expect(llm_put[:json]["because"]["caller"]).to eq("llm-plane")
      end
    end
  end

  describe "ROLE-gated routes (ADR 0047 amendment 2)" do
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

    it "BACK serves /_cpcp and not the vault surface" do
      with_role("back") do
        get "/_cpcp/up"
        expect(last_response.status).to eq(200)
        get "/secrets"
        expect(last_response.status).to eq(404)
      end
    end

    it "FRONT does not serve /_cpcp (the published port is not the write seam)" do
      with_role("front") do
        get "/_cpcp/up"
        expect(last_response.status).to eq(404)
        get "/up"
        expect(last_response.status).to eq(200)
        expect(Rails.application.routes.recognize_path("/")).to include(controller: "home")
      end
    end

    it "VAULT serves /secrets and not /_cpcp" do
      ENV["VAULT_CALLERS"] = callers_json
      ENV["VAULT_MASTER_KEY"] = "master-not-a-secret"
      ENV["VAULT_STORE_PATH"] = File.join(Dir.tmpdir, "vault-spec-#{Process.pid}.json")
      with_role("vault") do
        get "/_cpcp/up"
        expect(last_response.status).to eq(404)
        get "/secrets"
        expect(last_response.status).to eq(401)
        expect(JSON.parse(last_response.body)["reason"]).to eq("vault_unauthenticated")
      end
    ensure
      ENV.delete("VAULT_CALLERS")
      ENV.delete("VAULT_MASTER_KEY")
      ENV.delete("VAULT_STORE_PATH")
    end
  end

  describe "vault HTTP" do
    include Rack::Test::Methods
    def app = Rails.application

    around do |example|
      Dir.mktmpdir do |dir|
        @store_path = File.join(dir, "secrets.json")
        previous = {
          "VAULT_CALLERS" => ENV["VAULT_CALLERS"],
          "VAULT_MASTER_KEY" => ENV["VAULT_MASTER_KEY"],
          "VAULT_STORE_PATH" => ENV["VAULT_STORE_PATH"]
        }
        ENV["VAULT_CALLERS"] = callers_json
        ENV["VAULT_MASTER_KEY"] = "master-not-a-secret"
        ENV["VAULT_STORE_PATH"] = @store_path
        prev_role = Rails.application.config.x.role
        Rails.application.config.x.role = "vault"
        Rails.application.reload_routes!
        example.run
      ensure
        previous.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
        Rails.application.config.x.role = prev_role
        Rails.application.reload_routes!
      end
    end

    it "writes via admin and reads via llm-plane over HTTP; admin get is 403" do
      header "Authorization", "Bearer tok-admin"
      post "/secrets", JSON.generate({ "name" => "anthropic", "value" => "TEST_ONLY_NOT_A_KEY_http" }),
           "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["ok"]).to be(true)
      expect(body["result"]).not_to have_key("value")

      get "/secrets/anthropic"
      expect(last_response.status).to eq(403)

      header "Authorization", "Bearer tok-llm"
      get "/secrets/anthropic"
      expect(last_response.status).to eq(200)
      got = JSON.parse(last_response.body)
      expect(got["result"]["value"]).to eq("TEST_ONLY_NOT_A_KEY_http")
    end
  end
end

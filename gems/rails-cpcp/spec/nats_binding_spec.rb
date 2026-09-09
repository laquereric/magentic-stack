# frozen_string_literal: true

require "spec_helper"
require "json"
require "rails_cpcp/nats_binding"

RSpec.describe RailsCpcp::NatsBinding do
  it "names the subject from the role" do
    expect(described_class.subject("vault")).to eq("cpcp.vault.rpc")
    expect(described_class.subject("back")).to eq("cpcp.back.rpc")
  end

  it "is disabled when MM_NATS_URL is empty" do
    prev = ENV["MM_NATS_URL"]
    ENV.delete("MM_NATS_URL")
    expect(described_class.enabled?).to be false
    expect(described_class.request(role: "back", payload: "{}")).to be_nil
  ensure
    ENV["MM_NATS_URL"] = prev if prev
  end

  it "builds a POST /_cpcp/rpc Rack env carrying the Authorization header" do
    env = described_class.rack_env(%({"jsonrpc":"2.0"}), "Authorization" => "Bearer tok")
    expect(env["REQUEST_METHOD"]).to eq("POST")
    expect(env["PATH_INFO"]).to eq("/_cpcp/rpc")
    expect(env["CONTENT_TYPE"]).to eq("application/json")
    expect(env["HTTP_AUTHORIZATION"]).to eq("Bearer tok")
    expect(env["rack.input"].read).to eq(%({"jsonrpc":"2.0"}))
  end

  it "does not put the bearer token in the JSON-RPC body" do
    env = described_class.rack_env(%({"method":"vault.secret.list"}), "Authorization" => "Bearer tok-xyz")
    body = env["rack.input"].read
    expect(body).not_to include("tok-xyz")
    expect(env["HTTP_AUTHORIZATION"]).to include("tok-xyz")
  end

  it "listen roles are the CPCP RPC servers, not config or front" do
    expect(described_class::LISTEN_ROLES).to contain_exactly("back", "vault", "bus", "persist")
  end

  it "exclusive_raw leaves HTTP available only when MM_NATS_URL is empty" do
    prev = ENV["MM_NATS_URL"]
    ENV.delete("MM_NATS_URL")
    exclusive, raw = described_class.exclusive_raw(role: "back", payload: "{}")
    expect(exclusive).to be false
    expect(raw).to be_nil
  ensure
    ENV["MM_NATS_URL"] = prev if prev
  end

  it "exclusive_raw refuses rather than returning nil when the broker is silent" do
    prev = ENV["MM_NATS_URL"]
    ENV["MM_NATS_URL"] = "nats://127.0.0.1:1"
    allow(described_class).to receive(:request).and_return(nil)
    exclusive, raw = described_class.exclusive_raw(role: "back", payload: "{}")
    expect(exclusive).to be true
    parsed = JSON.parse(raw)
    expect(parsed["ok"]).to be false
    expect(parsed["reason"]).to eq("nats_unreachable")
    expect(parsed["because"]).to include("HTTP is not a fallback")
  ensure
    if prev
      ENV["MM_NATS_URL"] = prev
    else
      ENV.delete("MM_NATS_URL")
    end
  end
end

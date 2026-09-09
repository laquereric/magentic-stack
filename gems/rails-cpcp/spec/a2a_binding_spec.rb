# frozen_string_literal: true

require "spec_helper"
require "json"
require "rails_cpcp/nats_binding"
require "rails_cpcp/a2a_binding"

RSpec.describe RailsCpcp::A2aBinding do
  it "names the NATS subject from the agent" do
    expect(described_class.subject("back")).to eq("a2a.back.rpc")
  end

  it "serves an Agent Card that prefers NATS, not HTTP" do
    card = described_class.card
    expect(card["preferredTransport"]).to eq("NATS")
    expect(card["additionalInterfaces"].first["transport"]).to eq("NATS")
    expect(JSON.generate(card)).not_to include("/.well-known/")
    expect(JSON.generate(card)).not_to include("http://back")
  end

  it "rejects a message with no CPCP part rather than opening HTTP" do
    raw = described_class.handle(JSON.generate(
      "jsonrpc" => "2.0", "id" => 1, "method" => "message/send",
      "params" => { "message" => { "messageId" => "m1", "role" => "user", "parts" => [{ "kind" => "text", "text" => "hi" }] } }
    ))
    parsed = JSON.parse(raw)
    expect(parsed["result"]["status"]["state"]).to eq("rejected")
    expect(parsed["result"]["status"]["because"]).to include("HTTP is not a fallback")
  end

  it "exclusive_raw refuses when MM_NATS_URL is set and the broker is silent" do
    prev = ENV["MM_NATS_URL"]
    ENV["MM_NATS_URL"] = "nats://127.0.0.1:1"
    allow(described_class).to receive(:request).and_return(nil)
    exclusive, raw = described_class.exclusive_raw(agent: "back", payload: "{}")
    expect(exclusive).to be true
    expect(JSON.parse(raw)["reason"]).to eq("nats_unreachable")
  ensure
    if prev then ENV["MM_NATS_URL"] = prev else ENV.delete("MM_NATS_URL") end
  end

  it "listen roles are BACK only in v1" do
    expect(described_class::LISTEN_ROLES).to contain_exactly("back")
  end
end

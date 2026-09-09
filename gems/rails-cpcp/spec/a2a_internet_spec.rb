# frozen_string_literal: true

require "spec_helper"
require "json"
require "rails_cpcp/a2a_internet"

RSpec.describe RailsCpcp::A2aInternet do
  def with_env(pairs)
    prev = {}
    pairs.each do |k, v|
      prev[k] = ENV[k]
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
    yield
  ensure
    prev.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end

  it "does not speak internet A2A on the in-pod loopback bind" do
    with_env("ROLE" => "back", "HTTP_BIND" => "127.0.0.1") do
      expect(described_class.speaks?).to be false
    end
  end

  it "speaks internet A2A only on host-published BACK" do
    with_env("ROLE" => "back", "HTTP_BIND" => "0.0.0.0") do
      expect(described_class.speaks?).to be true
    end
    with_env("ROLE" => "front", "HTTP_BIND" => "0.0.0.0") do
      expect(described_class.speaks?).to be false
    end
  end

  it "serves a JSON-LD Agent Card that prefers HTTP, not NATS" do
    card = described_class.card(base_url: "https://example.test")
    expect(card["type"]).to eq("AgentCard")
    expect(card["preferredTransport"]).to eq("HTTP")
    expect(card["url"]).to eq("https://example.test/_a2a/rpc")
    expect(card["defaultInputModes"]).to include("application/ld+json")
    expect(JSON.generate(card)).not_to include("nats://")
    expect(JSON.generate(card)).not_to include("http://back")
  end

  it "names the well-known discovery path" do
    expect(described_class::WELL_KNOWN).to eq("/.well-known/agent-card.json")
    expect(described_class::RPC_PATH).to eq("/_a2a/rpc")
  end
end

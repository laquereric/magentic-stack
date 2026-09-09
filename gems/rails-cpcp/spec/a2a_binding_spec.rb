# frozen_string_literal: true

require "spec_helper"
require "json"
require "rails_cpcp/nats_binding"
require "rails_cpcp/envelope"
require "rails_cpcp/a2a_binding"

RSpec.describe RailsCpcp::A2aBinding do
  def grant(method: "note.list", operation_id: nil)
    node = {
      "@context" => { "@vocab" => "https://w3id.org/cpcp/ns#" },
      "id" => "urn:uuid:22222222-2222-2222-2222-222222222222",
      "type" => operation_id ? ["Effect", "cpcp:Push"] : ["Context", "cpcp:Pull"],
      "method" => method,
      "params" => {}
    }
    node["operationId"] = operation_id if operation_id
    {
      "jsonrpc" => "2.0", "id" => 1, "method" => "message/send",
      "params" => {
        "message" => {
          "@context" => { "@vocab" => "https://w3id.org/cpcp/osi8/a2a#" },
          "id" => "urn:uuid:11111111-1111-1111-1111-111111111111",
          "type" => "Message",
          "role" => "user",
          "parts" => [{
            "type" => "DataPart",
            "mediaType" => "application/ld+json",
            "data" => node
          }]
        }
      }
    }
  end

  it "names the NATS subject from the agent" do
    expect(described_class.subject("back")).to eq("a2a.back.rpc")
  end

  it "serves a JSON-LD Agent Card that prefers NATS, not HTTP" do
    card = described_class.card
    expect(card["@context"]).to be_a(Hash)
    expect(card["type"]).to eq("AgentCard")
    expect(card["preferredTransport"]).to eq("NATS")
    expect(card["defaultInputModes"]).to include("application/ld+json")
    expect(JSON.generate(card)).not_to include("/.well-known/")
    expect(JSON.generate(card)).not_to include("http://back")
  end

  it "rejects a text Part rather than opening HTTP" do
    raw = described_class.handle(JSON.generate(
      "jsonrpc" => "2.0", "id" => 1, "method" => "message/send",
      "params" => { "message" => { "id" => "m1", "role" => "user", "parts" => [{ "type" => "TextPart", "text" => "hi" }] } }
    ))
    parsed = JSON.parse(raw)
    expect(parsed["result"]["status"]["state"]).to eq("rejected")
    expect(parsed["result"]["status"]["because"]).to include("HTTP is not a fallback")
  end

  it "rejects nested JSON-RPC under data.cpcp as a2a_json_not_jsonld" do
    raw = described_class.handle(JSON.generate(
      "jsonrpc" => "2.0", "id" => 1, "method" => "message/send",
      "params" => { "message" => { "id" => "m1", "parts" => [{
        "data" => { "cpcp" => { "jsonrpc" => "2.0", "method" => "note.list", "params" => {} } }
      }] } }
    ))
    parsed = JSON.parse(raw)
    expect(parsed["result"]["status"]["state"]).to eq("rejected")
    expect(parsed["result"]["status"]["reason"]).to eq("a2a_json_not_jsonld")
  end

  it "rejects a method object with no @context" do
    raw = described_class.handle(JSON.generate(
      "jsonrpc" => "2.0", "id" => 1, "method" => "message/send",
      "params" => { "message" => { "id" => "m1", "parts" => [{
        "data" => { "method" => "note.list", "params" => {} }
      }] } }
    ))
    parsed = JSON.parse(raw)
    expect(parsed["result"]["status"]["reason"]).to eq("a2a_json_not_jsonld")
  end

  it "maps a JSON-LD grant onto a dispatcher request" do
    node = grant["params"]["message"]["parts"][0]["data"]
    rpc = described_class.ld_to_rpc(node)
    expect(rpc["method"]).to eq("note.list")
    expect(rpc["jsonrpc"]).to eq("2.0")
    expect(rpc).not_to have_key("operationId")
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

  it "does not unwrap a nested cpcp object even when it has @context" do
    raw = described_class.handle(JSON.generate(
      "jsonrpc" => "2.0", "id" => 1, "method" => "message/send",
      "params" => { "message" => { "id" => "m1", "parts" => [{
        "data" => { "cpcp" => { "@context" => { "@vocab" => "https://w3id.org/cpcp/ns#" },
                                "method" => "note.list", "params" => {} } }
      }] } }
    ))
    parsed = JSON.parse(raw)
    expect(parsed["result"]["status"]["reason"]).to eq("a2a_json_not_jsonld")
  end

  it "returns a JSON-LD Task for tasks/get of an unknown id" do
    raw = described_class.handle(JSON.generate(
      "jsonrpc" => "2.0", "id" => 9, "method" => "tasks/get",
      "params" => { "id" => "urn:uuid:missing" }
    ))
    parsed = JSON.parse(raw)
    expect(parsed["id"]).to eq(9)
    expect(parsed["result"]["type"]).to eq("Task")
    expect(parsed["result"]["status"]["state"]).to eq("unknown")
    expect(parsed["result"]["@context"]).to be_a(Hash)
  end
end

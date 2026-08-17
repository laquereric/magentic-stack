# frozen_string_literal: true

require "spec_helper"

RSpec.describe "mmg-switchyard v0 offline proof" do
  let(:config_local) do
    Mmg::Switchyard::Config.new(
      cid_iri: "urn:mm:cid:demo",
      model: "mlx-stub",
      source: :local,
      policy: { prefer: :local, privacy: :portable },
      budget: 2048,
      format: :openai
    )
  end

  let(:config_remote) do
    Mmg::Switchyard::Config.new(
      cid_iri: "urn:mm:cid:demo",
      model: "remote-stub",
      source: :remote,
      policy: { prefer: :remote, allow_remote: true, privacy: :portable },
      format: :openai
    )
  end

  let(:config_private) do
    Mmg::Switchyard::Config.new(
      cid_iri: "urn:mm:cid:private",
      model: "mlx-stub",
      source: :remote,
      policy: { prefer: :remote, allow_remote: true, privacy: :private },
      format: :openai
    )
  end

  let(:good_request) do
    {
      "messages" => [
        { "role" => "system", "content" => "You are helpful." },
        { "role" => "user", "content" => "hello" }
      ],
      "max_tokens" => 64
    }
  end

  it "Router.choose defaults to local and respects policy" do
    expect(Mmg::Switchyard::Router.choose(config_local)).to eq(:local)
    expect(Mmg::Switchyard::Router.choose(config_remote)).to eq(:remote)
    # private data forced local even if prefer remote
    expect(Mmg::Switchyard::Router.choose(config_private)).to eq(:local)
    expect(Mmg::Switchyard::Router.choose(nil)).to eq(:local)
  end

  it "Router.translate maps openai <-> anthropic" do
    o2a = Mmg::Switchyard::Router.translate(good_request.merge("format" => "openai"), to: :anthropic)
    expect(o2a[:ok]).to eq(true)
    expect(o2a[:value]["format"]).to eq("anthropic")
    expect(o2a[:value]["system"]).to include("helpful")
    expect(o2a[:value]["messages"].map { |m| m["role"] }).not_to include("system")

    a2o = Mmg::Switchyard::Router.translate(o2a[:value], to: :openai)
    expect(a2o[:ok]).to eq(true)
    expect(a2o[:value]["format"]).to eq("openai")
    expect(a2o[:value]["messages"].any? { |m| m["role"] == "system" }).to eq(true)
  end

  it "Contract validates closed request/response schemas (never-raise)" do
    bad = Mmg::Switchyard::Contract.validate_request(config_local, {})
    expect(bad[:ok]).to eq(false)
    expect(bad[:reason]).to eq("schema_request")

    ok = Mmg::Switchyard::Contract.validate_request(config_local, good_request)
    expect(ok[:ok]).to eq(true)

    bad_res = Mmg::Switchyard::Contract.validate_response(config_local, { "foo" => 1 })
    expect(bad_res[:ok]).to eq(false)

    good_res = Mmg::Switchyard::Contract.validate_response(config_local, {
      "content" => "hi",
      "model" => "mlx-stub",
      "finish_reason" => "stop",
      "usage" => { "prompt_tokens" => 1, "completion_tokens" => 1 }
    })
    expect(good_res[:ok]).to eq(true)
  end

  it "Client#assist end-to-end local stub with Observe span" do
    client = Mmg::Switchyard::Client.new(config_local)
    result = client.assist(good_request)
    expect(result[:ok]).to eq(true)
    expect(result[:value][:route]).to eq(:local)
    expect(result[:value][:response]["content"]).to eq("local-mlx-stub")
    expect(result[:value][:cid_iri]).to eq("urn:mm:cid:demo")

    spans = Mmg::Switchyard::Observe.spans
    expect(spans.length).to be >= 1
    attrs = spans.last[:attributes]
    expect(attrs["mmg.switchyard.route"]).to eq("local")
    expect(attrs["mmg.switchyard.outcome"]).to eq("ok")
    expect(attrs["gen_ai.request.model"]).to eq("mlx-stub")
    expect(attrs).to have_key("mmg.switchyard.latency_ms")
  end

  it "Client#assist routes remote when policy allows" do
    client = Mmg::Switchyard::Client.new(config_remote)
    result = client.assist(good_request)
    expect(result[:ok]).to eq(true)
    expect(result[:value][:route]).to eq(:remote)
    expect(result[:value][:response]["content"]).to eq("remote-switchyard-stub")
  end

  it "private policy never leaves device even if remote preferred" do
    client = Mmg::Switchyard::Client.new(config_private)
    result = client.assist(good_request)
    expect(result[:ok]).to eq(true)
    expect(result[:value][:route]).to eq(:local)
  end

  it "never-raises on invalid request" do
    expect {
      r = Mmg::Switchyard::Client.new(config_local).assist({})
      expect(r[:ok]).to eq(false)
      expect(r).to include(:reason, :because)
    }.not_to raise_error
  end

  it "budget gate fails closed" do
    cfg = Mmg::Switchyard::Config.new(
      cid_iri: "urn:mm:cid:demo",
      model: "m",
      policy: {},
      budget: 10
    )
    r = Mmg::Switchyard::Contract.validate_request(cfg, good_request.merge("max_tokens" => 9999))
    expect(r[:ok]).to eq(false)
    expect(r[:reason]).to eq("budget_exceeded")
  end

  it "MCB tool assist + route + translate" do
    r = Mmg::Switchyard::Mcb::Tool.call(
      action: "switchyard_assist",
      config: { cid_iri: "urn:mm:cid:demo", model: "m", policy: { prefer: :local } },
      request: good_request
    )
    expect(r[:ok]).to eq(true)
    expect(r[:value][:route]).to eq(:local)

    route = Mmg::Switchyard::Mcb::Tool.call(
      action: "switchyard.route",
      config: { cid_iri: "urn:mm:cid:x", policy: { prefer: :remote, allow_remote: true } }
    )
    expect(route[:ok]).to eq(true)
    expect(route[:value][:route]).to eq(:remote)

    tr = Mmg::Switchyard::Mcb::Tool.call(
      action: "switchyard.translate",
      request: good_request,
      to: "anthropic"
    )
    expect(tr[:ok]).to eq(true)
    expect(tr[:value]["format"]).to eq("anthropic")
  end

  it "doctrine: adapters are stubs (no network) and Source interface exists" do
    expect(Mmg::Switchyard::Adapters::StubSource.new).to be_a(Mmg::Switchyard::Adapters::Source)
    expect(Mmg::Switchyard::Adapters::LocalSource.new).to be_a(Mmg::Switchyard::Adapters::Source)
    expect(Mmg::Switchyard::Adapters::RemoteSource.new.endpoint).to be_nil
  end
end

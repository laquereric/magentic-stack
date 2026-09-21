# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Envelope do
  let(:envelope) { described_class }

  it "reads a success envelope and carries the status without reading meaning into it" do
    env = envelope.read(ok_envelope({ "@graph" => [{ "title" => "a" }] }), http_status: 200)

    expect(env[:ok]).to be true
    expect(env[:result]["@graph"].length).to eq 1
    expect(env[:http_status]).to eq 200
  end

  it "reads the nested refusal form" do
    env = envelope.read(nested_refusal("unknown_operation", 'no CPCP operation "nope"'), http_status: 200)

    expect(env[:ok]).to be false
    expect(env[:reason]).to eq :unknown_operation
    expect(env[:because]).to match(/no CPCP operation/)
  end

  it "reads the flat refusal form, including an object because" do
    env = envelope.read(flat_refusal("unknown_store", { "store" => "vault" }), http_status: 200)

    expect(env[:reason]).to eq :unknown_store
    expect(env[:because]).to eq({ "store" => "vault" })
    expect(envelope.text(env[:because])).to eq '{"store":"vault"}'
  end

  it "treats an HTTP 200 grounding refusal as a refusal" do
    env = envelope.read(nested_refusal("grounding_refused", "title missing"), http_status: 200)

    expect(env[:ok]).to be false
    expect(env[:http_status]).to eq 200
  end

  it "carries failure_layer from either form" do
    nested = { "ok" => false,
               "error" => { "reason" => "graph_unreachable", "because" => "down",
                            "failure_layer" => "infrastructure" } }
    expect(envelope.read(nested, http_status: 503)[:failure_layer]).to eq :infrastructure

    flat = { "ok" => false, "reason" => "persist_forbidden", "because" => "no",
             "failure_layer" => "http_auth" }
    expect(envelope.read(flat, http_status: 403)[:failure_layer]).to eq :http_auth
  end

  it "keeps a complete restoration and drops a partial one" do
    complete = nested_refusal("graph_unreachable", "store down").merge(
      "cpcp" => { "restoration" => {
        "state_reached" => "half written",
        "inconsistency" => "graph lags the store",
        "restore_when" => "the graph answers again",
        "restore_action" => "replay the projection"
      } }
    )
    expect(envelope.read(complete)[:restoration][:restore_action]).to eq "replay the projection"

    partial = nested_refusal("graph_unreachable", "store down").merge(
      "cpcp" => { "restoration" => { "state_reached" => "half written", "inconsistency" => "",
                                     "restore_when" => "later", "restore_action" => "replay" } }
    )
    expect(envelope.read(partial)[:restoration]).to be_nil
  end

  it "reports a recording that is not an application" do
    env = envelope.read(ok_envelope({ "live_applied" => false, "effective" => "2026-10-01" }))

    expect(env[:live_applied]).to be false
    expect(env[:effective]).to eq "2026-10-01"
  end

  it "refuses a body that is not an envelope" do
    expect(envelope.read("<html>")[:reason]).to eq :seam_body_unparseable
    expect(envelope.read({ "jsonrpc" => "2.0" })[:reason]).to eq :seam_body_unparseable
    expect(envelope.read({ "ok" => false })[:reason]).to eq :seam_body_unparseable
  end

  it "fills the failure layer for a binding reason" do
    expect(envelope.refuse(:user_declined, "no")[:failure_layer]).to eq :domain
    expect(envelope.refuse(:seam_unreachable, "no")[:failure_layer]).to eq :infrastructure
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Webhooks do
  let(:secret) { "super-secret-webhook-key" }
  let(:payload) do
    JSON.generate(
      "triggerEvent" => "BOOKING_CREATED",
      "createdAt" => "2026-09-17T00:00:00.000Z",
      "payload" => { "uid" => "b1", "status" => "ACCEPTED" }
    )
  end

  def signature_for(body: payload, key: secret)
    described_class.signed_payload(key, body)
  end

  it "accepts a valid HMAC-SHA256 signature" do
    r = described_class.verify(
      payload,
      {
        "X-Cal-Signature-256" => signature_for,
        "x-cal-webhook-version" => "2021-10-20"
      },
      signing_secret: secret
    )
    expect(r[:ok]).to be true
    expect(r[:type]).to eq("BOOKING_CREATED")
    expect(r[:event_id]).to eq("b1")
    expect(r[:version]).to eq("2021-10-20")
    expect(r[:data]["payload"]["uid"]).to eq("b1")
  end

  it "accepts a sha256= prefix on the header" do
    r = described_class.verify(
      payload,
      { "x-cal-signature-256" => "sha256=#{signature_for}" },
      signing_secret: secret
    )
    expect(r[:ok]).to be true
  end

  it "refuses a missing signing secret" do
    r = described_class.verify(payload, {}, signing_secret: "")
    expect(r[:reason]).to eq(:signing_secret_required)
  end

  it "refuses missing headers" do
    r = described_class.verify(payload, {}, signing_secret: secret)
    expect(r[:reason]).to eq(:webhook_headers_required)
  end

  it "refuses a bad signature" do
    r = described_class.verify(
      payload,
      { "x-cal-signature-256" => "deadbeef" * 8 },
      signing_secret: secret
    )
    expect(r[:reason]).to eq(:webhook_invalid)
  end
end

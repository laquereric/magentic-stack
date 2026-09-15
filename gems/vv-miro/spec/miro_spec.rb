# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro do
  it "exposes VERSION and the SDK pin" do
    expect(described_class::VERSION).to eq("0.1.0")
    expect(described_class::SDK_SRC).to include("sdk/v2/miro.js")
  end

  it "builds a client and oauth from the module" do
    expect(described_class.client(access_token: "at")).to be_a(Vv::Miro::Client)
    expect(described_class.oauth(client_id: "c", client_secret: "s")).to be_a(Vv::Miro::Oauth)
  end
end

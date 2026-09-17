# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma do
  it "exposes VERSION and the API pin" do
    expect(described_class::VERSION).to eq("0.1.0")
    expect(described_class::DEFAULT_API_URL).to include("api.figma.com")
    expect(described_class::PLUGIN_API).to eq("1.0.0")
  end

  it "builds a client and oauth from the module" do
    expect(described_class.client(access_token: "at")).to be_a(Vv::Figma::Client)
    expect(described_class.oauth(client_id: "c", client_secret: "s")).to be_a(Vv::Figma::Oauth)
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Transport do
  it "refuses a missing access token when auth is required" do
    t = described_class.new(uri: "https://api.figma.com", access_token: "")
    r = t.request(:get, "/v1/me")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:token_required)
  end

  it "refuses a missing URI" do
    t = described_class.new(uri: "", access_token: "at")
    r = t.request(:get, "/v1/me")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:uri_required)
  end
end

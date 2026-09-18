# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom do
  it "has a version" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "constructs the four planes from the facade" do
    expect(described_class.client(token: "cal_test_x")).to be_a(described_class::Client)
    expect(described_class.oauth(client_id: "cid", client_secret: "sec")).to be_a(described_class::Oauth)
    expect(described_class.webhooks).to eq(described_class::Webhooks)
    expect(described_class.embed).to eq(described_class::Embed)
  end
end

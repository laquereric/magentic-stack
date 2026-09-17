# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Embed do
  it "builds an embed URL" do
    r = described_class.url("AbCd")
    expect(r[:ok]).to be true
    expect(r[:data]).to include("https://www.figma.com/embed?")
    expect(r[:data]).to include("embed_host=figma")
    expect(r[:data]).to include("file")
    expect(r[:data]).to include("AbCd")
  end

  it "refuses a missing file key" do
    r = described_class.url("")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:file_required)
  end

  it "builds iframe attributes" do
    r = described_class.iframe_attrs("AbCd", width: 400, height: 300)
    expect(r[:ok]).to be true
    expect(r[:data][:width]).to eq(400)
    expect(r[:data][:src]).to include("embed")
    expect(r[:data][:allowfullscreen]).to be true
  end
end

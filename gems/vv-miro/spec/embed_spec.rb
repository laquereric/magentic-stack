# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Embed do
  it "builds a live-embed URL with autoplay" do
    r = described_class.url("o9J_abc=")
    expect(r[:ok]).to be true
    expect(r[:data]).to include("https://miro.com/app/live-embed/")
    expect(r[:data]).to include("autoplay=true")
  end

  it "accepts a viewport hash" do
    r = described_class.url("b1", move_to_viewport: { x: 1, y: 2, width: 3, height: 4 })
    expect(r[:ok]).to be true
    expect(r[:data]).to include("moveToViewport=1%2C2%2C3%2C4")
  end

  it "refuses widget + viewport together" do
    r = described_class.url("b1", move_to_widget: "w1", move_to_viewport: "0,0,1,1")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:viewport_conflict)
  end

  it "refuses a missing board id" do
    r = described_class.url("")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:board_required)
  end

  it "builds iframe attributes" do
    r = described_class.iframe_attrs("b1", width: 400, height: 300, embed_mode: "view_only_without_ui")
    expect(r[:ok]).to be true
    expect(r[:data][:width]).to eq(400)
    expect(r[:data][:src]).to include("embedMode=view_only_without_ui")
    expect(r[:data][:allowfullscreen]).to be true
  end
end

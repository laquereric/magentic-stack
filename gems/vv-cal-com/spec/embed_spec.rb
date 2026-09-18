# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Embed do
  it "builds a booking URL" do
    r = described_class.booking_url("ada", "intro")
    expect(r[:ok]).to be true
    expect(r[:data]).to eq("https://cal.com/ada/intro")
  end

  it "builds a profile URL without an event slug" do
    r = described_class.booking_url("ada")
    expect(r[:data]).to eq("https://cal.com/ada")
  end

  it "appends prefill query params" do
    r = described_class.booking_url("ada", "intro", name: "Ada", email: "ada@example.com")
    expect(r[:data]).to include("name=Ada")
    expect(r[:data]).to include("email=ada%40example.com")
  end

  it "refuses a missing username" do
    r = described_class.booking_url("")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:username_required)
  end

  it "builds iframe attributes" do
    r = described_class.iframe_attrs("ada", "intro", width: 400, height: 300)
    expect(r[:ok]).to be true
    expect(r[:data][:width]).to eq(400)
    expect(r[:data][:height]).to eq(300)
    expect(r[:data][:src]).to include("https://cal.com/ada/intro")
  end

  it "builds popup data-cal-link attrs" do
    r = described_class.popup_attrs("ada", "intro", namespace: "intro")
    expect(r[:ok]).to be true
    expect(r[:data]["data-cal-link"]).to eq("ada/intro")
    expect(r[:data]["data-cal-namespace"]).to eq("intro")
  end

  it "points embed.js at the app host" do
    r = described_class.embed_js_url
    expect(r[:data]).to eq("https://app.cal.com/embed/embed.js")
  end
end

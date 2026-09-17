# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Oauth do
  def ok(data = {})
    { ok: true, data: data }
  end

  def oauth_with(&handler)
    transport = Vv::Figma::FakeTransport.new(&handler)
    described_class.new(client_id: "cid", client_secret: "csec", transport: transport)
  end

  it "builds the authorize URL" do
    r = described_class.new(client_id: "cid", client_secret: "csec")
                      .authorize_url(redirect_uri: "https://app.example/cb", state: "s1")
    expect(r[:ok]).to be true
    expect(r[:data]).to start_with("https://www.figma.com/oauth?")
    expect(r[:data]).to include("client_id=cid")
    expect(r[:data]).to include("response_type=code")
    expect(r[:data]).to include("state=s1")
  end

  it "exchanges a code on POST /v1/oauth/token with HTTP Basic" do
    seen = nil
    o = oauth_with do |call|
      seen = call
      ok("access_token" => "at", "refresh_token" => "rt")
    end
    r = o.exchange(code: "abc", redirect_uri: "https://app.example/cb")
    expect(r[:ok]).to be true
    expect(seen[:method]).to eq(:post)
    expect(seen[:path]).to eq("/v1/oauth/token")
    expect(seen[:auth]).to be false
    expect(seen[:form]).to be true
    expect(seen[:basic]).to eq("cid:csec")
    expect(seen[:body]).to include(grant_type: "authorization_code", code: "abc")
  end

  it "refreshes a token" do
    seen = nil
    o = oauth_with do |call|
      seen = call
      ok("access_token" => "at2")
    end
    o.refresh(refresh_token: "rt")
    expect(seen[:path]).to eq("/v1/oauth/refresh")
    expect(seen[:body]).to include(grant_type: "refresh_token", refresh_token: "rt")
  end

  it "refuses exchange without a code" do
    r = oauth_with { |_| ok }.exchange(code: "", redirect_uri: "https://x")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:code_required)
  end
end

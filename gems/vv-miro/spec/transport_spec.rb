# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Miro::Transport do
  it "refuses a missing URI" do
    r = described_class.new(uri: "", access_token: "at").request(:get, "/v2/boards")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:uri_required)
  end

  it "refuses a missing access token when auth is on" do
    r = described_class.new(uri: "https://api.miro.com", access_token: "").request(:get, "/v2/boards")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:token_required)
  end

  it "maps HTTP 401 to http_error when the body is not a Miro error object" do
    stub_request(:get, "https://api.miro.com/v2/boards")
      .to_return(status: 401, body: { "message" => "Unauthorized" }.to_json, headers: { "Content-Type" => "application/json" })
    r = described_class.new(uri: "https://api.miro.com", access_token: "bad").request(:get, "/v2/boards")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:http_error)
    expect(r[:because]).to eq("Unauthorized")
  end

  it "unwraps a 200 board payload" do
    stub_request(:get, "https://api.miro.com/v2/boards/b1")
      .to_return(status: 200, body: { "id" => "b1", "name" => "N" }.to_json, headers: { "Content-Type" => "application/json" })
    r = described_class.new(uri: "https://api.miro.com", access_token: "at").request(:get, "/v2/boards/b1")
    expect(r[:ok]).to be true
    expect(r[:data]).to include("id" => "b1")
  end

  # `because` is returned to the caller and logged. Oauth puts client_secret in
  # the query string, and an exception that quotes the URL would carry it out
  # of the gem -- into a log line, a UI, or a bug report.
  describe "a refusal never carries a credential" do
    it "redacts secrets from an exception that quotes the URL" do
      t = described_class.new(uri: "https://api.miro.com", access_token: "at")
      allow(Net::HTTP).to receive(:new).and_raise(
        SocketError, "failed to open TCP connection to " \
                     "https://api.miro.com/v1/oauth/token?client_secret=s3cr3t-live&code=abc123"
      )
      r = t.request(:post, "/v1/oauth/token", auth: false)
      expect(r[:ok]).to be false
      expect(r[:because]).to include("client_secret=[redacted]")
      expect(r[:because]).to include("code=[redacted]")
      expect(r[:because]).not_to include("s3cr3t-live")
      expect(r[:because]).not_to include("abc123")
    end

    it "keeps the diagnosis a caller needs" do
      t = described_class.new(uri: "https://api.miro.com", access_token: "at")
      allow(Net::HTTP).to receive(:new).and_raise(SocketError, "getaddrinfo: nodename nor servname provided")
      r = t.request(:get, "/v2/boards")
      expect(r[:reason]).to eq(:network_error)
      expect(r[:because]).to include("SocketError")
      expect(r[:because]).to include("getaddrinfo")
    end
  end
end

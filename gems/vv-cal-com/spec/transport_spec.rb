# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Transport do
  let(:uri) { "https://api.cal.com" }
  let(:token) { "cal_test_secret" }
  let(:transport) { described_class.new(uri: uri, token: token, api_version: "2024-08-13") }

  def stub_cal(method, path, status: 200, body: { "status" => "success", "data" => { "uid" => "b1" } }, query: nil)
    url = "#{uri}#{path}"
    url += "?#{query}" if query
    stub_request(method, url)
      .to_return(status: status, body: JSON.generate(body), headers: { "Content-Type" => "application/json" })
  end

  it "sends Bearer auth, JSON content type, and cal-api-version" do
    stub_cal(:get, "/v2/bookings")
    transport.request(:get, "/v2/bookings")
    expect(WebMock).to have_requested(:get, "#{uri}/v2/bookings")
      .with(
        headers: {
          "Authorization" => "Bearer cal_test_secret",
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "User-Agent" => "vv-cal-com/#{Vv::CalCom::VERSION}",
          "Cal-Api-Version" => "2024-08-13"
        }
      )
  end

  it "sends Platform headers when configured" do
    t = described_class.new(uri: uri, token: token, client_id: "cid", secret_key: "sec")
    stub_cal(:get, "/v2/me")
    t.request(:get, "/v2/me")
    expect(WebMock).to have_requested(:get, "#{uri}/v2/me")
      .with(headers: { "X-Cal-Client-Id" => "cid", "X-Cal-Secret-Key" => "sec" })
  end

  it "maps a success envelope onto { ok: true, data: }" do
    stub_cal(:get, "/v2/bookings/b1", body: { "status" => "success", "data" => { "uid" => "b1" } })
    r = transport.request(:get, "/v2/bookings/b1")
    expect(r).to include(ok: true, data: { "uid" => "b1" })
  end

  it "maps HTTP 401 Cal errors to cal_error without raising" do
    stub_cal(:get, "/v2/bookings", status: 401, body: {
      "status" => "error",
      "error" => { "message" => "Invalid API key", "code" => "UnauthorizedException" }
    })
    r = transport.request(:get, "/v2/bookings")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:cal_error)
    expect(r[:because]).to eq("Invalid API key")
    expect(r[:http_status]).to eq(401)
  end

  it "maps a timeout to :timeout without raising" do
    stub_request(:get, "#{uri}/v2/bookings").to_timeout
    r = transport.request(:get, "/v2/bookings")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:timeout)
  end

  it "refuses construction-time missing credentials at request time" do
    r = described_class.new(uri: "", token: "").request(:get, "/v2/bookings")
    expect(r[:reason]).to eq(:uri_required)
    r = described_class.new(uri: uri, token: "").request(:get, "/v2/bookings")
    expect(r[:reason]).to eq(:token_required)
  end

  it "omits Authorization when auth is optional and no token is set" do
    t = described_class.new(uri: uri, token: "")
    stub_cal(:post, "/v2/bookings")
    t.request(:post, "/v2/bookings", body: { "eventTypeId" => 1 }, auth: :optional)
    expect(WebMock).to have_requested(:post, "#{uri}/v2/bookings")
      .with { |req| req.headers["Authorization"].nil? }
  end

  it "joins array query values with commas" do
    stub_request(:get, "#{uri}/v2/bookings?eventTypeIds=100%2C200")
      .to_return(status: 200, body: JSON.generate("status" => "success", "data" => []),
                 headers: { "Content-Type" => "application/json" })
    transport.request(:get, "/v2/bookings", query: { "eventTypeIds" => [100, 200] })
    expect(WebMock).to have_requested(:get, "#{uri}/v2/bookings?eventTypeIds=100%2C200")
  end
end

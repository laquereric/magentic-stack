# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Share do
  def ok(data = {})
    { ok: true, data: data }
  end

  def client_with(&handler)
    transport = Vv::Figma::FakeTransport.new(&handler)
    Vv::Figma::Client.new(access_token: "at", transport: transport)
  end

  it "refuses a missing client" do
    r = described_class.push(nil, file_key: "Ab", effects: [{ op: "create", item: { type: "comment" } }])
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:client_required)
  end

  it "refuses a missing file_key (REST cannot create files)" do
    r = described_class.push(client_with { |_| ok }, file_key: "", effects: [{ op: "create" }])
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:file_required)
  end

  it "posts comments onto an existing file and returns a view link" do
    seen = []
    c = client_with do |call|
      seen << call
      ok("id" => "c1")
    end
    r = described_class.push(c, file_key: "AbCd", name: "Workshop", effects: [
      { op: "create", item: { type: "comment", message: "S3" } }
    ])
    expect(r[:ok]).to be true
    expect(r[:data]["file_key"]).to eq("AbCd")
    expect(r[:data]["view_link"]).to eq("https://www.figma.com/file/AbCd/")
    expect(seen.first[:path]).to eq("/v1/files/AbCd/comments")
  end

  it "is reachable as Client#share" do
    c = client_with { |_| ok("id" => "c1") }
    r = c.share(file_key: "Ab", effects: [{ op: "create", item: { type: "comment", message: "x" } }])
    expect(r[:ok]).to be true
  end
end

# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Figma::Client do
  def ok(data = {})
    { ok: true, data: data }
  end

  def client_with(&handler)
    transport = Vv::Figma::FakeTransport.new(&handler)
    described_class.new(access_token: "at", transport: transport)
  end

  describe "refusals before the wire" do
    it "refuses a missing file key" do
      r = client_with { |_| ok }.get_file("")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:file_required)
    end

    it "refuses get_nodes without ids" do
      r = client_with { |_| ok }.get_nodes("Ab", ids: [])
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:item_id_required)
    end
  end

  it "gets a file" do
    seen = nil
    c = client_with do |call|
      seen = call
      ok("name" => "Care", "document" => {})
    end
    r = c.get_file("AbCd")
    expect(r[:ok]).to be true
    expect(seen[:path]).to eq("/v1/files/AbCd")
  end

  it "posts a comment" do
    seen = nil
    c = client_with do |call|
      seen = call
      ok("id" => "c1")
    end
    c.create_comment("AbCd", message: "hello")
    expect(seen[:method]).to eq(:post)
    expect(seen[:path]).to eq("/v1/files/AbCd/comments")
    expect(seen[:body]).to include("message" => "hello")
  end

  it "applies a comment Effect" do
    seen = nil
    c = client_with do |call|
      seen = call
      ok("id" => "c1")
    end
    r = c.apply_effect("AbCd", op: "create", item: { type: "comment", message: "hi" })
    expect(r[:ok]).to be true
    expect(seen[:path]).to eq("/v1/files/AbCd/comments")
  end

  it "refuses a rectangle Effect on REST" do
    r = client_with { |_| ok }.apply_effect("AbCd", op: "create", item: { type: "rectangle" })
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:plugin_required)
  end
end

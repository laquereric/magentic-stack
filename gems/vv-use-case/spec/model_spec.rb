# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::UseCase::Model do
  def fabric(objects)
    { "width" => 900, "height" => 1200, "objects" => objects }
  end

  it "extracts actors, use cases, system, and associations" do
    r = described_class.extract(fabric([
      { "type" => "Group", "ucKind" => "system", "ucId" => "sys_1", "left" => 280, "top" => 160,
        "width" => 520, "height" => 640, "objects" => [{ "type" => "IText", "text" => "Care" }] },
      { "type" => "Group", "ucKind" => "actor", "ucId" => "act_1", "ucRole" => "primary",
        "left" => 80, "top" => 360, "objects" => [{ "type" => "IText", "text" => "Specialist" }] },
      { "type" => "Group", "ucKind" => "usecase", "ucId" => "uc_1", "left" => 400, "top" => 300,
        "width" => 220, "height" => 90, "objects" => [{ "type" => "IText", "text" => "Refund" }] },
      { "type" => "Line", "ucKind" => "association", "ucId" => "as_1", "ucFrom" => "act_1", "ucTo" => "uc_1" }
    ]), title: "Customer Care", digest: "sha256:" + ("a" * 64))

    expect(r["ok"]).to be true
    expect(r["schema"]).to eq("sharedai.uc.essentials.v1")
    expect(r["system"]["label"]).to eq("Care")
    expect(r["actors"][0]["label"]).to eq("Specialist")
    expect(r["use_cases"][0]["label"]).to eq("Refund")
    expect(r["associations"][0]["from"]).to eq("act_1")
  end

  it "ignores poster shapes without ucKind" do
    r = described_class.extract(fabric([
      { "type" => "Rect", "left" => 0, "top" => 0 },
      { "type" => "IText", "text" => "POSTER" },
      { "type" => "Group", "ucKind" => "actor", "ucId" => "act_1", "left" => 10, "top" => 10,
        "objects" => [{ "type" => "IText", "text" => "A" }] }
    ]))
    expect(r["ok"]).to be true
    expect(r["actors"].size).to eq(1)
    expect(r["use_cases"]).to eq([])
  end

  it "refuses an empty diagram" do
    r = described_class.extract(fabric([]))
    expect(r["ok"]).to be false
    expect(r["reason"]).to eq("empty_use_case")
  end
end

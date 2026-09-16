# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::UseCase::Map do
  it "maps model kinds onto shape then connector Effects with local ids" do
    effects = described_class.effects(
      "width" => 900, "height" => 1200,
      "system" => { "id" => "sys_1", "label" => "Care", "x" => 280, "y" => 160, "w" => 520, "h" => 640 },
      "actors" => [{ "id" => "act_1", "label" => "Specialist", "x" => 80, "y" => 360, "w" => 80, "h" => 120 }],
      "use_cases" => [{ "id" => "uc_1", "label" => "Refund", "x" => 400, "y" => 300, "w" => 220, "h" => 90 }],
      "associations" => [{ "id" => "as_1", "from" => "act_1", "to" => "uc_1" }]
    )
    types = effects.map { |e| e.dig("item", "type") }
    expect(types).to eq(%w[shape shape shape connector])
    expect(effects[0].dig("item", "shape")).to eq("rectangle")
    expect(effects[1].dig("item", "shape")).to eq("round_rectangle")
    expect(effects[2].dig("item", "shape")).to eq("circle")
    expect(effects[3].dig("item", "start", "id")).to eq("act_1")
    expect(effects[3].dig("item", "end", "id")).to eq("uc_1")
    expect(effects[1].dig("item", "id")).to eq("act_1")
  end
end
